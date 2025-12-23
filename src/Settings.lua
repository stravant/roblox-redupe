local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "redupeState"

export type RedupeSettings = {
	WindowPosition: Vector2,
	CopyCount: number,
	CopySpacing: number,
	CopyPadding: number,
	UseSpacing: boolean,
	MultilySnapByCount: boolean,
	Rotation: CFrame,
	TouchSide: number,
	GroupAs: string,
	AddOriginalToGroup: boolean,
	HaveHelp: boolean,
}

local function loadSettings(plugin: Plugin): RedupeSettings
	-- Placeholder for loading state logic
	local raw = plugin:GetSetting(kSettingsKey) or {}
	return {
		WindowPosition = Vector2.new(
			raw.WindowPositionX or InitialPosition.X,
			raw.WindowPositionY or InitialPosition.Y
		):Max(Vector2.new(0, 0)), -- Make sure the panel is onscreen
		CopyCount = raw.CopyCount or 3,
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
	}
end
local function saveSettings(plugin: Plugin, settings: RedupeSettings)
	-- Placeholder for saving state logic
	plugin:SetSetting(kSettingsKey, {
		WindowPositionX = settings.WindowPosition.X,
		WindowPositionY = settings.WindowPosition.Y,
		CopyCount = settings.CopyCount,
		CopySpacing = settings.CopySpacing,
		CopyPadding = settings.CopyPadding,
		UseSpacing = settings.UseSpacing,
		MultilySnapByCount = settings.MultilySnapByCount,
		TouchSide = settings.TouchSide,
		GroupAs = settings.GroupAs,
		AddOriginalToGroup = settings.AddOriginalToGroup,
		HaveHelp = settings.HaveHelp,
	})
end

return {
	Load = loadSettings,
	Save = saveSettings,
}