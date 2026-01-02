--!strict
local UserInputService = game:GetService("UserInputService")

local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local Colors = require("./Colors")
local HelpGui = require("./HelpGui")
local TutorialGui = require("./TutorialGui")
local OperationButton = require("./OperationButton")
local Types = require("./Types")

local e = React.createElement

local function createNextOrder()
	local order = 0
	return function()
		order += 1
		return order
	end
end

local function SessionTopInfoRow(props: {
	LayoutOrder: number?,
	ShowHelpToggle: boolean,
	Panelized: boolean,
	Config: Types.PluginGuiConfig,
	HandleAction: (string) -> (),
})
	local helpContext = HelpGui.use()
	local stHoveredRef = React.useRef(0)
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
		PopoutPanelButton = e("ImageButton", {
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = if props.Panelized
				then "rbxassetid://138963813997953"
				else "rbxassetid://86290965429311",
			LayoutOrder = 0,
			[React.Event.MouseButton1Click] = function()
				props.HandleAction("togglePanelized")
			end,
		}),
		DragText = not props.Panelized and e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Colors.WHITE,
			Text = "::",
			Font = Enum.Font.SourceSansBold,
			TextSize = 32,
			LayoutOrder = 1,
		}, {
			Padding = e("UIPadding", {
				PaddingBottom = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 3),
			}),
		}),
		STLogoGraph = e("ImageLabel", {
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Image = "rbxassetid://140140513285893",
			LayoutOrder = 2,
			[React.Event.MouseEnter] = function()
				stHoveredRef.current = stHoveredRef.current + 1
				local currentHoverId = stHoveredRef.current
				task.delay(0.5, function()
					if stHoveredRef.current == currentHoverId then
						setStHovered(true)
					end
				end)
			end,
			[React.Event.MouseLeave] = function()
				stHoveredRef.current = stHoveredRef.current + 1
				setStHovered(false)
			end,
		}),
		PluginNameLabel = e("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = Colors.WHITE,
			RichText = true,
			Text = stHovered and "by stravant" or `<i>{props.Config.PluginName}</i>`,
			Font = Enum.Font.SourceSansBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = stHovered and 24 or 26,
			LayoutOrder = 3,
		}, {
			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),
		}),
		HelpPart = props.ShowHelpToggle and e("Frame", {
			Size = helpContext.HaveHelp and UDim2.fromOffset(76, 0) or UDim2.fromOffset(42, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 4,
		}, {
			ToggleHelp = e(OperationButton, {
				Text = helpContext.HaveHelp and "Hide Help" or "Help",
				Color = Colors.ACTION_BLUE,
				Height = 24,
				OnClick = function()
					helpContext.SetHaveHelp(not helpContext.HaveHelp)
				end,
				Disabled = false,
			}),
		})
	})
end

local function getViewSize(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	else
		return Vector2.new(800, 600)
	end
end

-- Determines which edge to make the position relative to
local function updateWindowPosition(settings: Types.PluginGuiSettings, size: Vector2, newPositionScreenSpace: Vector2)
	local viewSize = getViewSize()
	local center = newPositionScreenSpace + size / 2
	local centerFraction = center / viewSize
	local computedAnchor = Vector2.new(math.round(centerFraction.X), math.round(centerFraction.Y))
	local cornerOfWindow = newPositionScreenSpace + size * computedAnchor
	local cornerOfScreen = viewSize * computedAnchor
	settings.WindowPosition = cornerOfWindow - cornerOfScreen
	settings.WindowAnchor = computedAnchor
end

local function getMainWindow(context: Instance): Instance?
	local check: Instance? = context
	while check do
		if check:HasTag("MainWindow") then
			return check
		end
		check = check.Parent
	end
	return nil
end

local function getMainWindowSize(context: Instance): Vector2
	local mainWindow = getMainWindow(context)
	if mainWindow and mainWindow:IsA("GuiObject") then
		return Vector2.new(mainWindow.AbsoluteSize.X, mainWindow.AbsoluteSize.Y)
	else
		warn("Something weird happened, missing main window")
		return Vector2.new(240, 400)
	end
end

local function createBeginDragFunction(settings: Types.PluginGuiSettings, updatedSettings: () -> ())
	return function(instance, inputObject: InputObject)
		if inputObject.UserInputState ~= Enum.UserInputState.Begin then
			return
		end

		local startMouseLocation = UserInputService:GetMouseLocation()
		local viewSize = getViewSize()
		local windowSize = getMainWindowSize(instance)

		-- In screen space
		local startWindowPositionScreenSpace =
			settings.WindowAnchor * viewSize
			+ settings.WindowPosition
			- windowSize * settings.WindowAnchor

		task.spawn(function()
			local previousDelta = Vector2.new()
			while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
				local newMouseLocation = UserInputService:GetMouseLocation()
				local delta = newMouseLocation - startMouseLocation
				if delta ~= previousDelta then
					previousDelta = delta
					local newPositionScreenSpace = startWindowPositionScreenSpace + delta

					updateWindowPosition(settings, windowSize, newPositionScreenSpace)
					updatedSettings()
				end
				task.wait()
			end
		end)
	end
end

local function SessionView(props: {
	CurrentSettings: Types.PluginGuiSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	Config: Types.PluginGuiConfig,
	OnSizeChanged: (Vector2) -> ()?,
	children: {[string]: React.ReactNode}?,
}): React.ReactNode
	local nextOrder = createNextOrder()

	local childrenPlusListLayout: {[string]: React.ReactNode} = table.clone(assert(props.children))
	childrenPlusListLayout.ListLayout = e("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[React.Change.AbsoluteSize] = function(rbx: Frame)
			if props.OnSizeChanged then
				props.OnSizeChanged(rbx.AbsoluteSize)
			end
		end,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		ListLayout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Don't let things feel crowded at the bottom of the scrolling panel
		Padding = props.Panelized and e("UIPadding", {
			PaddingBottom = UDim.new(0, 40),
		}),
		TopInfoRow = props.Panelized and e(SessionTopInfoRow, {
			LayoutOrder = nextOrder(),
			ShowHelpToggle = true,
			Panelized = true,
			Config = props.Config,
			HandleAction = props.HandleAction,
		}),
		Content = e("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, childrenPlusListLayout),
	})
end

local function EmptySessionView(props: {
	CurrentSettings: Types.PluginGuiSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	Config: Types.PluginGuiConfig,
	children: {[string]: React.ReactNode}?,
})
	local beginDrag = if not props.Panelized then
		createBeginDragFunction(props.CurrentSettings, props.UpdatedSettings)
		else nil

	-- TODO: Pull out some part of this into props.Children

	return e("ImageButton", {
		Image = "",
		AutoButtonColor = false,
		Size = UDim2.new(0, 240, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		[React.Event.InputBegan] = beginDrag,
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
			ShowHelpToggle = false,
			HandleAction = props.HandleAction,
			Panelized = props.Panelized,
			Config = props.Config,
		}),
		InfoLabel = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 120),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = props.Config.PendingText,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.SourceSans,
			TextSize = 20,
			LayoutOrder = 2,
		}, {
			Padding = e("UIPadding", {
				PaddingBottom = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		}),
	})
end

local function createBeginResizeFunction(settings: Types.PluginGuiSettings, updatedSettings: () -> ())
	return function(instance, x, y)
		local startMouseLocation = UserInputService:GetMouseLocation()
		local startWindowSizeDelta = settings.WindowHeightDelta
		local startWindowPosition = settings.WindowPosition

		task.spawn(function()
			local previousDelta = Vector2.new()
			while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
				local newMouseLocation = UserInputService:GetMouseLocation()
				local delta = newMouseLocation - startMouseLocation
				if delta ~= previousDelta then
					previousDelta = delta
					settings.WindowHeightDelta = math.min(0, startWindowSizeDelta + delta.Y)
					if settings.WindowAnchor.Y == 1 then
						-- If anchored to bottom, need to move position up as we grow
						settings.WindowPosition = startWindowPosition + Vector2.new(0, delta.Y)
					end
					updatedSettings()
				end
				task.wait()
			end
		end)
	end
end

local function ScrollableSessionView(props: {
	CurrentSettings: Types.PluginGuiSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	Config: Types.PluginGuiConfig,
	children: {[string]: React.ReactNode}?,
}): React.ReactNode
	local dragFunction = createBeginDragFunction(props.CurrentSettings, props.UpdatedSettings)
	local currentDisplaySize, setCurrentDisplaySize = React.useState(300)
	local HEADER_SIZE_EXTRA = 36
	return e("ImageButton", {
		Size = UDim2.new(1, 0, 0, currentDisplaySize + props.CurrentSettings.WindowHeightDelta),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.BLACK,
		AutoButtonColor = false,
		Image = "",
		[React.Event.InputBegan] = dragFunction,
	}, {
		OrderedLayer = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			ListLayout = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Header = e(SessionTopInfoRow, {
				LayoutOrder = 1,
				ShowHelpToggle = not props.Panelized,
				HandleAction = props.HandleAction,
				Panelized = props.Panelized,
				Config = props.Config,
			}),
			Scroll = e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 0, 0),
				CanvasSize = UDim2.fromScale(1, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 0,
				LayoutOrder = 2,
			}, {
				Flex = e("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Grow,
				}),
				Content = e(SessionView, {
					Config = props.Config,
					CurrentSettings = props.CurrentSettings,
					UpdatedSettings = props.UpdatedSettings,
					HandleAction = props.HandleAction,
					Panelized = props.Panelized,
					OnSizeChanged = function(newSize: Vector2)
						setCurrentDisplaySize(newSize.Y + HEADER_SIZE_EXTRA)
					end,
				}, props.children),
			}),
		}),
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		ResizeWidget = e("TextButton", {
			Size = UDim2.fromOffset(32, 10),
			Position = UDim2.new(0.5, 0, 1, -3),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Text = "",
			BackgroundColor3 = Colors.BLACK,
			AutoButtonColor = false,
			LayoutOrder = 3,
			ZIndex = 2,
			[React.Event.MouseButton1Down] = createBeginResizeFunction(
				props.CurrentSettings,
				props.UpdatedSettings
			),
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Line1 = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(1, -8, 0, 1),
				Position = UDim2.new(0.5, 0, 0.5, -1),
				BackgroundColor3 = Colors.OFFWHITE,
				BorderSizePixel = 0,
			}),
			Line2 = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(1, -8, 0, 1),
				Position = UDim2.new(0.5, 0, 0.5, 1),
				BackgroundColor3 = Colors.OFFWHITE,
				BorderSizePixel = 0,
			}),
		}),
	})
end

local function MainGuiViewport(props: {
	GuiState: Types.PluginGuiMode,
	CurrentSettings: Types.PluginGuiSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Config: Types.PluginGuiConfig,
	children: {[string]: React.ReactNode}?,
})
	local settings = props.CurrentSettings

	-- Ugly hack, need to make a special layer for the Tutorial to not interrupt
	-- automatic sizing of the main SessionView
	local showTutorial = not settings.DoneTutorial and settings.HaveHelp

	return e("Frame", {
		Size = UDim2.fromOffset(240, 0),
		Position = UDim2.new(
			settings.WindowAnchor.X, settings.WindowPosition.X,
			settings.WindowAnchor.Y, settings.WindowPosition.Y),
		AnchorPoint = settings.WindowAnchor,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[React.Tag] = "MainWindow",
	}, {
		Content = if props.GuiState == "active"
			then e(ScrollableSessionView, {
				Config = props.Config,
				CurrentSettings = props.CurrentSettings,
				UpdatedSettings = props.UpdatedSettings,
				HandleAction = props.HandleAction,
				Panelized = false,
			}, props.children)
			else e(EmptySessionView, {
				Config = props.Config,
				CurrentSettings = props.CurrentSettings,
				UpdatedSettings = props.UpdatedSettings,
				Panelized = false,
				HandleAction = props.HandleAction,
			}),
		ActualTutorialGui = showTutorial and e(TutorialGui, {
			ClickedDone = function()
				props.CurrentSettings.DoneTutorial = true
				props.UpdatedSettings()
			end,
		}),
		HelpDisplay = e(HelpGui.HelpDisplay, {
			Panelized = false,
		}),
	})
end

local function InactiveView(props: {
	OnActivate: () -> (),
	PluginName: string,
})
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.BLACK,
		BorderSizePixel = 0,
	}, {
		CenteredContent = e("Frame", {
			Size = UDim2.fromOffset(200, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			ListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),
		}, {
			Content = e("TextButton", {
				LayoutOrder = 2,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				TextColor3 = Colors.WHITE,
				BackgroundColor3 = Colors.ACTION_BLUE,
				RichText = true,
				Text = `<font size="26" face="SourceSans">Activate</font> <i>{props.PluginName}</i>`,
				Font = Enum.Font.SourceSansBold,
				TextSize = 26,
				[React.Event.MouseButton1Click] = props.OnActivate,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
				Padding = e("UIPadding", {
					PaddingBottom = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
				}),
			}),
		}),
	})
end

local function MainGuiPanelized(props: {
	GuiState: Types.PluginGuiMode,
	CurrentSettings: Types.PluginGuiSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Config: Types.PluginGuiConfig,
	children: {[string]: React.ReactNode}?,
}): React.ReactNode
	if props.GuiState == "inactive" then
		return e(InactiveView, {
			OnActivate = function()
				props.HandleAction("reset")
			end,
			PluginName = props.Config.PluginName,
		})
	else
		return e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.fromScale(1, 0),
			BorderSizePixel = 0,
			BackgroundColor3 = Colors.BLACK,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 0,
		}, {
			Padding = e("UIPadding", {
				PaddingBottom = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
			}),
			Content = if props.GuiState == "active"
				then e(SessionView, {
					Config = props.Config,
					CurrentSettings = props.CurrentSettings,
					UpdatedSettings = props.UpdatedSettings,
					HandleAction = props.HandleAction,
					Panelized = true,
				}, props.children)
				else e(EmptySessionView, {
					Config = props.Config,
					CurrentSettings = props.CurrentSettings,
					UpdatedSettings = props.UpdatedSettings,
					Panelized = true,
					HandleAction = props.HandleAction,
				}, props.children),
			HelpDisplay = e(HelpGui.HelpDisplay, {
				Panelized = true,
			}),
		})
	end
end

local function PluginGui(props: {
	GuiState: Types.PluginGuiMode,
	CurrentSettings: Types.PluginGuiSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	Config: Types.PluginGuiConfig,
	children: {[string]: React.ReactNode}?,
})
	return e(HelpGui.Provider, {
		CurrentSettings = props.CurrentSettings,
		UpdatedSettings = props.UpdatedSettings,
	}, {
		Viewport = e(props.Panelized and MainGuiPanelized or MainGuiViewport, {
			Config = props.Config,
			GuiState = props.GuiState,
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
		}, props.children),
	})
end

return PluginGui