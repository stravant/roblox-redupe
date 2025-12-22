--!strict
local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local NEW_RIBBON_ICON = "rbxassetid://98256996626224"

local Packages = script.Parent.Parent.Packages

local createRedupeSession = require(script.Parent.createRedupeSession)
local Settings = require(script.Parent.Settings)
local MainGui = require(script.Parent.MainGui)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

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

return function(plugin: Plugin)
	local toolbar = plugin:CreateToolbar("Redupe")
	local button = toolbar:CreateButton("openRedupe", "Open Redupe", NEW_RIBBON_ICON, "Redupe")

	-- The current session
	local session: createRedupeSession.RedupeSession? = nil

	local activeSettings = Settings.Load(plugin)

	local selectionChangedCn = nil
	local pluginActive = false

	local undoCn = nil

	local reactRoot;
	local reactScreenGui;

	local temporarilyIgnoreSelectionChanges = false

	local function destroyUI()
		button:SetActive(false)
		if selectionChangedCn then
			selectionChangedCn:Disconnect()
			selectionChangedCn = nil
		end
		if reactRoot then
			reactRoot:unmount()
			reactRoot = nil
			reactScreenGui:Destroy()
			reactScreenGui = nil
		end
	end

	local handleAction: (string) -> () = nil

	local function updateUI()
		if reactRoot then
			reactRoot:render(React.createElement(MainGui, {
				CanPlace = session and session.CanPlace(),
				HasSession = session ~= nil,
				CurrentSettings = activeSettings,
				UpdatedSettings = function()
					if session then
						session.Update()
					end
					updateUI()
				end,
				HandleAction = handleAction,
			}))
		end
	end

	local function destroySession()
		if session then
			session:Destroy()
			session = nil
			undoCn:Disconnect()
			undoCn = nil
		end
	end

	local function tryCreateSession(oldState: createRedupeSession.SessionState?)
		if session then
			destroySession()
		end
		local targets = getFilteredSelection()
		if #targets > 0 then
			session = createRedupeSession(plugin, targets, activeSettings, oldState)
			session.ChangeSignal:Connect(updateUI)
			updateUI()

			-- Kill the session on undo
			undoCn = ChangeHistoryService.OnUndo:Connect(function()
				destroySession()
			end)

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
		-- Don't reuse rotations when pressing done, only when stamping
		activeSettings.Rotation = CFrame.new()

		destroyUI()
		destroySession()

		-- Explict X press -> Deactivate
		plugin:Deactivate()
	end

	local function uiPresent()
		return reactRoot ~= nil
	end
	
	local function onSelectionChange()
		if temporarilyIgnoreSelectionChanges then
			return
		end
		-- Kill rotation if we switch selected object, it just feels weird to keep in practice.
		print("Reset rotation")
		activeSettings.Rotation = CFrame.new()
		tryCreateSession(if session then session.GetState() else nil)
	end

	local function createUI()
		selectionChangedCn = Selection.SelectionChanged:Connect(onSelectionChange)
		reactScreenGui = Instance.new("ScreenGui")
		reactScreenGui.Name = "RedupeReactUI"
		reactScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		reactScreenGui.Parent = CoreGui
		reactRoot = ReactRoblox.createRoot(reactScreenGui)
		updateUI()
	end

	function handleAction(action: string)
		-- Ignore selection changes until we're done changing the selection
		-- to the newly created objects.
		temporarilyIgnoreSelectionChanges = true
		if action == "cancel" then
			closeRequested()
		elseif action == "stamp" then
			local sessionState = session.Commit(false)
			tryCreateSession(sessionState)
		elseif action == "done" then
			session.Commit(true)
			closeRequested()
		end
		task.defer(function()
			temporarilyIgnoreSelectionChanges = false
		end)
	end

	-- Always get a fresh session when the user clicks the button to provide
	-- them a simple model.
	button.Click:Connect(function()
		button:SetActive(true)
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
		Settings.Save(plugin, activeSettings)
	end)
end