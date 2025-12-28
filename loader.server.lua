-- Use the toolbar combiner?
local COMBINE_TOOLBAR = false

local createSharedToolbar = require(script.Parent.Packages.createSharedToolbar)
local Signal = require(script.Parent.Packages.Signal)

local RIBBON_ICON = "rbxassetid://98256996626224"
local TOOLTIP = "Activate Redupe plugin, opening the settings panel and activating the duplication dragger."

local setButtonActive: (active: boolean) -> () = nil
local buttonClicked = Signal.new()

if COMBINE_TOOLBAR then
	local toolbarSettings: createSharedToolbar.SharedToolbarSettings = {
		ButtonName = "Redupe",
		ButtonTooltip = TOOLTIP,
		ButtonIcon = RIBBON_ICON,
		ToolbarName = "GeomTools",
		CombinerName = "GeomToolsToolbar",
		ClickedFn = function()
			buttonClicked:Fire()
		end,
	}
	createSharedToolbar(plugin, toolbarSettings)
	function setButtonActive(active: boolean)
		assert(toolbarSettings.Button):SetActive(active)
	end
else
	local toolbar = plugin:CreateToolbar("Redupe")
	local button = toolbar:CreateButton("openRedupe", TOOLTIP, RIBBON_ICON, "Redupe")
	local clickCn = button.Click:Connect(function()
		buttonClicked:Fire()
	end)
	function setButtonActive(active: boolean)
		button:SetActive(active)
	end
	plugin.Unloading:Connect(function()
		clickCn:Disconnect()
	end)
end

-- Lazy load the main plugin on first click
local loaded = false
local clickedCn = buttonClicked:Connect(function()
	if not loaded then
		loaded = true
		require(script.Parent.Src.main)(plugin, buttonClicked, setButtonActive)
		-- Refire event now that the plugin is listening
		buttonClicked:Fire()
	end
end)
plugin.Deactivation:Connect(function()
	clickedCn:Disconnect()
end)



