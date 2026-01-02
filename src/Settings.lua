local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "redupeState"

local PluginGuiTypes = require("./PluginGui/Types")

export type RedupeSettings = PluginGuiTypes.PluginGuiSettings & {
	CopyCount: number,
	FinalCopyCount: number, -- Not saved, after redundancy is accounted for
	CopySpacing: number,
	CopyPadding: number,
	UseSpacing: boolean,
	MultilySnapByCount: boolean,
	Rotation: CFrame, -- Not saved, only to comunicate between archituctural layers
	TouchSide: number,
	GroupAs: string,
	AddOriginalToGroup: boolean,
	ResizeAlign: boolean,
}


local function loadSettings(plugin: Plugin): RedupeSettings
	-- Placeholder for loading state logic
	local raw = plugin:GetSetting(kSettingsKey) or {}
	return {
		WindowPosition = Vector2.new(
			raw.WindowPositionX or InitialPosition.X,
			raw.WindowPositionY or InitialPosition.Y
		),
		WindowAnchor = Vector2.new(
			raw.WindowAnchorX or 0,
			raw.WindowAnchorY or 0
		),
		CopyCount = raw.CopyCount or 3,
		FinalCopyCount = raw.CopyCount or 3, -- Intentionally also copy count
		CopySpacing = raw.CopySpacing or 1,
		CopyPadding = raw.CopyPadding or 0,
		UseSpacing = if raw.UseSpacing == nil then true else raw.UseSpacing,
		MultilySnapByCount = if raw.MultilySnapByCount == nil then true else raw.MultilySnapByCount,
		-- Don't actually save the rotation
		Rotation = CFrame.new(),
		TouchSide = raw.TouchSide or 1,
		GroupAs = raw.GroupAs or "None",
		AddOriginalToGroup = if raw.AddOriginalToGroup == nil then true else raw.AddOriginalToGroup,
		HaveHelp = if raw.HaveHelp ~= nil then raw.HaveHelp else true,
		DoneTutorial = if raw.DoneTutorial ~= nil then raw.DoneTutorial else false,
		ResizeAlign = if raw.ResizeAlign ~= nil then raw.ResizeAlign else true,
		WindowHeightDelta = if raw.WindowHeightDelta ~= nil then raw.WindowHeightDelta else 0,
	}
end
local function saveSettings(plugin: Plugin, settings: RedupeSettings)
	-- Placeholder for saving state logic
	plugin:SetSetting(kSettingsKey, {
		WindowPositionX = settings.WindowPosition.X,
		WindowPositionY = settings.WindowPosition.Y,
		WindowAnchorX = settings.WindowAnchor.X,
		WindowAnchorY = settings.WindowAnchor.Y,
		CopyCount = settings.CopyCount,
		CopySpacing = settings.CopySpacing,
		CopyPadding = settings.CopyPadding,
		UseSpacing = settings.UseSpacing,
		MultilySnapByCount = settings.MultilySnapByCount,
		TouchSide = settings.TouchSide,
		GroupAs = settings.GroupAs,
		AddOriginalToGroup = settings.AddOriginalToGroup,
		HaveHelp = settings.HaveHelp,
		DoneTutorial = settings.DoneTutorial,
		ResizeAlign = settings.ResizeAlign,
		WindowHeightDelta = settings.WindowHeightDelta,
	})
end

return {
	Load = loadSettings,
	Save = saveSettings,
}