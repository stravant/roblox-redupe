--!strict
local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local Colors = require("./Colors")

local function ChipWithOutline(props: {
	Text: string,
	LayoutOrder: number?,
	TextColor3: Color3,
	Bolded: boolean,
	BorderColor3: Color3,
	BorderSize: number?,
	ZIndex: number?,
	BackgroundColor3: Color3,
	OnClick: () -> (),
	children: any,
})
	local children = {
		Border = props.BorderSize and e("UIStroke", {
			Color = props.BorderColor3,
			Thickness = props.BorderSize,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Center,
		}),
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	}
	for key, child in props.children or {} do
		children[key] = child
	end

	return e("TextButton", {
		Size = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = props.BackgroundColor3,
		TextColor3 = props.TextColor3,
		RichText = true,
		ZIndex = props.ZIndex,
		Text = props.Text,
		Font = if props.Bolded then Enum.Font.SourceSansBold else Enum.Font.SourceSans,
		TextSize = if props.Bolded then 20 else 18,
		AutoButtonColor = not props.Bolded,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, children)
end

local function ChipForToggle(props: {
	Text: string,
	LayoutOrder: number?,
	IsCurrent: boolean,
	OnClick: () -> (),
})
	local isCurrent = props.IsCurrent
	return e(ChipWithOutline, {
		Text = props.Text,
		TextColor3 = Colors.WHITE,
		BorderColor3 = Colors.WHITE,
		BorderSize = if isCurrent then 2 else nil,
		Bolded = isCurrent,
		BackgroundColor3 = Colors.ACTION_BLUE,
		LayoutOrder = props.LayoutOrder,
		ZIndex = if isCurrent then 2 else 1,
		OnClick = props.OnClick,
	}, {
		Flex = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Grow,
		}),
	})
end

return ChipForToggle