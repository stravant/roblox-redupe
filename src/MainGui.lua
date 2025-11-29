
--!strict

local TextService = game:GetService("TextService")

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages

local Settings = require(script.Parent.Settings)
local createRedupeSession = require(script.Parent.createRedupeSession)
local Signal = require(Packages.Signal)
local React = require(Packages.React)

local e = React.createElement

-- Shim to correct for LPS not knowing about Path2DControlPoint
type Path2DControlPoint = {
	new: (udimPos: UDim2, inTangent: UDim2?, outTangent: UDim2?) -> Path2DControlPoint,
}
local Path2DControlPoint = Path2DControlPoint

local HelpContext = React.createContext(nil)

local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local DARK_RED = Color3.new(0.705882, 0, 0)
local ACTION_BLUE = Color3.fromRGB(0, 60, 255)

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
			Position = UDim2.fromOffset(INSET * 2, -2),
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

local function WithHelpIcon(props: {
	Subject: React.ReactElement<any, any>,
	Help: React.ReactElement<any, any>,
	LayoutOrder: number?,
})
	local helpContext = React.useContext(HelpContext)
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
			ImageColor3 = if hovered then ACTION_BLUE else WHITE,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			[React.Event.MouseEnter] = function()
				helpContext.SetHelpMessage(props.Help)
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				helpContext.SetHelpMessage(nil)
				setHovered(false)
			end,
		}),
	})
end

local function OperationPanel(props: {
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	local SPLIT = 0.7
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
				DoneButton = e(WithHelpIcon, {
					Help = "Test",
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
				StampButton = e(WithHelpIcon, {
					Help = "Test",
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

local function CopiesPanel(props: {
	Session: createRedupeSession.RedupeSession,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Copy Placement",
		LayoutOrder = props.LayoutOrder,
	}, {
		RedSquare = e("Frame", {
			Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		}),
	})
end

local function RotationPanel(props: {
	Session: createRedupeSession.RedupeSession,
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
	Session: createRedupeSession.RedupeSession,
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
	Session: createRedupeSession.RedupeSession,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
})
	local session = props.Session
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
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
			Session = session,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 2,
		}),
		RotationPanel = e(RotationPanel, {
			Session = session,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 3,
		}),
		ResultPanel = e(ResultPanel, {
			Session = session,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = 4,
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

local function HelpDisplay(props: {

})
	local helpContext = React.useContext(HelpContext)
	print("Show help:", helpContext.HelpMessage)
	return nil
end

local function MainGui(props: {
	HasSession: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
})
	local helpMessage, setHelpMessage = React.useState(nil :: string?)
	local haveHelp, setHaveHelp = React.useState(true)
	local helpContext = React.useMemo(function()
		return {
			HelpMessage = helpMessage,
			SetHelpMessage = setHelpMessage,
			HaveHelp = haveHelp,
			SetHaveHelp = setHaveHelp,
		}
	end, { helpMessage, setHelpMessage })

	local settings = props.CurrentSettings
	return e(HelpContext.Provider, {
		value = helpContext,
	}, {
		e("Frame", {
			Size = UDim2.fromOffset(settings.WindowSize.X, settings.WindowSize.Y),
			Position = UDim2.fromOffset(settings.WindowPosition.X + 350, settings.WindowPosition.Y),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		}, {
			Content = if props.HasSession
				then e(SessionView, {
					Session = createRedupeSession,
					UpdatedSettings = props.UpdatedSettings,
					HandleAction = props.HandleAction,
				})
				else e(EmptySessionView),
			HelpDisplay = e(HelpDisplay),
		}),
	})
end

return MainGui