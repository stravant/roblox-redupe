--!strict
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local DraggerService = game:GetService("DraggerService")

local Packages = script.Parent.Parent.Packages

local Iris = require(Packages.Iris)
local Signal = require(Packages.Signal)
local DraggerFramework = require(Packages.DraggerFramework)
local DraggerSchemaCore = require(Packages.DraggerSchemaCore)
local Roact = require(Packages.Roact)

local DraggerContext_PluginImpl = require(DraggerFramework.Implementation.DraggerContext_PluginImpl)
local DraggerToolComponent = require(DraggerFramework.DraggerTools.DraggerToolComponent)
local MoveHandles = require(script.Parent.MoveHandles)
local ScaleHandles = require(script.Parent.ScaleHandles)
local TransformHandlesImplementation = require(script.Parent.TranformHandlesImplementation)

local InitialSize = Vector2.new(300, 200)
local InitialPosition = Vector2.new(100, 100)
local kSettingsKey = "redupeState"
type RedupeSettings = {
	WindowPosition: Vector2,
	WindowSize: Vector2,
	CopyCount: number,
	CopySpacing: number,
	CopyPadding: number,
	UseSpacing: boolean,
	MultilySnapByCount: boolean,
}
local function loadSettings(plugin: Plugin): RedupeSettings
	-- Placeholder for loading state logic
	local raw = plugin:GetSetting(kSettingsKey) or {}
	return {
		WindowPosition = Vector2.new(
			raw.WindowPositionX or InitialPosition.X,
			raw.WindowPositionY or InitialPosition.Y
		),
		WindowSize = Vector2.new(
			raw.WindowSizeX or InitialSize.X,
			raw.WindowSizeY or InitialSize.Y
		),
		CopyCount = raw.CopyCount or 3,
		CopySpacing = raw.CopySpacing or 1,
		CopyPadding = raw.CopyPadding or 0,
		UseSpacing = raw.UseSpacing or false,
		MultilySnapByCount = if raw.MultilySnapByCount == nil then true else raw.MultilySnapByCount,
	}
end
local function saveSettings(plugin: Plugin, settings: RedupeSettings)
	-- Placeholder for saving state logic
	plugin:SetSetting(kSettingsKey, {
		WindowPositionX = settings.WindowPosition.X,
		WindowPositionY = settings.WindowPosition.Y,
		WindowSizeX = settings.WindowSize.X,
		WindowSizeY = settings.WindowSize.Y,
		CopyCount = settings.CopyCount,
		CopySpacing = settings.CopySpacing,
		CopyPadding = settings.CopyPadding,
		UseSpacing = settings.UseSpacing,
		MultilySnapByCount = settings.MultilySnapByCount,
	})
end

local function getFilteredSelection(): { Instance }
	local selection = Selection:Get()
	local filtered = {}
	for _, item in selection do
		if item:IsA("BasePart") or item:IsA("Model") or
			item:FindFirstChildWhichIsA("BasePart", true) or
			item:FindFirstChildWhichIsA("Model", true) then
			table.insert(filtered, item)
		end
	end
	return filtered
end

local function createCFrameDraggerSchema(getBoundingBoxFromContextFunc)
	local schema = table.clone(DraggerSchemaCore)
	schema.getMouseTarget = function()
		-- Never find a target
		return nil
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

local function createRedupeSession(plugin: Plugin, targets: { Instance }, currentSettings: RedupeSettings)
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

	local copies = {}
	local function updatePlacement(done: boolean)
		for _, copy in copies do
			copy:Destroy()
		end
		table.clear(copies)
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
		local globalEndDeltaPosition = draggerContext.StartCFrame:VectorToWorldSpace(draggerContext.EndDeltaPosition)
		for i = 1, copyCount - 1 do
			local t = i / (copyCount - 1)
			local mid = draggerContext.StartCFrame:Lerp(draggerContext.EndCFrame, t)
			local item = targets[1]:Clone() -- TODO: All of them
			item:PivotTo(mid + globalEndDeltaPosition * t)
			if not draggerContext.EndDeltaSize:FuzzyEq(Vector3.zero) then
				if item:IsA("Model") then
					local delta = draggerContext.EndDeltaSize * t
					local scaleVec = (size + delta) / size
					local scale = math.max(scaleVec.X, scaleVec.Y, scaleVec.Z)
					item:ScaleTo(item:GetScale() * scale)
				elseif item:IsA("Part") then
					item.Size = size + (draggerContext.EndDeltaSize * t)
				end
			end
			item.Parent = targets[1].Parent
			table.insert(copies, item)
		end
		if not done then
			for _, item in copies do
				setTransparency(item, 0.8)
			end
		end
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
		for _, instance in copies do
			instance:Destroy()
		end
	end
	session.Commit = function()
		updatePlacement(true)
		copies = {}
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

type RedupeSession = typeof(createRedupeSession(...))

local function irisStateInTable(table, key, onChange)
	local state = Iris.State(table[key])
	state:onChange(function(value)
		table[key] = value
		onChange(value)
	end)
	return state
end

return function(plugin: Plugin)
	local toolbar = plugin:CreateToolbar("Redupe")
	local button = toolbar:CreateButton("openRedupe", "Open Redupe", "", "Redupe")

	-- The current session
	local session: RedupeSession? = nil

	local mainRender: () -> ()? = nil

	local activeSettings = loadSettings(plugin)
	local isWindowOpen = Iris.State(true)

	local irisInitialized = false
	local irisDestroy: () -> ()? = nil
	local selectionChangedCn = nil
	local pluginActive = false

	local function destroyUI()
		button:SetActive(false)
		if irisDestroy then
			irisDestroy()
			irisDestroy = nil
		end
		if selectionChangedCn then
			selectionChangedCn:Disconnect()
			selectionChangedCn = nil
		end
	end

	local function destroySession()
		if session then
			session:Destroy()
			session = nil
		end
	end

	local function tryCreateSession()
		if session then
			destroySession()
		end
		local targets = getFilteredSelection()
		if #targets > 0 then
			session = createRedupeSession(plugin, targets, activeSettings)

			-- Activate the plugin here, only after we have a session
			if not pluginActive then
				plugin:Activate(true)
				pluginActive = true
			end
		end
	end

	local function closeRequested()
		destroyUI()
		destroySession()

		-- Explict X press -> Deactivate
		plugin:Deactivate()
	end

	local function uiPresent()
		return irisDestroy ~= nil
	end
	
	local function onSelectionChange()
		tryCreateSession()
	end

	local function createUI()
		selectionChangedCn = Selection.SelectionChanged:Connect(onSelectionChange)
		if not irisInitialized then
			irisInitialized = true
			Iris.Init(CoreGui, RunService.RenderStepped)
		end
		irisDestroy = Iris:Connect(function()
			local window = Iris.Window("Redupe", {
				size = irisStateInTable(activeSettings, "WindowSize"),
				position = irisStateInTable(activeSettings, "WindowPosition"),
				isOpened = isWindowOpen,
			})
			if window.closed() then
				closeRequested()
			end
			mainRender()
			Iris.End()
		end)
	end


	local copyCountState = irisStateInTable(activeSettings, "CopyCount", function()
		session.Update()
	end)
	local copySpacingState = irisStateInTable(activeSettings, "CopySpacing", function()
		session.Update()
	end)
	local copyPaddingState = irisStateInTable(activeSettings, "CopyPadding", function()
		session.Update()
	end)
	local MAIN_MODE = {
		"Specify copy count",
		"Specify copy spacing",
	}
	local useSpacingState = Iris.State(MAIN_MODE[activeSettings.UseSpacing and 2 or 1])
	useSpacingState:onChange(function(value)
		activeSettings.UseSpacing = table.find(MAIN_MODE, value) == 2
		session.Update()
	end)
	local multiplySnapByCountState = irisStateInTable(activeSettings, "MultilySnapByCount", function()
		session.Update()
	end)

	function mainRender()
		if session then
			Iris.Text("Configure duplicate")
			if Iris.Button("Done").clicked() then
				session.Commit()
				destroySession()
				plugin:Deactivate()
			end
			Iris.Separator()
			Iris.ComboArray({ "Mode" }, { index = useSpacingState }, MAIN_MODE)
			if activeSettings.UseSpacing then
				Iris.InputNum({"Spacing Multiplier"}, {
					number = copySpacingState,
				})
				Iris.InputNum({"Stud Padding", 1}, {
					number = copyPaddingState,
				})
			else
				Iris.InputNum({
					[Iris.Args.InputNum.Text] = "Copy Count",
					[Iris.Args.InputNum.Min] = 1,
				}, {
					number = copyCountState,
				})
			end
			Iris.Checkbox({"Multiply snap by count"}, { isChecked = multiplySnapByCountState })
		else
			Iris.TextWrapped({"Select one or more objects to duplicate to begin"})
		end
	end

	-- Always get a fresh session when the user clicks the button to provide
	-- them a simple model.
	button.Click:Connect(function()
		button:SetActive(true)
		isWindowOpen:set(true)
		if not uiPresent() then
			createUI()
		end
		tryCreateSession()
	end)

	-- When the user selects a different tool, stop doing anything, destroy the
	-- UI and the session.
	plugin.Deactivation:Connect(function()
		pluginActive = false
		destroyUI()
		destroySession()
	end)

	plugin.Unloading:Connect(function()
		destroySession()
		destroyUI()
		Iris.Shutdown()
		saveSettings(plugin, activeSettings)
	end)
end