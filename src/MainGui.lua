
--!strict

local TextService = game:GetService("TextService")

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages

local Settings = require(script.Parent.Settings)
local createRedupeSession = require(script.Parent.createRedupeSession)
local Signal = require(Packages.Signal)
local React = require(Packages.React)

local HelpGui = require(script.Parent.HelpGui)

local e = React.createElement

-- Shim to correct for LPS not knowing about Path2DControlPoint
type Path2DControlPoint = {
	new: (udimPos: UDim2, inTangent: UDim2?, outTangent: UDim2?) -> Path2DControlPoint,
}
local Path2DControlPoint = Path2DControlPoint

local BLACK = Color3.fromRGB(0, 0, 0)
local GREY = Color3.fromRGB(38, 38, 38)
local WHITE = Color3.fromRGB(255, 255, 255)
local DARK_RED = Color3.new(0.705882, 0, 0)
local ACTION_BLUE = Color3.fromRGB(0, 60, 255)
local DARKER_BLUE = Color3.fromRGB(0, 42, 179)

local function SubPanel(props: {
	Title: string,
	Padding: UDim?,
	LayoutOrder: number?,
	children: React.ReactElement<any, any>?,
})
	local outlineRef = React.useRef(nil)

	local TITLE_PADDING = 2
	local INSET = 6
	local ROOTINSET = INSET / math.sqrt(2)
	local TITLE_SIZE = 2 * INSET + 2

	React.useEffect(function()
		local outline = outlineRef.current
		if outline then
			local titleLength = TextService:GetTextSize(
				props.Title,
				TITLE_SIZE,
				Enum.Font.SourceSansBold,
				Vector2.new(1000, 1000)
			).X
			local titleLengthPlusPadding = titleLength + TITLE_PADDING * 2

			outline:InsertControlPoint(1, Path2DControlPoint.new(
				UDim2.new(0, 2 * INSET, 0, INSET),
				UDim2.fromOffset(0, 0),
				UDim2.fromOffset(-ROOTINSET, 0)
			))
			outline:InsertControlPoint(2, Path2DControlPoint.new(
				UDim2.new(0, INSET, 0, 2 * INSET),
				UDim2.fromOffset(0, -ROOTINSET),
				UDim2.fromOffset(0, 0)
			))
			outline:InsertControlPoint(3, Path2DControlPoint.new(
				UDim2.new(0, INSET, 1, -2 * INSET),
				UDim2.fromOffset(0, 0),
				UDim2.fromOffset(0, ROOTINSET)
			))
			outline:InsertControlPoint(4, Path2DControlPoint.new(
				UDim2.new(0, 2 * INSET, 1, -INSET),
				UDim2.fromOffset(-ROOTINSET, 0),
				UDim2.fromOffset(0, 0)
			))
			outline:InsertControlPoint(5, Path2DControlPoint.new(
				UDim2.new(1, -2 * INSET, 1, -INSET),
				UDim2.fromOffset(0, 0),
				UDim2.fromOffset(ROOTINSET, 0)
			))
			outline:InsertControlPoint(6, Path2DControlPoint.new(
				UDim2.new(1, -INSET, 1, -2 * INSET),
				UDim2.fromOffset(0, ROOTINSET),
				UDim2.fromOffset(0, 0)
			))
			outline:InsertControlPoint(7, Path2DControlPoint.new(
				UDim2.new(1, -INSET, 0, 2 * INSET),
				UDim2.fromOffset(0, 0),
				UDim2.fromOffset(0, -ROOTINSET)
			))
			outline:InsertControlPoint(8, Path2DControlPoint.new(
				UDim2.new(1, -2 * INSET, 0, INSET),
				UDim2.fromOffset(ROOTINSET, 0),
				UDim2.fromOffset(0, 0)
			))
			outline:InsertControlPoint(9, Path2DControlPoint.new(
				UDim2.new(0, titleLengthPlusPadding + 2 * INSET, 0, INSET),
				UDim2.fromOffset(0, 0),
				UDim2.fromOffset(0, 0)
			))
		end
		return function()
			if outline then
				outline:SetControlPoints({})
			end
		end
	end, {})

	local content = table.clone(props.children or {})
	content.ListLayout = e("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = props.Padding,
	})

	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
	}, {
		Outline = e("Path2D", {
			Thickness = 2,
			Color3 = WHITE,
			ref = outlineRef,
		}),
		TitleLabel = e("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromOffset(INSET * 2, -3),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = WHITE,
			Text = props.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.SourceSansBold,
			TextSize = TITLE_SIZE,
		}, {
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, TITLE_PADDING),
			}),
		}),
		Content = e("Frame", {
			Position = UDim2.fromOffset(INSET * 2, INSET * 2),
			Size = UDim2.new(1, -(INSET * 4), 0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
		}, content),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, INSET * 2),
		}),
	})
end

local function OperationButton(props: {
	Text: string,
	Height: number,
	Color: Color3,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	return e("TextButton", {
		BackgroundColor3 = props.Color,
		TextColor3 = WHITE,
		Text = props.Text,
		Size = UDim2.new(1, 0, 0, props.Height),
		Font = Enum.Font.SourceSansBold,
		TextSize = 18,
		AutoButtonColor = true,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseButton1Click] = props.OnClick,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
	})
end

local function OperationPanel(props: {
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Perform Operation",
		LayoutOrder = props.LayoutOrder,
	}, {
		Main = e("Frame", {
			Size = UDim2.new(1, -2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			ListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			Left = e("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				BackgroundTransparency = 1,
			}, {
				Flex = e("UIFlexItem", {
					GrowRatio = 2,
					FlexMode = Enum.UIFlexMode.Custom,
				}),
				ListLayout = e("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				DoneButton = e(HelpGui.WithHelpIcon, {
					Help = e(HelpGui.BasicTooltip, {
						HelpRichText = "Place the duplicated objects into the world and close Redupe.",
					}),
					Subject = e(OperationButton, {
						Text = "PLACE & EXIT",
						Color = ACTION_BLUE,
						Height = 24,
						OnClick = function()
							props.HandleAction("done")
						end,
					}),
					LayoutOrder = 1,
				}),
				StampButton = e(HelpGui.WithHelpIcon, {
					Help = e(HelpGui.BasicTooltip, {
						HelpRichText = "Place the duplicated objects and keep Redupe open to place additional copies.",
					}),
					Subject = e(OperationButton, {
						Text = "STAMP & REPEAT",
						Color = ACTION_BLUE,
						Height = 24,
						OnClick = function()
							props.HandleAction("stamp")
						end,
					}),
					LayoutOrder = 2,
				}),
			}),
			Right = e("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				BackgroundTransparency = 1,
			}, {
				Flex = e("UIFlexItem", {
					GrowRatio = 1,
					FlexMode = Enum.UIFlexMode.Custom,
				}),
				CancelButton = e(OperationButton, {
					Text = "CANCEL",
					Color = DARK_RED,
					Height = 52,
					OnClick = function()
						props.HandleAction("cancel")
					end,
				}),
			}),
		}),
	})
end

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
		TextColor3 = WHITE,
		BorderColor3 = WHITE,
		BorderSize = if isCurrent then 2 else nil,
		Bolded = isCurrent,
		BackgroundColor3 = ACTION_BLUE,
		LayoutOrder = props.LayoutOrder,
		ZIndex = if isCurrent then 2 else 1,
		OnClick = props.OnClick,
	}, {
		Flex = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Grow,
		}),
	})
end

-- React component with two side by side chips to pick between Spacing or Count
local function SpacingOrCountToggle(props: {
	Session: createRedupeSession.RedupeSession,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local settings = props.CurrentSettings

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = ACTION_BLUE,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		SpacingChip = e(ChipForToggle, {
			Text = "Spacing",
			IsCurrent = settings.UseSpacing,
			LayoutOrder = 1,
			OnClick = function()
				settings.UseSpacing = true
				props.UpdatedSettings()
			end,
		}),
		CountChip = e(ChipForToggle, {
			Text = "Count",
			IsCurrent = not settings.UseSpacing,
			LayoutOrder = 2,
			OnClick = function()
				settings.UseSpacing = false
				props.UpdatedSettings()
			end,
		}),
	})
end

local function InterpretValue(input: string): number?
	-- Implicit divide by 360
	if input:sub(1, 1) == "/" then
		input = "360" .. input
	end
	local fragment, err = loadstring("return " .. input)
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
	Grow: boolean,
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
			local newValue = props.ValueEntered(newValue)
			-- If the value didn't change we need to revert because we won't get rerendered
			if newValue == props.Value then
				object.Text = displayText
			end
		else
			-- Revert to previous value
			object.Text = displayText
		end
		setHasFocus(false)
	end, { props.ValueEntered, displayText })

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
			TextColor3 = WHITE,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			LayoutOrder = 1,
		}),
		TextBox = e("TextBox", {
			Text = textFitsAtNormalSize and displayText or " " .. displayText,
			TextColor3 = WHITE,
			RichText = true,
			BackgroundColor3 = GREY,
			Size = UDim2.new(0, 0, 0, 24),
			Font = Enum.Font.RobotoMono,
			TextScaled = not textFitsAtNormalSize,
			TextSize = 20,
			LayoutOrder = 2,
			[React.Event.Focused] = onFocused,
			[React.Event.FocusLost] = onFocusLost,
			ref = textBoxRef,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
			Border = hasFocus and e("UIStroke", {
				Color = ACTION_BLUE,
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

local function AutoButtonColorDarken(c: Color3): Color3
	return c:Lerp(BLACK, 0.3)
end

local function Checkbox(props: {
	Label: string,
	Checked: boolean,
	Changed: (boolean) -> (),
	LayoutOrder: number?,
})
	local labelHovered, setLabelHovered = React.useState(false)
	local checkboxColor = if props.Checked then ACTION_BLUE else GREY
	if labelHovered then
		checkboxColor = AutoButtonColorDarken(checkboxColor)
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Label = e("TextButton", {
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = props.Label,
			TextColor3 = WHITE,
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
			Size = UDim2.new(0, 24, 0, 24),
			BackgroundColor3 = checkboxColor,
			Text = if props.Checked then "✓" else "",
			TextColor3 = WHITE,
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

local function CopiesPanel(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Generation Method",
		Padding = UDim.new(0, 4),
		LayoutOrder = props.LayoutOrder,
	}, {
		SpacingOrCount = e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Choose whether to evenly space a fixed number of copies or place as many copies as the space allows.",
			}),
			Subject = e(SpacingOrCountToggle, {
				CurrentSettings = props.CurrentSettings,
				UpdatedSettings = props.UpdatedSettings,
			}),
			LayoutOrder = 1,
		}),
		Count = not props.CurrentSettings.UseSpacing and e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "The fixed number of copies to distribute.",
			}),
			Subject = e(NumberInput, {
				Label = "Copy Count",
				Value = props.CurrentSettings.CopyCount,
				ValueEntered = function(newValue: number)
					newValue = math.clamp(math.round(newValue), 2, 1000)
					props.CurrentSettings.CopyCount = newValue
					props.UpdatedSettings()
					return newValue
				end,
			}),
			LayoutOrder = 2,
		}),
		SpacingMultiplier = props.CurrentSettings.UseSpacing and e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Multiple of object size to use as spacing between copies.\nA multiple of 1.0 will put the objects exactly back to back.",
			}),
			Subject = e(NumberInput, {
				Label = "Spacing Factor",
				Unit = "x",
				Value = props.CurrentSettings.CopySpacing,
				ValueEntered = function(newValue: number)
					if math.abs(newValue) < 0.01 then
						warn("Redupe: Spacing factor of 0 will result in the copies being exactly on top of one and other.\n"
							.. "Unless you plan to rotate a stack of copies around the pivot you probably want a spacing greater than one.")
					end
					props.CurrentSettings.CopySpacing = newValue
					props.UpdatedSettings()
					return newValue
				end,
			}),
			LayoutOrder = 3,
		}),
		Padding = props.CurrentSettings.UseSpacing and e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Additional studs of padding to add between copies.",
			}),
			Subject = e(NumberInput, {
				Label = "Stud Padding",
				Unit = "studs",
				Value = props.CurrentSettings.CopyPadding,
				ValueEntered = function(newValue: number)
					props.CurrentSettings.CopyPadding = newValue
					props.UpdatedSettings()
				end,
			}),
			LayoutOrder = 4,
		}),
		MultiplySnapByCount = e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "When enabled, the snap will apply to each copy, keeping each copy aligned to your chosen grid.\nWhen disabled, the snap will apply to the end position only.",
			}),
			Subject = e(Checkbox, {
				Label = "Multiply Snap By Count",
				Checked = props.CurrentSettings.MultilySnapByCount,
				Changed = function(newValue: boolean)
					props.CurrentSettings.MultilySnapByCount = newValue
					props.UpdatedSettings()
				end,
			}),
			LayoutOrder = 5,
		}),
	})
end

local function toCleanDegree(radians: number): number
	if math.abs(radians) < 0.0001 then
		return 0
	end
	return math.deg(radians)
end

local function RotationDisplay(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdateSettings: () -> (),
	LayoutOrder: number?,
})
	local x, y, z = props.CurrentSettings.Rotation:ToEulerAnglesXYZ()
	local xDegrees = toCleanDegree(x)
	local yDegrees = toCleanDegree(y)
	local zDegrees = toCleanDegree(z)

	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		ListLayout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
		}),
		XCoord = e(NumberInput, {
			Unit = "°",
			Value = xDegrees,
			Grow = true,
			ChipColor = Color3.fromRGB(255, 0, 0),
			ValueEntered = function(newValue: number)
				local theta = math.rad(newValue)
				local rotation = CFrame.fromEulerAnglesXYZ(theta, y, z)
				props.CurrentSettings.Rotation = rotation
				props.UpdateSettings()
			end,
			LayoutOrder = 1,
		}),
		YCoord = e(NumberInput, {
			Unit = "°",
			Value = yDegrees,
			Grow = true,
			ChipColor = Color3.fromRGB(0, 255, 0),
			ValueEntered = function(newValue: number)
				local theta = math.rad(newValue)
				local rotation = CFrame.fromEulerAnglesXYZ(x, theta, z)
				props.CurrentSettings.Rotation = rotation
				props.UpdateSettings()
			end,
			LayoutOrder = 2,
		}),
		ZCoord = e(NumberInput, {
			Unit = "°",
			Value = zDegrees,
			Grow = true,
			ChipColor = Color3.fromRGB(0, 0, 255),
			ValueEntered = function(newValue: number)
				local theta = math.rad(newValue)
				local rotation = CFrame.fromEulerAnglesXYZ(x, y, theta)
				props.CurrentSettings.Rotation = rotation
				props.UpdateSettings()
			end,
			LayoutOrder = 3,
		}),
	})
end

local function RotateModeImageChip(props: {
	Image: string,
	ImageRectOffset: Vector2,
	ImageRectSize: Vector2,
	IsCurrent: boolean,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	local isHovered, setIsHovered = React.useState(false)

	return e("ImageButton", {
		Size = UDim2.new(0, 0, 0, 46),
		BackgroundTransparency = 1,
		Image = props.Image,
		ImageColor3 = if not props.IsCurrent and isHovered then WHITE:Lerp(BLACK, 0.3) else WHITE,
		ImageRectOffset = props.ImageRectOffset,
		ImageRectSize = props.ImageRectSize,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseButton1Click] = props.OnClick,
		[React.Event.MouseEnter] = function()
			setIsHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setIsHovered(false)
		end,
	}, {
		Stroke = props.IsCurrent and e("UIStroke", {
			Color = WHITE,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		}),
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		Flex = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Grow,
		}),
	})
end

local function RotateModeToggle(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local settings = props.CurrentSettings

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		InnerOption = e(RotateModeImageChip, {
			Image = "rbxassetid://115945750977717",
			ImageRectOffset = Vector2.new(0, 20),
			ImageRectSize = Vector2.new(222, 200),
			IsCurrent = settings.TouchSide == 1,
			LayoutOrder = 1,
			OnClick = function()
				settings.TouchSide = 1
				props.UpdatedSettings()
			end,
		}),
		MiddleOption = e(RotateModeImageChip, {
			Image = "rbxassetid://115945750977717",
			ImageRectOffset = Vector2.new(222, 20),
			ImageRectSize = Vector2.new(222, 200),
			IsCurrent = settings.TouchSide == 0,
			LayoutOrder = 2,
			OnClick = function()
				settings.TouchSide = 0
				props.UpdatedSettings()
			end,
		}),
		OuterOption = e(RotateModeImageChip, {
			Image = "rbxassetid://115945750977717",
			ImageRectOffset = Vector2.new(444, 20),
			ImageRectSize = Vector2.new(222, 200),
			IsCurrent = settings.TouchSide == -1,
			LayoutOrder = 3,
			OnClick = function()
				settings.TouchSide = -1
				props.UpdatedSettings()
			end,
		}),
	})
end

local function RotationPanel(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Rotation Between Copies",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Rotation = e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Enter a precise rotation between copies.\nYou can also enter \"/7\" to form a circle of 7 copies.\nUse the rotate handles for simpler rotations.",
			}),
			Subject = e(RotationDisplay, {
				CurrentSettings = props.CurrentSettings,
				UpdateSettings = props.UpdatedSettings,
			}),
			LayoutOrder = 1,
		}),
		e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Choose what pivot point the rotation uses, the one on the inside, middle, or outside of the curve.",
			}),
			Subject = e(RotateModeToggle, {
				CurrentSettings = props.CurrentSettings,
				UpdatedSettings = props.UpdatedSettings,
			}),
			LayoutOrder = 2,
		}),
	})
end

-- React component with two side by side chips to pick between Spacing or Count
local function GroupAsToggle(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local settings = props.CurrentSettings

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = ACTION_BLUE,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		NoneOption = e(ChipForToggle, {
			Text = "None",
			IsCurrent = settings.GroupAs == "None",
			LayoutOrder = 1,
			OnClick = function()
				settings.GroupAs = "None"
				props.UpdatedSettings()
			end,
		}),
		ModelOption = e(ChipForToggle, {
			Text = "Model",
			IsCurrent = settings.GroupAs == "Model",
			LayoutOrder = 2,
			OnClick = function()
				settings.GroupAs = "Model"
				props.UpdatedSettings()
			end,
		}),
		FolderOption = e(ChipForToggle, {
			Text = "Folder",
			IsCurrent = settings.GroupAs == "Folder",
			LayoutOrder = 3,
			OnClick = function()
				settings.GroupAs = "Folder"
				props.UpdatedSettings()
			end,
		}),
	})
end

local function ResultPanel(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Result Grouping",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		GroupAs = e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "What should the copies be grouped under? If none then the copies will be siblings of the original.\nIgnored when using STAMP & REPEAT.",
			}),
			Subject = e(GroupAsToggle, {
				CurrentSettings = props.CurrentSettings,
				UpdatedSettings = props.UpdatedSettings,
			}),
			LayoutOrder = 1,
		}),
		AddOriginalToGroup = props.CurrentSettings.GroupAs ~= "None" and e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Should the original you copied from be added to the group too or should only the new copies be grouped?",
			}),
			Subject = e(Checkbox, {
				Label = "Add Original to Group",
				Checked = props.CurrentSettings.AddOriginalToGroup,
				Changed = function(checked: boolean)
					props.CurrentSettings.AddOriginalToGroup = checked
					props.UpdatedSettings()
				end,
			}),
			LayoutOrder = 2,
		})
	})
end

local function SessionTopInfoRow(props: {
	LayoutOrder: number?,
})
	local helpContext = HelpGui.use()
	local stHovered, setStHovered = React.useState(false)
	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1
	}, {
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 0),
			PaddingTop = UDim.new(0, 0),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 4),
		}),
		ListLayout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		DragText = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = WHITE,
			Text = "::",
			Font = Enum.Font.SourceSansBold,
			TextSize = 32,
			LayoutOrder = 1,
		}, {
			Padding = e("UIPadding", {
				PaddingBottom = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 3),
			}),
		}),
		STLogoGraph = e("ImageLabel", {
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Image = "rbxassetid://140140513285893",
			LayoutOrder = 2,
			[React.Event.MouseEnter] = function()
				setStHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setStHovered(false)
			end,
		}),
		PluginNameLabel = e("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = WHITE,
			RichText = true,
			Text = stHovered and "by stravant" or "<i>Redupe</i>",
			Font = Enum.Font.SourceSansBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 26,
			LayoutOrder = 3,
		}, {
			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
		}),
		HelpPart = e("Frame", {
			Size = helpContext.HaveHelp and UDim2.fromOffset(76, 0) or UDim2.fromOffset(42, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 4,
		}, {
			ToggleHelp = e(OperationButton, {
				Text = helpContext.HaveHelp and "Hide Help" or "Help",
				Color = ACTION_BLUE,
				Height = 24,
				OnClick = function()
					helpContext.SetHaveHelp(not helpContext.HaveHelp)
				end,
			}),
		})
	})
end

local function SessionView(props: {
	CurrentSetting: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
})
	return e("ImageButton", {
		Image = "",
		AutoButtonColor = false,
		Size = UDim2.new(0, 240, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		ListLayout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		TopInfoRow = e(SessionTopInfoRow, {
			LayoutOrder = 1,
		}),
		OperationPanel = e(OperationPanel, {
			HandleAction = props.HandleAction,
			LayoutOrder = 2,
		}),
		CopiesPanel = e(CopiesPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 3,
		}),
		RotationPanel = e(RotationPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 4,
		}),
		ResultPanel = e(ResultPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 5,
		}),

	})
end

local function EmptySessionView()
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		InfoLabel = e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = "Select at least one Part or Model to duplicate.",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.SourceSans,
			TextSize = 20,
		}),
	})
end

local function MainGui(props: {
	HasSession: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
})
	local settings = props.CurrentSettings
	return e(HelpGui.Provider, {
		CurrentSettings = props.CurrentSettings,
		UpdatedSettings = props.UpdatedSettings,
	}, {
		e("Frame", {
			Size = UDim2.fromOffset(settings.WindowSize.X, settings.WindowSize.Y),
			Position = UDim2.fromOffset(settings.WindowPosition.X + 350, settings.WindowPosition.Y),
			BackgroundTransparency = 1,
		}, {
			Content = if props.HasSession
				then e(SessionView, {
					CurrentSettings = props.CurrentSettings,
					UpdatedSettings = props.UpdatedSettings,
					HandleAction = props.HandleAction,
				})
				else e(EmptySessionView),
			HelpDisplay = e(HelpGui.HelpDisplay),
		}),
	})
end

return MainGui