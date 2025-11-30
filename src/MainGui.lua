
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
		SpacingChip = e(ChipWithOutline, {
			Text = "Spacing",
			TextColor3 = WHITE,
			BorderColor3 = WHITE,
			BorderSize = if settings.UseSpacing then 2 else nil,
			Bolded = settings.UseSpacing,
			BackgroundColor3 = ACTION_BLUE,
			LayoutOrder = 1,
			ZIndex = if settings.UseSpacing then 2 else 1,
			OnClick = function()
				settings.UseSpacing = true
				props.UpdatedSettings()
			end,
		}, {
			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
		}),
		CountChip = e(ChipWithOutline, {
			Text = "Count",
			TextColor3 = WHITE,
			BorderColor3 = WHITE,
			BorderSize = if not settings.UseSpacing then 2 else nil,
			Bolded = not settings.UseSpacing,
			BackgroundColor3 = ACTION_BLUE,
			LayoutOrder = 2,
			ZIndex = if not settings.UseSpacing then 2 else 1,
			OnClick = function()
				settings.UseSpacing = false
				props.UpdatedSettings()
			end,
		}, {
			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
		}),
	})
end	

local function InterpretValue(input: string): number?
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
	Label: string,
	Value: number,
	Split: number?,
	Unit: string?,
	ValueEntered: (number) -> (),
	LayoutOrder: number?,
})
	local hasFocus, setHasFocus = React.useState(false)

	local displayText = string.format('<b>%g</b><font size="14">%s</font>', props.Value, if props.Unit then props.Unit else "")

	local onFocusLost = React.useCallback(function(object: TextBox, enterPressed: boolean)
		local newValue = InterpretValue(object.Text)
		if newValue then
			props.ValueEntered(newValue)
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
		Size = UDim2.new(1, 0, 0, 0),
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
		Label = e("TextLabel", {
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
			Text = displayText,
			TextColor3 = WHITE,
			RichText = true,
			BackgroundColor3 = GREY,
			Size = UDim2.new(0, 0, 0, 24),
			Font = Enum.Font.RobotoMono,
			TextSize = 20,
			LayoutOrder = 2,
			[React.Event.Focused] = onFocused,
			[React.Event.FocusLost] = onFocusLost,
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
		Title = "Copy Placement",
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
					props.CurrentSettings.CopySpacing = newValue
					props.UpdatedSettings()
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

local function RotationPanel(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Rotation Angle",
		LayoutOrder = props.LayoutOrder,
	}, {
		RedSquare = e("Frame", {
			Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		}),
	})
end

local function ResultPanel(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Where to put results?",
		LayoutOrder = props.LayoutOrder,
	}, {
		RedSquare = e("Frame", {
			Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		}),
	})
end

local function SessionView(props: {
	CurrentSetting: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
})
	local helpContext = HelpGui.use()
	return e("Frame", {
		Size = UDim2.new(0, 240, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	}, {
		ListLayout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		OperationPanel = e(OperationPanel, {
			HandleAction = props.HandleAction,
			LayoutOrder = 1,
		}),
		CopiesPanel = e(CopiesPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 2,
		}),
		RotationPanel = e(RotationPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 3,
		}),
		ResultPanel = e(ResultPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 4,
		}),
		-- TODO: Better place
		ToggleHelp = e(OperationButton, {
			Text = "Toggle Help",
			Color = ACTION_BLUE,
			LayoutOrder = 5,
			Height = 24,
			OnClick = function()
				helpContext.SetHaveHelp(not helpContext.HaveHelp)
			end,
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