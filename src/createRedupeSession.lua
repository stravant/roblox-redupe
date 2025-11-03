--!strict

local CoreGui = game:GetService("CoreGui")
local DraggerService = game:GetService("DraggerService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Packages = script.Parent.Parent.Packages

local Signal = require(Packages.Signal)
local DraggerFramework = require(Packages.DraggerFramework)
local DraggerSchemaCore = require(Packages.DraggerSchemaCore)
local Roact = require(Packages.Roact)

local Settings = require(script.Parent.Settings)
local createGhostPreview = require(script.Parent.createGhostPreview)

local DraggerContext_PluginImpl = require(DraggerFramework.Implementation.DraggerContext_PluginImpl)
local DraggerToolComponent = require(DraggerFramework.DraggerTools.DraggerToolComponent)
local MoveHandles = require(script.Parent.MoveHandles)
local ScaleHandles = require(script.Parent.ScaleHandles)
local TransformHandlesImplementation = require(script.Parent.TranformHandlesImplementation)

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

local function setTransparency(instance: Instance, transparency: number)
	if instance:IsA("BasePart") then
		instance.Transparency = transparency
	end
	for _, desc in instance:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Transparency = transparency
		end
	end
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
	local center, offset, size = info:getLocalBoundingBox()

	local ghostPreview = createGhostPreview(targets, center, offset, size)

	draggerContext.SetDraggingFunction = function(isDragging)
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

		if not currentSettings.UseSpacing then
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
			return
		end
		local largest = largestAxis(offset)
		local leftover = offset - (largest * offset)
		if leftover:FuzzyEq(Vector3.zero) then
			-- Perfectly on an axis, lock it in
			draggerContext.PrimaryAxis = largest
		else
			-- Not perfectly on axis, leave things the way they were
		end
		updateSnapSize()
	end

	local function updatePlacement(done: boolean)
		-- Hide previous previews
		ghostPreview.hide()

		local copyCount
		if draggerContext.PrimaryAxis == nil then
			-- No primary axis set -> Haven't dragged -> Do nothing
			return
		elseif currentSettings.UseSpacing then
			local offset = draggerContext.EndCFrame:ToObjectSpace(draggerContext.StartCFrame).Position
			local offsetOnAxis = (draggerContext.PrimaryAxis * offset).Magnitude
			local sizeOnAxis = (draggerContext.PrimaryAxis * draggerContext.SnapSize).Magnitude
			copyCount = math.floor(offsetOnAxis / sizeOnAxis + 0.5) + 1
		elseif currentSettings.CopyCount < 2 then
			-- Nothing to create
			return
		else
			copyCount = currentSettings.CopyCount
		end
		local endOffset = draggerContext.StartCFrame:VectorToWorldSpace(draggerContext.EndDeltaPosition)
		for i = 1, copyCount - 1 do
			local t = i / (copyCount - 1)
			local mid = draggerContext.StartCFrame:Lerp(draggerContext.EndCFrame, t)
			local copyPosition = mid + endOffset * t
			local copySize = size + (draggerContext.EndDeltaSize * t)
			ghostPreview.create(not done, copyPosition, copySize)
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
					end,
					Visible = function()
						-- Only allow resizing when we have a single target
						return draggerContext.PrimaryAxis ~= nil and #targets == 1
					end,
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
						draggerContext.EndCFrame = globalTransform * draggerContext.StartDragCFrame
						updatePrimaryAxis()
						updatePlacement(false)
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
	end
	session.Commit = function()
		updatePlacement(true)
		ChangeHistoryService:SetWaypoint("Redupe Commit")
	end
	session.Update = function()
		draggerContext.UseSnapSize = currentSettings.UseSpacing
		updateSnapSize()
		maybeAdjustPositionUsingCopyCount()
		maybeAdjustPositionUsingCopySpacing()
		updatePlacement(false)
		fixedSelection.SelectionChanged:Fire() -- Cause a dragger update
	end
	return session
end

export type RedupeSession = typeof(createRedupeSession(...))

return createRedupeSession