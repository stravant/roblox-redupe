
local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

-- Inactive = plugin's tool is not active
-- Pending = the tool is active but has no selection to work on
-- Active = the tool is active and has a selection to work on
export type PluginGuiMode = "inactive" | "pending" | "active"

export type PluginGuiSettings = {
	WindowAnchor: Vector2,
	WindowPosition: Vector2,
	WindowHeightDelta: number,
	DoneTutorial: boolean,
	HaveHelp: boolean,
}

export type TutorialElementProps = {
	LayoutOrder: number?,
	ClickedDone: () -> (),
}

export type PluginGuiConfig = {
	PluginName: string,
	PendingText: string,
	TutorialElement: React.ComponentType<TutorialElementProps>,
}

export type PluginGuiState = {
	Mode: PluginGuiMode,
	Settings: PluginGuiSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
}

return {}