--!strict

local CoreGui = game:GetService("CoreGui")
local DraggerService = game:GetService("DraggerService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Packages = script.Parent.Parent.Packages

local Signal = require(Packages.Signal)
local DraggerFramework = require(Packages.DraggerFramework)
local DraggerSchemaCore = require(Packages.DraggerSchemaCore)
local Roact = require(Packages.Roact)
local Signal = require(Packages.Signal)

local Settings = require(script.Parent.Settings)
local createGhostPreview = require(script.Parent.createGhostPreview)
local bendPlacement = require(script.Parent.bendPlacement)

local DraggerContext_PluginImpl = require(DraggerFramework.Implementation.DraggerContext_PluginImpl)
local DraggerToolComponent = require(DraggerFramework.DraggerTools.DraggerToolComponent)
local MoveHandles = require(script.Parent.MoveHandles)
local ScaleHandles = require(script.Parent.ScaleHandles)
local RotateHandles = require(script.Parent.RotateHandles)

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
	}
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

local function createRedupeSession(plugin: Plugin, targets: { Instance }, currentSettings: Settings.RedupeSettings)
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
			if draggerContext.PrimaryAxis then
				local offset = draggerContext.EndCFrame:ToObjectSpace(draggerContext.StartCFrame).Position
				local lengthOnAxis = math.abs(draggerContext.PrimaryAxis:Dot(offset))
				local unPaddedLengthPer = ((lengthOnAxis / (lastCopiesUsed - 1)) - currentSettings.CopyPadding)
				local spacing = unPaddedLengthPer / draggerContext.PrimaryAxis:Dot(size)
				currentSettings.CopySpacing = spacing
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
			draggerContext.SnapSize = size * currentSettings.CopySpacing + vectorPadding
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
		local snappedMagnitude = math.floor(offsetMagnitude / sizeOnAxis + 0.5) * sizeOnAxis
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

	local function updatePlacement(done: boolean)
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
			bendPlacement(placement, draggerContext.PrimaryAxis, currentSettings.Rotation, currentSettings.TouchSide)
		end

		-- Place using offsets
		local runningPosition = draggerContext.StartCFrame
		for _, placement in placements do
			runningPosition *= placement.Offset
			ghostPreview.create(not done, runningPosition, placement.Size)
		end

		ghostPreview.trim()

		-- Remember the copy count for snapping purposes
		draggerContext.SnapMultiplier = copyCount - 1
	end

	-- Schema
	local schema = createCFrameDraggerSchema(function(context)
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
						return draggerContext.StartCFrame * currentSettings.Rotation,
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

	session.Destroy = function()
		Roact.unmount(handle)
		screenGui:Destroy()
		ghostPreview.hide()
		ghostPreview.trim()
		primaryAxisDisplay:Destroy()
		rotatedAxisDisplay:Destroy()
	end
	session.Commit = function()
		updatePlacement(true)
		ChangeHistoryService:SetWaypoint("Redupe Commit")
		primaryAxisDisplay:Destroy()
		rotatedAxisDisplay:Destroy()
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
	return session
end

export type RedupeSession = typeof(createRedupeSession(...))

return createRedupeSession