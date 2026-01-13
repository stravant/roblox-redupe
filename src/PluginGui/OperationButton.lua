--!strict
local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local Colors = require("./Colors")

local function OperationButton(props: {
	Text: string,
	SubText: string?,
	Height: number,
	Disabled: boolean,
	Color: Color3,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	local text = if props.SubText then
		string.format('%s\n<i><font size="12" color="#FFF">%s</font></i>', props.Text, props.SubText)
	else
		props.Text
	local color = if props.Disabled then props.Color:Lerp(Colors.DISABLED_GREY, 0.5) else props.Color

	return e("TextButton", {
		BackgroundColor3 = color,
		TextColor3 = if props.Disabled then Colors.WHITE:Lerp(Colors.DISABLED_GREY, 0.5) else Colors.WHITE,
		Text = text,
		RichText = true,
		Size = UDim2.new(1, 0, 0, props.Height),
		Font = Enum.Font.SourceSansBold,
		TextSize = 18,
		AutoButtonColor = not props.Disabled,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseButton1Click] = if props.Disabled then nil else props.OnClick,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
	})
end

return OperationButton