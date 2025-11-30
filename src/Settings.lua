local InitialSize = Vector2.new(300, 200)
local InitialPosition = Vector2.new(100, 100)
local kSettingsKey = "redupeState"

export type RedupeSettings = {
	WindowPosition: Vector2,
	WindowSize: Vector2,
	CopyCount: number,
	CopySpacing: number,
	CopyPadding: number,
	UseSpacing: boolean,
	MultilySnapByCount: boolean,
	TouchSide: number,
	HaveHelp: boolean,
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
		TouchSide = raw.TouchSide or 1,
		HaveHelp = if raw.HaveHelp ~= nil then raw.HaveHelp else true,
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
		TouchSide = settings.TouchSide,
		HaveHelp = settings.HaveHelp,
	})
end

return {
	Load = loadSettings,
	Save = saveSettings,
}