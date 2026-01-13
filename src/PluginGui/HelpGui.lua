--!strict
local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)

local Types = require("./Types")

local e = React.createElement

local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local DARK_RED = Color3.new(0.705882, 0, 0)
local _ACTION_BLUE = Color3.fromRGB(0, 60, 255)

export type HelpContext = {
	HelpMessage: {
		Source: Instance,
		Help: React.ReactElement<any, any>,
	}?,
	SetHelpMessage: (source: Instance?, help: React.ReactElement<any, any>?) -> (),
	HaveHelp: boolean,
	SetHaveHelp: (boolean) -> (),
}

local HelpContext = React.createContext((nil :: any) :: HelpContext)

local HelpGui = {}

function HelpGui.use(): HelpContext
	return React.useContext(HelpContext)
end

type HelpMessageType = {
	Source: Instance,
	Help: React.ReactElement<any, any>,
}


function HelpGui.Provider(props: {
	CurrentSettings: Types.PluginGuiSettings,
	UpdatedSettings: () -> (),
	children: React.ReactElement<any, any>?,
})
	local helpMessage, setHelpMessage = React.useState(nil)

	local contextValue = React.useMemo(function()
		return {
			HelpMessage = helpMessage,
			SetHelpMessage = function(source, element)
				if source == nil and element == nil then
					setHelpMessage(nil)
				else
					assert(source and element, "Should not have any one of source / element")
					setHelpMessage({
						Source = source,
						Help = element,
					} :: any) -- Can't type the useState correctly
				end
			end,
			HaveHelp = props.CurrentSettings.HaveHelp,
			SetHaveHelp = function(value)
				props.CurrentSettings.HaveHelp = value
				props.UpdatedSettings()
			end,
		}
	end, {
		helpMessage,
		setHelpMessage,
		props.CurrentSettings.HaveHelp,
		props.UpdatedSettings,
	} :: {any})

	return e(HelpContext.Provider, {
		value = contextValue,
	}, props.children)
end

function HelpGui.WithHelpIcon(props: {
	Subject: React.ReactElement<any, any>,
	Help: React.ReactElement<any, any>,
	LayoutOrder: number?,
})
	local helpContext = HelpGui.use()
	local hovered, setHovered = React.useState(false)

	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Subject = e("Frame", {
			Size = UDim2.fromScale(0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, {
			Subject = props.Subject,
			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
		}),
		Help = helpContext.HaveHelp and e("ImageLabel", {
			Size = UDim2.fromOffset(16, 16),
			Image = "rbxassetid://10717855468",
			ImageColor3 = if hovered then DARK_RED else WHITE,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			[React.Event.MouseEnter] = function(instance)
				helpContext.SetHelpMessage(instance, props.Help)
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				helpContext.SetHelpMessage(nil)
				setHovered(false)
			end,
		}),
	})
end

function HelpGui.BasicTooltip(props: {
	HelpRichText: string,
	LayoutOrder: number?,
})
	return e("TextLabel", {
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = BLACK,
		TextColor3 = WHITE,
		RichText = true,
		Text = props.HelpRichText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.SourceSans,
		TextSize = 16,
		LayoutOrder = props.LayoutOrder,
	}, {
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = e("UIStroke", {
			Color = DARK_RED,
			Thickness = 2,
			ZIndex = 2,
			BorderOffset = UDim.new(0, -6),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

function HelpGui.HelpDisplay(props: {
	Panelized: boolean,
})
	local helpContext = HelpGui.use()
	local frameRef = React.useRef(nil)

	local X_PLACEMENT = 0.75

	-- Find offset if there's a message to display
	local xOffset = if props.Panelized then 0.2 else X_PLACEMENT
	local offset = UDim2.new(xOffset, 0, 0, 0)
	if frameRef.current and helpContext.HelpMessage then
		assert(helpContext.HelpMessage.Source:IsA("GuiObject"))
		local offsetY = helpContext.HelpMessage.Source.AbsolutePosition.Y - frameRef.current.AbsolutePosition.Y
		offset = UDim2.new(xOffset, 0, 0, offsetY)
	end

	-- TODO: Possibly display tooltip in a better place if the user has the popup
	-- near the left of the viewport.

	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		ZIndex = 3, -- hardcode ZIndex here, hack
		ref = frameRef,
	}, {
		HelpContent = helpContext.HelpMessage and e("Frame", {
			Position = offset,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
		}, {
			Content = helpContext.HelpMessage.Help,
		}),
	})
end

return HelpGui