
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

export type PluginGuiConfig = {
	PluginName: string,
	PendingText: string,
}

return {}