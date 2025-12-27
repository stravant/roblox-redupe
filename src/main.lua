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

	local selectionChangedCn: RBXScriptConnection? = nil
	local pluginActive = false

	local undoCn: RBXScriptConnection? = nil

	local reactRoot: ReactRoblox.RootType? = nil
	local reactScreenGui: ScreenGui? = nil

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
		end
		if reactScreenGui then
			reactScreenGui:Destroy()
			reactScreenGui = nil
		end
	end

	local handleAction: (string) -> () = nil

	local function updateUI()
		if reactRoot then
			reactRoot:render(React.createElement(MainGui, {
				CanPlace = session and session.CanPlace() or false,
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
			session.Destroy()
			session = nil
		end
		if undoCn then
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
			local newSession = createRedupeSession(plugin, targets, activeSettings, oldState)
			newSession.ChangeSignal:Connect(updateUI)
			session = newSession
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
		activeSettings.Rotation = CFrame.new()
		-- It might be interesting to try to preserve state here
		-- but that doesn't seem to be working well in practice.
		--tryCreateSession(if session then session.GetState() else nil)
		tryCreateSession()
	end

	local function createUI()
		selectionChangedCn = Selection.SelectionChanged:Connect(onSelectionChange)
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "RedupeReactUI"
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.Parent = CoreGui
		reactScreenGui = screenGui
		reactRoot = ReactRoblox.createRoot(screenGui)
		updateUI()
	end

	local function doReset()
		activeSettings.Rotation = CFrame.new() -- Need to reset rotation here
		if not uiPresent() then
			createUI()
		end
		tryCreateSession()
	end

	function handleAction(action: string)
		-- Ignore selection changes until we're done changing the selection
		-- to the newly created objects.
		temporarilyIgnoreSelectionChanges = true
		if action == "cancel" then
			closeRequested()
		elseif action == "stamp" then
			assert(session)
			local sessionState = session.Commit(false)
			tryCreateSession(sessionState)
		elseif action == "done" then
			assert(session)
			session.Commit(true)
			closeRequested()
		elseif action == "reset" then
			doReset()
		end
		task.defer(function()
			temporarilyIgnoreSelectionChanges = false
		end)
	end

	button.Click:Connect(function()
		-- If the plugin is already open but nothing is selected treat the
		-- button press as closing the panel.
		if uiPresent() and (#getFilteredSelection() == 0) then
			button:SetActive(false)
			destroyUI()
			destroySession()
		else
			-- If the plugin is not open, open it and try to begin a session.
			-- If there is no selection the user will see a UI telling them
			-- to select something.
			button:SetActive(true)
			doReset()
		end
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