--!strict
local UserInputService = game:GetService("UserInputService")

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local Colors = require("./PluginGui/Colors")
local Settings = require("./Settings")
local HelpGui = require("./PluginGui/HelpGui")
local TutorialGui = require("./TutorialGui")
local SubPanel = require("./PluginGui/SubPanel")
local ChipForToggle = require("./PluginGui/ChipForToggle")
local NumberInput = require("./PluginGui/NumberInput")
local Checkbox = require("./PluginGui/Checkbox")

local e = React.createElement

local function createNextOrder()
	local order = 0
	return function()
		order += 1
		return order
	end
end

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

local function OperationPanel(props: {
	CanPlace: boolean,
	CopyCount: number?,
	GroupAs: string,
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	local canRepeat = props.CanPlace and props.GroupAs == "None"
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
					GrowRatio = 5,
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
						Text = if props.CanPlace then `PLACE [{props.CopyCount}] COPIES` else "PLACE & EXIT",
						SubText = not props.CanPlace and "(Drag to add copies first)" or nil,
						Disabled = not props.CanPlace,
						Color = Colors.ACTION_BLUE,
						Height = 34,
						OnClick = function()
							props.HandleAction("done")
						end,
					}),
					LayoutOrder = 1,
				}),
				StampButton = e(HelpGui.WithHelpIcon, {
					Help = e(HelpGui.BasicTooltip, {
						HelpRichText = "Place the duplicated objects and keep Redupe open to place additional copies in the same way.\nDoes not work if grouping is enabled because that would create awkwardly nested groups.",
					}),
					Subject = e(OperationButton, {
						Text = "STAMP & REPEAT",
						SubText = (props.CanPlace and not canRepeat) and "(Only with grouping: None)" or nil,
						Disabled = not canRepeat,
						Color = Colors.ACTION_BLUE,
						Height = 34,
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
					GrowRatio = 2,
					FlexMode = Enum.UIFlexMode.Custom,
				}),
				ListLayout = e("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				CancelButton = e(OperationButton, {
					Text = "EXIT",
					Color = Colors.DARK_RED,
					Disabled = false,
					Height = 34,
					OnClick = function()
						props.HandleAction("cancel")
					end,
					LayoutOrder = 1,
				}),
				ResetButton = e(OperationButton, {
					Text = "RESET",
					Color = Colors.DARK_RED,
					Disabled = not props.CanPlace,
					Height = 34,
					OnClick = function()
						props.HandleAction("reset")
					end,
					LayoutOrder = 2,
				}),
			}),
		}),
	})
end

-- React component with two side by side chips to pick between Spacing or Count
local function SpacingOrCountToggle(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local settings = props.CurrentSettings

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = Colors.ACTION_BLUE,
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
			Text = "Alignment",
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



local function CopiesPanel(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Specify Copy...",
		Padding = UDim.new(0, 4),
		LayoutOrder = props.LayoutOrder,
	}, {
		SpacingOrCount = e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Choose whether to place as many back-to-back copies as space allows or evenly distribute a fixed number of copies.",
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
				HelpRichText = "Multiple of object size to use as spacing between copies.\nA multiple of 1.0 will place the copies exactly back to back.",
			}),
			Subject = e(NumberInput, {
				Label = "Copy Spacing",
				Unit = "xSize",
				Value = props.CurrentSettings.CopySpacing,
				ValueEntered = function(newValue: number)
					if math.abs(newValue) < 0.01 then
						warn("Redupe: A spacing factor of 0 would imply infinitely many copies, not allowed!")
						return props.CurrentSettings.CopySpacing
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
				HelpRichText =
					"Additional studs of padding to add between copies." ..
					"\n• May be negative if overlap is needed.",
			}),
			Subject = e(NumberInput, {
				Label = "Extra Padding",
				Unit = "studs",
				Value = props.CurrentSettings.CopyPadding,
				ValueEntered = function(newValue: number)
					props.CurrentSettings.CopyPadding = newValue
					props.UpdatedSettings()
					return newValue
				end,
			}),
			LayoutOrder = 4,
		}),
		MultiplySnapByCount = e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = 
					"When enabled, your grid snap will be multiplied by the copy count, so that during a resize each copy individually stays grid aligned rather than only the endpoint staying grid aligned." ..
					"\n• Disable if you need more precise positioning of the final copy.",
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
				return nil
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
				return nil
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
				return nil
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
	local helpContext = HelpGui.use()

	return e("ImageButton", {
		Size = UDim2.new(0, 0, 0, helpContext.HaveHelp and 33 or 36),
		BackgroundTransparency = 1,
		Image = props.Image,
		ImageColor3 = if not props.IsCurrent and isHovered then Colors.WHITE:Lerp(Colors.BLACK, 0.3) else Colors.WHITE,
		ImageRectOffset = props.ImageRectOffset,
		ScaleType = Enum.ScaleType.Crop,
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
			Color = Colors.WHITE,
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
				HelpRichText = "Choose what pivot point the rotation uses, the one on the inside, middle, or outside of the curve.\n• Outside tends to be the best for parts.\n• Middle tends to be the best for non-boxy models like trees.\n• Inside has use cases where Z-fighting must be avoided.",
			}),
			Subject = e(RotateModeToggle, {
				CurrentSettings = props.CurrentSettings,
				UpdatedSettings = props.UpdatedSettings,
			}),
			LayoutOrder = 2,
		}),
		e(HelpGui.WithHelpIcon, {
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Should the parts in copies next to eachother be resized up to the point where they align? Wedges will be used to fill any large gaps.\n" ..
					"• This will only apply to parts which span the full size of the selection on the axis of duplication.",
			}),
			Subject = e(Checkbox, {
				Label = "Automatic ResizeAlign",
				Checked = props.CurrentSettings.ResizeAlign,
				Changed = function(checked: boolean)
					props.CurrentSettings.ResizeAlign = checked
					props.UpdatedSettings()
				end,
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
		BackgroundColor3 = Colors.ACTION_BLUE,
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
				HelpRichText = "What should the copies be grouped under? If none then the copies will be siblings of the original.",
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
		}),
	})
end

local function SessionTopInfoRow(props: {
	LayoutOrder: number?,
	ShowHelpToggle: boolean,
	Panelized: boolean,
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
			Text = stHovered and "by stravant" or "<i>Redupe</i>",
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
local function updateWindowPosition(settings: Settings.RedupeSettings, size: Vector2, newPositionScreenSpace: Vector2)
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

local function createBeginDragFunction(settings: Settings.RedupeSettings, updatedSettings: () -> ())
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
	CanPlace: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	OnSizeChanged: (Vector2) -> ()?,
}): React.ReactNode
	local nextOrder = createNextOrder()
	local content: {[string]: React.ReactNode} = {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		ListLayout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		-- Don't let things feel crowded at the bottom of the scrolling panel
		Padding = props.Panelized and e("UIPadding", {
			PaddingBottom = UDim.new(0, 40),
		}),
		TopInfoRow = props.Panelized and e(SessionTopInfoRow, {
			LayoutOrder = nextOrder(),
			ShowHelpToggle = true,
			Panelized = true,
			HandleAction = props.HandleAction,
		}),
		OperationPanel = e(OperationPanel, {
			GroupAs = props.CurrentSettings.GroupAs,
			CopyCount = props.CurrentSettings.FinalCopyCount,
			CanPlace = props.CanPlace,
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
		}),
		CopiesPanel = e(CopiesPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		RotationPanel = e(RotationPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		ResultPanel = e(ResultPanel, {
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
	}

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[React.Change.AbsoluteSize] = function(rbx: Frame)
			if props.OnSizeChanged then
				props.OnSizeChanged(rbx.AbsoluteSize)
			end
		end,
	}, content)
end

local function EmptySessionView(props: {
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
})
	local beginDrag = if not props.Panelized then
		createBeginDragFunction(props.CurrentSettings, props.UpdatedSettings)
		else nil

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
		}),
		InfoLabel = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 120),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = "Select at least one Part, Model, or Folder to duplicate.\nThen drag the handles to add or configure duplicates and hit Place to confirm.",
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

local function createBeginResizeFunction(settings: Settings.RedupeSettings, updatedSettings: () -> ())
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
	CanPlace: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
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
					CanPlace = props.CanPlace,
					CurrentSettings = props.CurrentSettings,
					UpdatedSettings = props.UpdatedSettings,
					HandleAction = props.HandleAction,
					Panelized = props.Panelized,
					OnSizeChanged = function(newSize: Vector2)
						setCurrentDisplaySize(newSize.Y + HEADER_SIZE_EXTRA)
					end,
				}),
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
	HasSession: boolean,
	CanPlace: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Active: boolean,
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
		Content = if props.HasSession
			then e(ScrollableSessionView, {
				CanPlace = props.CanPlace,
				CurrentSettings = props.CurrentSettings,
				UpdatedSettings = props.UpdatedSettings,
				HandleAction = props.HandleAction,
				Panelized = false,
			})
			else e(EmptySessionView, {
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

local function MainGuiPanelized(props: {
	HasSession: boolean,
	CanPlace: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Active: boolean,
}): React.ReactNode
	if props.Active then
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
			Content = if props.HasSession
				then e(SessionView, {
					CanPlace = props.CanPlace,
					CurrentSettings = props.CurrentSettings,
					UpdatedSettings = props.UpdatedSettings,
					HandleAction = props.HandleAction,
					Panelized = true,
				})
				else e(EmptySessionView, {
					CurrentSettings = props.CurrentSettings,
					UpdatedSettings = props.UpdatedSettings,
					Panelized = true,
					HandleAction = props.HandleAction,
				}),
			HelpDisplay = e(HelpGui.HelpDisplay, {
				Panelized = true,
			}),
		})
	else
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
					Text = "<font size=\"26\" face=\"SourceSans\">Activate</font> <i>Redupe</i>",
					Font = Enum.Font.SourceSansBold,
					TextSize = 26,
					[React.Event.MouseButton1Click] = function()
						props.HandleAction("reset")
					end,
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
end

local function MainGui(props: {
	HasSession: boolean,
	CanPlace: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	Active: boolean,
})
	return e(HelpGui.Provider, {
		CurrentSettings = props.CurrentSettings,
		UpdatedSettings = props.UpdatedSettings,
	}, {
		Viewport = e(props.Panelized and MainGuiPanelized or MainGuiViewport, {
			HasSession = props.HasSession,
			CanPlace = props.CanPlace,
			CurrentSettings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			Active = props.Active,
		}),
	})
end

return MainGui