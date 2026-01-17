--!strict
local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local Colors = require("./Colors")

local function AutoButtonColorDarken(c: Color3): Color3
	return c:Lerp(Colors.BLACK, 0.3)
end

local HEIGHT = 22

local function Checkbox(props: {
	Label: string,
	Checked: boolean,
	Changed: (boolean) -> (),
	LayoutOrder: number?,
})
	local labelHovered, setLabelHovered = React.useState(false)
	local checkboxColor = if props.Checked then Colors.ACTION_BLUE else Colors.GREY
	if labelHovered then
		checkboxColor = AutoButtonColorDarken(checkboxColor)
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = e("TextButton", {
			Size = UDim2.new(0, 0, 0, HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = props.Label,
			TextColor3 = Colors.WHITE,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			LayoutOrder = 1,
			[React.Event.MouseButton1Click] = function()
				props.Changed(not props.Checked)
			end,
			[React.Event.MouseEnter] = function()
				setLabelHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setLabelHovered(false)
			end,
		}),
		CheckBox = e("TextButton", {
			Size = UDim2.new(0, HEIGHT, 0, HEIGHT),
			BackgroundColor3 = checkboxColor,
			Text = if props.Checked then "✓" else "",
			TextColor3 = Colors.WHITE,
			Font = Enum.Font.SourceSansBold,
			TextSize = 24,
			LayoutOrder = 2,
			[React.Event.MouseButton1Click] = function()
				props.Changed(not props.Checked)
			end,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Stroke = not props.Checked and e("UIStroke", {
				Color = Color3.fromRGB(136, 136, 136),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			}),
		}),
	})
end

return Checkbox