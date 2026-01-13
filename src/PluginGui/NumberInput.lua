--!strict
local TextService = game:GetService("TextService")

local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local Colors = require("./Colors")

local function InterpretValue(input: string): number?
	-- Implicit divide by 360
	if input:sub(1, 1) == "/" then
		input = "360" .. input
	end
	local fragment, _err = loadstring("return " .. input)
	if fragment then
		local success, result = pcall(fragment)
		if success and typeof(result) == "number" then
			return result
		end
	end
	return nil
end

local function NumberInput(props: {
	Label: string?,
	Value: number,
	Unit: string?,
	ValueEntered: (number) -> number?,
	LayoutOrder: number?,
	ChipColor: Color3?,
	Grow: boolean?,
})
	local hasFocus, setHasFocus = React.useState(false)

	local displayText = string.format('<b>%g</b><font size="14">%s</font>', props.Value, if props.Unit then props.Unit else "")

	local textBoxRef = React.useRef(nil)
	local numberPartLength = TextService:GetTextSize(
		string.format("%g", props.Value),
		20,
		Enum.Font.RobotoMono,
		Vector2.new(1000, 1000)
	).X
	local unitPartLength = TextService:GetTextSize(
		if props.Unit then props.Unit else "",
		14,
		Enum.Font.RobotoMono,
		Vector2.new(1000, 1000)
	).X
	local displayTextSize = numberPartLength + unitPartLength
	local textFitsAtNormalSize = not textBoxRef.current or
		textBoxRef.current.AbsoluteSize.X >= displayTextSize + 4

	local onFocusLost = React.useCallback(function(object: TextBox, enterPressed: boolean)
		local newValue = InterpretValue(object.Text)
		if newValue then
			newValue = props.ValueEntered(newValue)
			-- If the value didn't change we need to revert because we won't get rerendered
			if newValue == props.Value then
				object.Text = displayText
			end
		else
			-- Revert to previous value
			object.Text = displayText
		end
		setHasFocus(false)
	end, { props.ValueEntered, displayText } :: {any})

	local onFocused = React.useCallback(function(object: TextBox)
		setHasFocus(true)
	end, {})

	return e("Frame", {
		Size = if props.Grow then UDim2.new() else UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Flex = props.Grow and e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Grow,
		}),
		Label = props.Label and e("TextLabel", {
			Text = props.Label,
			TextColor3 = Colors.WHITE,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			LayoutOrder = 1,
		}),
		TextBox = e("TextBox", {
			Text = textFitsAtNormalSize and displayText or " " .. displayText,
			TextColor3 = Colors.WHITE,
			RichText = true,
			BackgroundColor3 = Colors.GREY,
			Size = UDim2.new(0, 0, 0, 24),
			Font = Enum.Font.RobotoMono,
			TextScaled = not textFitsAtNormalSize,
			TextSize = 20,
			LayoutOrder = 2,
			[React.Event.Focused] = onFocused,
			[React.Event.FocusLost] = onFocusLost :: any,
			ref = textBoxRef,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
			Border = hasFocus and e("UIStroke", {
				Color = Colors.ACTION_BLUE,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			ChipColor = props.ChipColor and not hasFocus and e("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				ChipFrame = e("Frame", {
					Size = UDim2.new(0, 2, 1, 0),
					BackgroundColor3 = props.ChipColor,
				}),
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
			}),
		}),
	})
end

return NumberInput