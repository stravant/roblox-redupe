--!strict
local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Packages = script.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Signal = require(Packages.Signal)

local createRedupeSession = require("./createRedupeSession")
local Settings = require("./Settings")
local RedupeGui = require("./RedupeGui")
local PluginGuiTypes = require("./PluginGui/Types")

local function getFilteredSelection(): { Instance }
	local selection = Selection:Get()
	local filtered = {}
	local terrain = workspace.Terrain
	for _, item in selection do
		-- Don't try to duplicate services
		if item.Parent == game or item == terrain then
			continue
		end
		if item:IsA("BasePart") or item:IsA("Model") or
			item:FindFirstChildWhichIsA("BasePart", true) or
			item:FindFirstChildWhichIsA("Model", true) then
			table.insert(filtered, item)
		end
	end
	return filtered
end

return function(plugin: Plugin, panel: DockWidgetPluginGui, buttonClicked: Signal.Signal<>, setButtonActive: (active: boolean) -> ())
	-- The current session
	local session: createRedupeSession.RedupeSession? = nil

	local active = false

	local activeSettings = Settings.Load(plugin)

	local selectionChangedCn: RBXScriptConnection? = nil
	local pluginActive = false

	local undoCn: RBXScriptConnection? = nil

	local reactRoot: ReactRoblox.RootType? = nil
	local reactScreenGui: LayerCollector? = nil

	local temporarilyIgnoreSelectionChanges = false

	local handleAction: (string) -> () = nil

	local function destroyReactRoot()
		if reactRoot then
			reactRoot:unmount()
			reactRoot = nil
		end
		if reactScreenGui then
			reactScreenGui:Destroy()
			reactScreenGui = nil
		end
	end
	local function createReactRoot()
		if panel.Enabled then
			reactRoot = ReactRoblox.createRoot(panel)
		else
			local screen = Instance.new("ScreenGui")
			screen.Name = "RedupeMainGui"
			screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			screen.Parent = CoreGui
			reactScreenGui = screen
			reactRoot = ReactRoblox.createRoot(screen)
		end
	end

	local function getGuiState(): PluginGuiTypes.PluginGuiMode
		if not active then
			return "inactive"
		elseif session == nil then
			return "pending"
		else
			return "active"
		end
	end

	local function updateUI()
		local needsUI = active or panel.Enabled
		if needsUI then
			if not reactRoot then
				createReactRoot()
			elseif panel.Enabled and reactScreenGui ~= nil then
				-- Moved to panel, need to destroy old gui and recreate root
				destroyReactRoot()
				createReactRoot()
			elseif not panel.Enabled and reactScreenGui == nil then
				-- Moved to screen gui, need to destroy old gui and recreate root
				destroyReactRoot()
				createReactRoot()
			end

			assert(reactRoot, "We just created it")
			reactRoot:render(React.createElement(RedupeGui, {
				CanPlace = session and session.CanPlace() or false,
				GuiState = getGuiState(),
				CurrentSettings = activeSettings,
				UpdatedSettings = function()
					if session then
						session.Update()
					end
					updateUI()
				end,
				HandleAction = handleAction,
				Panelized = panel.Enabled,
			}))
		elseif reactRoot then
			destroyReactRoot()
		end
	end

	local onSelectionChange
	local function setActive(newActive: boolean)
		if active == newActive then
			return
		end
		setButtonActive(newActive)
		if newActive then
			selectionChangedCn = Selection.SelectionChanged:Connect(onSelectionChange)
			active = true
		else
			if selectionChangedCn then
				selectionChangedCn:Disconnect()
				selectionChangedCn = nil
			end
			active = false
		end
		updateUI()
	end

	local function destroySession()
		if session then
			-- Need to disconnect selection changed so
			-- that us restoring the selection after bad FinishRecording
			-- behavior does not cause a new session to be created.
			local mustRestoreSelectionChanged = false
			if selectionChangedCn then
				mustRestoreSelectionChanged = true
				selectionChangedCn:Disconnect()
				selectionChangedCn = nil
			end
			session.Destroy()
			session = nil
			if mustRestoreSelectionChanged then
				selectionChangedCn = Selection.SelectionChanged:Connect(onSelectionChange)
			end
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

		setActive(false)
		destroySession()

		-- Explict X press -> Deactivate
		plugin:Deactivate()
	end
	
	function onSelectionChange()
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

	local function doReset()
		activeSettings.Rotation = CFrame.new() -- Need to reset rotation here
		setActive(true)
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
		elseif action == "togglePanelized" then
			panel.Enabled = not panel.Enabled
			updateUI()
		else
			warn("Unknown action: "..action)
		end
		task.defer(function()
			temporarilyIgnoreSelectionChanges = false
		end)
	end

	local clickedCn = buttonClicked:Connect(function()
		-- If the plugin is already open but nothing is selected treat the
		-- button press as closing the panel.
		if active and (#getFilteredSelection() == 0) then
			setActive(false)
			destroySession()
		else
			-- If the plugin is not open, open it and try to begin a session.
			-- If there is no selection the user will see a UI telling them
			-- to select something.
			doReset()
		end
	end)

	-- Initial UI show in the case where we're in Panelized mode
	updateUI()

	-- When the user selects a different tool, stop doing anything, destroy the
	-- UI and the session.
	plugin.Deactivation:Connect(function()
		pluginActive = false
		setActive(false)
		destroySession()
		assert(selectionChangedCn == nil)
		assert(undoCn == nil)
	end)

	plugin.Unloading:Connect(function()
		destroySession()
		setActive(false)
		destroyReactRoot()
		Settings.Save(plugin, activeSettings)
		clickedCn:Disconnect()
		assert(selectionChangedCn == nil)
		assert(undoCn == nil)
		assert(reactRoot == nil)
		assert(reactScreenGui == nil)
	end)
end