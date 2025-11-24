--!strict
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local NEW_RIBBON_ICON = "rbxassetid://140448476907799"

local Packages = script.Parent.Parent.Packages

local Iris = require(Packages.Iris)

local createRedupeSession = require(script.Parent.createRedupeSession)
local Settings = require(script.Parent.Settings)

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
	local button = toolbar:CreateButton("openRedupe", "Open Redupe", NEW_RIBBON_ICON, "Redupe")

	-- The current session
	local session: createRedupeSession.RedupeSession? = nil

	local mainRender: () -> ()? = nil

	local activeSettings = Settings.Load(plugin)
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
		else
			-- Force a ribbon tool to be selected so that the user can easily modify
			-- the selection to have something to duplicate selected.
			if plugin:GetSelectedRibbonTool() == Enum.RibbonTool.None then
				plugin:SelectRibbonTool(Enum.RibbonTool.Select, UDim2.new())
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

	local copyCountState
	copyCountState = irisStateInTable(activeSettings, "CopyCount", function()
		print("Copy count update->", copyCountState:get())
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
		-- Read back the copy count / spacing in case it changed due to preserving the
		-- previewed copy count when changing modes.
		assert(activeSettings.CopyCount, "Missing copy count")
		copyCountState:set(activeSettings.CopyCount)
		copySpacingState:set(activeSettings.CopySpacing)
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
				Iris.InputNum({
					"Spacing Multiplier",
					[Iris.Args.InputNum.Format] = "%.3fx",
				}, {
					number = copySpacingState,
				})
				Iris.InputNum({
					"Stud Padding", 1,
					[Iris.Args.InputNum.Format] = "%.3fstuds",
				}, {
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
		Settings.Save(plugin, activeSettings)
	end)
end