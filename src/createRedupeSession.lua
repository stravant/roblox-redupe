--!strict

local CoreGui = game:GetService("CoreGui")
local DraggerService = game:GetService("DraggerService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local TweenService = game:GetService("TweenService")

local Packages = script.Parent.Parent.Packages

local DraggerFramework = require(Packages.DraggerFramework)
local DraggerSchemaCore = require(Packages.DraggerSchemaCore)
local Roact = require(Packages.Roact)
local Signal = require(Packages.Signal)

local Settings = require("./Settings")
local createGhostPreview = require("./createGhostPreview")
local bendPlacement = require("./bendPlacement")

local DraggerContext_PluginImpl = (require :: any)(DraggerFramework.Implementation.DraggerContext_PluginImpl)
local DraggerToolComponent = (require :: any)(DraggerFramework.DraggerTools.DraggerToolComponent)
local MoveHandles = require("./MoveHandles")
local ScaleHandles = require("./ScaleHandles")
local RotateHandles = require("./RotateHandles")

local ROTATE_GRANULARITY_MULTIPLIER = 2

local function createCFrameDraggerSchema(getBoundingBoxFromContextFunc)
	local schema = table.clone(DraggerSchemaCore)
	schema.getMouseTarget = function()
		-- Never find a target
		return nil
	end
	schema.addUndoWaypoint = function()
		-- Noop. We don't want an undo waypoint every drag
	end
	schema.SelectionInfo = {
		new = function(context, selection)
			return {
				isEmpty = function(self)
					return false
				end,
				getBoundingBox = function(self)
					return getBoundingBoxFromContextFunc(context)
				end,
				getAllAttachments = function(self)
					return {}
				end,
				getObjectsToTransform = function(self)
					return {}, {}, {}
				end,
				getBasisObject = function(self)
					return nil
				end,
				getOriginalCFrameMap = function(self)
					return {}
				end,
				getTransformedCopy = function(self, globalTransform)
					return self
				end,
			}
		end,
	} :: any -- Okay to not match the cloned type because we're only using part of the schema.
	return schema
end

local function createFixedSelection(selection: { Instance })
	local selectionChangedSignal = Signal.new()
	return {
		Get = function()
			return selection
		end,
		Set = function(newSelection, _hint)
			task.defer(function()
				selectionChangedSignal:Fire()
			end)
		end,
		SelectionChanged = selectionChangedSignal,
	}
end

local function largestAxis(v: Vector3): Vector3
	local absV = v:Abs()
	if absV.X > absV.Y and absV.X > absV.Z then
		return Vector3.xAxis
	elseif absV.Y > absV.Z then
		return Vector3.yAxis
	else
		return Vector3.zAxis
	end
end

export type SessionState = {
	RelativeEndCFrame: CFrame,
	EndDeltaSize: Vector3,
	EndDeltaPosition: Vector3,
	PrimaryAxis: Vector3?,
	Center: CFrame,
}

-- Really messy, could be cleaned up a lot.
local function tweenCamera(globalTransform: CFrame)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	task.spawn(function()
		local startCFrame = camera.CFrame
		local endCFrame = globalTransform * startCFrame
		local startFocus = camera.Focus
		local endFocus = globalTransform * startFocus

		-- On render step
		local DURATION = 0.2
		local elapsed = 0
		while elapsed < DURATION do
			local dt = task.wait()
			elapsed += dt
			local alpha = math.clamp(elapsed / DURATION, 0, 1)
			alpha = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			local interpCFrame = startCFrame:Lerp(endCFrame, alpha)
			local interpFocus = startFocus:Lerp(endFocus, alpha)
			camera.Focus = CFrame.new(interpFocus.Position)
			camera.CFrame = CFrame.lookAlong(interpCFrame.Position, interpCFrame.LookVector)
		end
	end)
end

local function createRedupeSession(plugin: Plugin, targets: { Instance }, currentSettings: Settings.RedupeSettings, previousState: SessionState?)
	local session = {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RedupeSessionDraggers"
	screenGui.Parent = CoreGui

	local changeSignal = Signal.new()

	local fixedSelection = createFixedSelection(targets)

	-- Context
	local draggerContext = DraggerContext_PluginImpl.new(
		plugin,
		game,
		settings(),
		fixedSelection
	)

	-- Get the bounds
	local info = DraggerSchemaCore.SelectionInfo.new(draggerContext, targets)
	local center, boundsOffset, size = info:getLocalBoundingBox()

	-- If we have a previous center, try to tween the camera by
	-- the difference
	if previousState then
		local globalTransform = center * previousState.Center:Inverse()
		tweenCamera(globalTransform)
	end

	-- Kind of ugly, needed to make switching between modes work easily to
	-- preserve the copy count.
	local lastCopiesUsed: number? = nil

	local ghostPreview = createGhostPreview(targets, center, boundsOffset, size)

	draggerContext.SetDraggingFunction = function(_isDragging)
	end
	draggerContext.DragUpdatedSignal = Signal.new()

	draggerContext.PrimaryAxis = nil
	draggerContext.StartCFrame = center
	draggerContext.StartDragCFrame = center
	draggerContext.EndCFrame = draggerContext.StartCFrame
	draggerContext.SnapSize = nil
	draggerContext.EndDeltaSize = Vector3.zero
	draggerContext.EndDeltaPosition = Vector3.zero
	draggerContext.StartEndResizeSize = nil
	draggerContext.StartEndResizePosition = nil
	draggerContext.UseSnapSize = currentSettings.UseSpacing

	-- Patch snapping to support a mulitplier
	draggerContext.SnapMultiplier = 1
	function draggerContext:snapToGridSize(delta)
		if DraggerService.LinearSnapEnabled then
			local snap = DraggerService.LinearSnapIncrement
			if currentSettings.MultilySnapByCount then
				snap *= draggerContext.SnapMultiplier
			end
			return math.floor(delta / snap + 0.5) * snap
		else
			return delta
		end
	end

	-- Proportionally adjust the end position when adding / removing copies
	local previousCopyCount = currentSettings.CopyCount
	local function maybeAdjustPositionUsingCopyCount()
		if currentSettings.CopyCount == previousCopyCount then
			return
		end
		local deltaCopyCount = currentSettings.CopyCount - previousCopyCount
		
		-- If in spacing mode, nothing to do
		if currentSettings.UseSpacing then
			return
		end
		
		local offset = draggerContext.StartCFrame:ToObjectSpace(draggerContext.EndCFrame)
		local offsetPer = offset.Position / (previousCopyCount - 1)

		-- Offset the end CFrame by the change
		draggerContext.EndCFrame += draggerContext.StartCFrame:VectorToWorldSpace(offsetPer * deltaCopyCount)
		
		local endDeltaSize = draggerContext.EndDeltaSize
		local endDeltaPosition = draggerContext.EndDeltaPosition

		-- Offset the end position / size modifications
		draggerContext.EndDeltaSize += deltaCopyCount * endDeltaSize / (previousCopyCount - 1)
		draggerContext.EndDeltaPosition += deltaCopyCount * endDeltaPosition / (previousCopyCount - 1)

		previousCopyCount = currentSettings.CopyCount
	end

	local previousMode = currentSettings.UseSpacing
	local function maybeAdjustCopyCountUsingMode()
		if currentSettings.UseSpacing == previousMode then
			return
		end

		if currentSettings.UseSpacing then
			-- Switch spacing. Update the spacing to result in what we last
			-- generated.
			if draggerContext.PrimaryAxis and lastCopiesUsed then
				local offset = draggerContext.EndCFrame:ToObjectSpace(draggerContext.StartCFrame).Position
				local lengthOnAxis = math.abs(draggerContext.PrimaryAxis:Dot(offset))
				local unPaddedLengthPer = ((lengthOnAxis / (lastCopiesUsed - 1)) - currentSettings.CopyPadding)
				local spacing = unPaddedLengthPer / draggerContext.PrimaryAxis:Dot(size)
				if spacing < 0.01 then
					warn("Redupe: Spacing settings don't work for this selection (E.g.: A negative padding equal to the selection's size)")
					currentSettings.CopySpacing = 1
				else
					currentSettings.CopySpacing = spacing
				end
			end
		else
			-- Switch count. Update the count to what we last generated.
			if lastCopiesUsed then
				currentSettings.CopyCount = lastCopiesUsed
				previousCopyCount = lastCopiesUsed
			end
		end

		previousMode = currentSettings.UseSpacing
	end

	local function updateSnapSize()
		if draggerContext.PrimaryAxis then
			local vectorPadding = draggerContext.PrimaryAxis * currentSettings.CopyPadding
			local paddedSize = size * currentSettings.CopySpacing + vectorPadding
			-- Padded size must be greater than zero on every axis. If any axis
			-- is equal to zero default it to one to avoid divide by zero.
			draggerContext.SnapSize = Vector3.new(
				(paddedSize.X > 0.01) and paddedSize.X or 1,
				(paddedSize.Y > 0.01) and paddedSize.Y or 1,
				(paddedSize.Z > 0.01) and paddedSize.Z or 1
			)
		else
			draggerContext.SnapSize = size * currentSettings.CopySpacing
		end
	end
	updateSnapSize() -- Initial update

	-- Resnap the end position based on the copy spacing
	local previousCopySpacing = currentSettings.CopySpacing
	local previousCopyPadding = currentSettings.CopyPadding
	local function maybeAdjustPositionUsingCopySpacing()
		if currentSettings.CopySpacing == previousCopySpacing and
			currentSettings.CopyPadding == previousCopyPadding then
			return
		end

		if not currentSettings.UseSpacing or not draggerContext.PrimaryAxis then
			return
		end

		local offset = draggerContext.StartCFrame:ToObjectSpace(draggerContext.EndCFrame)
		local sizeOnAxis = (draggerContext.PrimaryAxis * draggerContext.SnapSize).Magnitude
		local offsetOnAxis = draggerContext.PrimaryAxis * offset.Position
		offset -= offsetOnAxis
		local offsetMagnitude = offsetOnAxis.Magnitude
		local newCount = math.floor(offsetMagnitude / sizeOnAxis + 0.5)
		if newCount == 0 then
			-- Need at least one copy so we don't lose the primary axis.
			newCount = 1
		end
		local snappedMagnitude = newCount * sizeOnAxis
		local newOffset = offsetOnAxis.Unit * snappedMagnitude
		offset += newOffset
		draggerContext.EndCFrame = draggerContext.StartCFrame * offset

		previousCopySpacing = currentSettings.CopySpacing
		previousCopyPadding = currentSettings.CopyPadding
	end

	-- If a primary axis has not been chosen yet, try to lock one in.
	-- This lock-in happens on the first positional drag. That drag
	-- decides what axis copies are stamped along in UseSnapSize mode.
	-- Outside UseSnapSize mode which axis we do the stamping along is not.
	-- Important.
	local function updatePrimaryAxis()
		local offset = draggerContext.StartCFrame:ToObjectSpace(draggerContext.EndCFrame).Position
		if offset:FuzzyEq(Vector3.zero) then
			-- Has not moved, clear axis
			draggerContext.PrimaryAxis = nil

			-- Also clear the size adjustment because we could have
			-- a size adjustment that does not apply to the new axis
			-- the user uses next.
			draggerContext.EndDeltaSize = Vector3.zero
			draggerContext.EndDeltaPosition = Vector3.zero
			return
		end
		local largest = largestAxis(offset)
		local leftover = offset - (largest * offset)
		if leftover:FuzzyEq(Vector3.zero, 0.001) then
			-- Perfectly on an axis, lock it in
			if largest ~= draggerContext.PrimaryAxis then
				-- Clear size adjustment if changing axis
				draggerContext.EndDeltaSize = Vector3.zero
				draggerContext.EndDeltaPosition = Vector3.zero
			end
			draggerContext.PrimaryAxis = largest
		else
			-- Not perfectly on axis, leave things the way they were
		end
		updateSnapSize()
	end

	local primaryAxisDisplay = Instance.new("WireframeHandleAdornment")
	primaryAxisDisplay.Name = "RedupePrimaryAxisDisplay"
	primaryAxisDisplay.Adornee = workspace.Terrain
	primaryAxisDisplay.Parent = CoreGui
	primaryAxisDisplay.AlwaysOnTop = true

	local rotatedAxisDisplay = Instance.new("WireframeHandleAdornment")
	rotatedAxisDisplay.Name = "RedupeRotatedAxisDisplay"
	rotatedAxisDisplay.Adornee = workspace.Terrain
	rotatedAxisDisplay.Parent = CoreGui
	rotatedAxisDisplay.AlwaysOnTop = true

	local function updatePrimaryAxisDisplay()
		primaryAxisDisplay:Clear()
		rotatedAxisDisplay:Clear()
		if draggerContext.PrimaryAxis then
			local color
			if draggerContext.PrimaryAxis:FuzzyEq(Vector3.xAxis) then
				color = Color3.fromRGB(255, 0, 0)
			elseif draggerContext.PrimaryAxis:FuzzyEq(Vector3.yAxis) then
				color = Color3.fromRGB(0, 255, 0)
			else
				color = Color3.fromRGB(0, 0, 255)
			end
			local endDisplayPosition = (draggerContext.EndCFrame * CFrame.new(draggerContext.EndDeltaPosition)).Position
			local worldDirection = draggerContext.StartCFrame:VectorToWorldSpace(draggerContext.PrimaryAxis)
			primaryAxisDisplay.Color3 = color
			primaryAxisDisplay:AddLine(
				(endDisplayPosition - worldDirection * 10000),
				(endDisplayPosition + worldDirection * 10000)
			)

			if not currentSettings.Rotation:FuzzyEq(CFrame.identity) then
				local startDisplayPosition = draggerContext.StartCFrame.Position
				local worldRotatedDirection = (draggerContext.StartCFrame * currentSettings.Rotation):VectorToWorldSpace(draggerContext.PrimaryAxis)
				rotatedAxisDisplay.Color3 = Color3.new(1, 1, 1)
				rotatedAxisDisplay:AddLine(
					(startDisplayPosition - worldRotatedDirection * 10000),
					(startDisplayPosition + worldRotatedDirection * 10000)
				)
			end
		end
	end

	local function getCopyCount(): number?
		if draggerContext.PrimaryAxis == nil then
			-- No primary axis set -> Haven't dragged -> Do nothing
			return nil
		elseif currentSettings.UseSpacing then
			local offset = draggerContext.EndCFrame:ToObjectSpace(draggerContext.StartCFrame).Position
			local offsetOnAxis = (draggerContext.PrimaryAxis * offset).Magnitude
			local sizeOnAxis = (draggerContext.PrimaryAxis * draggerContext.SnapSize).Magnitude
			if math.abs(sizeOnAxis) < 0.01 then
				warn(`Redupe: Spacing settings result in too many copies ({offsetOnAxis / sizeOnAxis})`)
				return nil
			end
			return math.floor(offsetOnAxis / sizeOnAxis + 0.5) + 1
		elseif currentSettings.CopyCount < 2 then
			-- Nothing to create
			return nil
		else
			return currentSettings.CopyCount
		end
	end

	local function maybeUpdateSizeAdjustments(previousCount: number?, newCount: number?)
		if previousCount == newCount or previousCount == nil or newCount == nil then
			return
		end
		local oldSizePer = draggerContext.EndDeltaSize / (previousCount - 1)
		local oldOffsetPer = draggerContext.EndDeltaPosition / (previousCount - 1)
		draggerContext.EndDeltaSize = oldSizePer * (newCount - 1)
		draggerContext.EndDeltaPosition = oldOffsetPer * (newCount - 1)
	end

	local function updatePlacement(done: boolean): {{ Instance }}?
		ghostPreview.hide()

		updatePrimaryAxisDisplay()

		local copyCount = getCopyCount()
		if copyCount then
			lastCopiesUsed = copyCount
		else
			lastCopiesUsed = nil
			return
		end

		local endOffset = draggerContext.StartCFrame:VectorToWorldSpace(draggerContext.EndDeltaPosition)
		local placements = {}
		for i = 1, copyCount - 1 do
			local t = i / (copyCount - 1)
			local mid = draggerContext.StartCFrame:Lerp(draggerContext.EndCFrame, t)
			local copyPosition = mid + endOffset * t
			local copySize = size + (draggerContext.EndDeltaSize * t)
			table.insert(placements, {
				Position = copyPosition,
				BoundsOffset = boundsOffset,
				Size = copySize,
				Offset = CFrame.new(),
				PreviousSize = Vector3.new(),
			})
		end

		-- Convert positions to offsets and apply bending
		for i, placement in placements do
			if i == 1 then
				placement.Offset = draggerContext.StartCFrame:ToObjectSpace(placement.Position)
				placement.PreviousSize = size
			else
				placement.Offset = placements[i - 1].Position:ToObjectSpace(placement.Position)
				placement.PreviousSize = placements[i - 1].Size
			end

			-- Do the bending
			bendPlacement(placement, draggerContext.PrimaryAxis, currentSettings.Rotation, currentSettings.TouchSide, currentSettings.CopyPadding, currentSettings.CopySpacing)
		end

		-- Place using offsets
		local runningPosition = draggerContext.StartCFrame
		local results = {}
		for _, placement in placements do
			runningPosition *= placement.Offset
			table.insert(results, ghostPreview.create(not done, runningPosition, placement.Size))
		end

		ghostPreview.trim()

		-- Remember the copy count for snapping purposes
		draggerContext.SnapMultiplier = copyCount - 1
		currentSettings.CopyCount = copyCount
		return results
	end

	-- Schema
	local schema = createCFrameDraggerSchema(function(context: typeof(draggerContext))
		return context.EndCFrame, Vector3.zero, Vector3.zero
	end)

	local rootElement = Roact.createElement(DraggerToolComponent, {
		Mouse = plugin:GetMouse(),
		DraggerContext = draggerContext,
		DraggerSchema = schema,
		DraggerSettings = {
			AllowDragSelect = false,
			AnalyticsName = "Redupe",
			HandlesList = {
				ScaleHandles.new(draggerContext, {
					GetBoundingBox = function()
						return draggerContext.EndCFrame * CFrame.new(draggerContext.EndDeltaPosition),
							Vector3.zero,
							Vector3.one + draggerContext.EndDeltaSize
					end,
					StartScale = function()
						draggerContext.StartEndResizeSize = draggerContext.EndDeltaSize
						draggerContext.StartEndResizePosition = draggerContext.EndDeltaPosition
					end,
					ApplyScale = function(deltaSize, deltaOffset)
						draggerContext.EndDeltaSize = draggerContext.StartEndResizeSize + deltaSize
						draggerContext.EndDeltaPosition = draggerContext.StartEndResizePosition + deltaOffset
						updatePlacement(false)
						changeSignal:Fire()
					end,
					Visible = function()
						-- Only allow resizing when we have a single target
						return draggerContext.PrimaryAxis ~= nil and #targets == 1
					end,
				}),
				RotateHandles.new(draggerContext, {
					GetBoundingBox = function()
						if not draggerContext.PrimaryAxis then
							return draggerContext.StartCFrame,
								Vector3.zero,
								Vector3.zero
						end
						-- Offset the position the rotate handles are shown around opposite to the offset
						-- so that the rotate handles don't overlap the other handles excessively.
						local offset = draggerContext.StartCFrame:ToObjectSpace(draggerContext.EndCFrame).Position * draggerContext.PrimaryAxis
						local offsetDirection = -offset.Unit
						local baseCFrame = draggerContext.StartCFrame * CFrame.new(offsetDirection * ((size) + Vector3.one * 4))
						baseCFrame = draggerContext.StartCFrame -- Offset isn't working well
						return baseCFrame * currentSettings.Rotation,
							Vector3.zero,
							Vector3.zero
					end,
					StartTransform = function()
						draggerContext.StartDragCFrame = currentSettings.Rotation
					end,
					ApplyTransform = function(localTransform: CFrame)
						-- Take only half the rotation to provide more precision
						local halfRotation = CFrame.new():Lerp(localTransform, 1 / ROTATE_GRANULARITY_MULTIPLIER)
						local result = draggerContext.StartDragCFrame * halfRotation
						-- For rotations we have to orthonormalize to avoid accumulating
						-- catastrophic skew because skew accumulates exponentially per
						-- operation.
						currentSettings.Rotation = result:Orthonormalize()
						updatePlacement(false)
						changeSignal:Fire()
					end,
					Visible = function()
						return draggerContext.PrimaryAxis ~= nil
					end,
					SnapGranularityMultiplier = ROTATE_GRANULARITY_MULTIPLIER,
				}),
				MoveHandles.new(draggerContext, {
					GetBoundingBox = function()
						return draggerContext.EndCFrame * CFrame.new(draggerContext.EndDeltaPosition),
							Vector3.zero,
							Vector3.one + draggerContext.EndDeltaSize
					end,
					StartTransform = function()
						draggerContext.StartDragCFrame = draggerContext.EndCFrame
					end,
					ApplyTransform = function(globalTransform: CFrame)
						local previousCopyCount = getCopyCount()
						draggerContext.EndCFrame = globalTransform * draggerContext.StartDragCFrame
						updatePrimaryAxis()
						maybeUpdateSizeAdjustments(previousCopyCount, getCopyCount())
						updatePlacement(false)
						changeSignal:Fire()
					end,
				}),
			},
		},
	})

	local handle = Roact.mount(rootElement)

	local function packageResults(results: {{ Instance }})
		local createdContainers = {}
		local containers = {}
		for i, target in targets do
			if currentSettings.GroupAs == "None" then
				containers[i] = target.Parent
			else
				local container = Instance.new(currentSettings.GroupAs)
				if currentSettings.GroupAs == "Model" then
					assert(container:IsA("Model"))
					if target:IsA("PVInstance") then
						container.WorldPivot = target:GetPivot()
					else
						container.WorldPivot = center
					end
				end
				container.Name = target.Name .. "Copies"
				container.Parent = target.Parent
				containers[i] = container
				table.insert(createdContainers, container)
			end
		end
		for _, copyList in results do
			for i, copy in copyList do
				copy.Parent = containers[i]
			end
		end
		if currentSettings.AddOriginalToGroup then
			for i, target in targets do
				target.Parent = containers[i]
			end
		end
		return createdContainers
	end

	local recordingInProgress = ChangeHistoryService:TryBeginRecording("RedupeChanges", "Redupe Changes")

	session.GetState = function()
		return {
			Center = center,
			RelativeEndCFrame = draggerContext.StartCFrame:ToObjectSpace(draggerContext.EndCFrame),
			EndDeltaSize = draggerContext.EndDeltaSize,
			EndDeltaPosition = draggerContext.EndDeltaPosition,
			PrimaryAxis = draggerContext.PrimaryAxis,
		}
	end
	session.CanPlace = function(): boolean
		return draggerContext.PrimaryAxis ~= nil
	end
	session.Destroy = function()
		if recordingInProgress then
			local existingSelection = Selection:Get()
			ChangeHistoryService:FinishRecording(recordingInProgress, Enum.FinishRecordingOperation.Cancel)
			-- Finish recording may clobber the selection when using cancel mode, manually
			-- preserve the selection we had. Cancelling may have removed something that
			-- was selected but Set is tolerant of that.
			Selection:Set(existingSelection)
			recordingInProgress = nil
		end
		Roact.unmount(handle)
		screenGui:Destroy()
		ghostPreview.hide()
		ghostPreview.trim()
		primaryAxisDisplay:Destroy()
		rotatedAxisDisplay:Destroy()
	end
	session.Commit = function(groupResults: boolean)
		local finalResults = updatePlacement(true)
		if not finalResults then
			-- Nothing objects placed
			ChangeHistoryService:FinishRecording(recordingInProgress, Enum.FinishRecordingOperation.Cancel)
			recordingInProgress = nil
			return session.GetState()
		end

		-- Put results into containers if needed
		local createdContainers
		if groupResults then
			createdContainers = packageResults(finalResults)
		else
			createdContainers = {}
		end
		if #createdContainers > 0 then
			Selection:Set(createdContainers)
		else
			Selection:Set(finalResults[#finalResults])
		end

		if recordingInProgress then
			ChangeHistoryService:FinishRecording(recordingInProgress, Enum.FinishRecordingOperation.Commit)
			recordingInProgress = nil
		else
			warn("Redupe: ChangeHistory Recording failed, fall back to adding waypoint.")
			ChangeHistoryService:SetWaypoint("Redupe Changes")
		end
		primaryAxisDisplay:Destroy()
		rotatedAxisDisplay:Destroy()
		return session.GetState()
	end
	session.Update = function()
		draggerContext.UseSnapSize = currentSettings.UseSpacing
		maybeAdjustCopyCountUsingMode()
		updateSnapSize()
		maybeAdjustPositionUsingCopyCount()
		maybeAdjustPositionUsingCopySpacing()
		updatePlacement(false)
		fixedSelection.SelectionChanged:Fire() -- Cause a dragger update
	end
	session.ChangeSignal = changeSignal

	-- Restore previous state if requested
	if previousState then
		draggerContext.EndCFrame = draggerContext.StartCFrame * previousState.RelativeEndCFrame
		draggerContext.EndDeltaSize = previousState.EndDeltaSize
		draggerContext.EndDeltaPosition = previousState.EndDeltaPosition
		draggerContext.PrimaryAxis = previousState.PrimaryAxis
		session.Update()
	end

	return session
end

export type RedupeSession = typeof(createRedupeSession(...))

return createRedupeSession