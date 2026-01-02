
local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local Colors = require("./PluginGui/Colors")
local HelpGui = require("./PluginGui/HelpGui")
local SubPanel = require("./PluginGui/SubPanel")
local ChipForToggle = require("./PluginGui/ChipForToggle")
local NumberInput = require("./PluginGui/NumberInput")
local Checkbox = require("./PluginGui/Checkbox")
local Vector3Input = require("./PluginGui/Vector3Input")
local PluginGui = require("./PluginGui/PluginGui")
local OperationButton = require("./PluginGui/OperationButton")
local Settings = require("./Settings")
local PluginGuiTypes = require("./PluginGui/Types")

local e = React.createElement

local function createNextOrder()
	local order = 0
	return function()
		order += 1
		return order
	end
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

	return e(Vector3Input, {
		Value = Vector3.new(xDegrees, yDegrees, zDegrees),
		ValueEntered = function(newValue: Vector3)
			local thetaX = math.rad(newValue.X)
			local thetaY = math.rad(newValue.Y)
			local thetaZ = math.rad(newValue.Z)
			local rotation = CFrame.fromEulerAnglesXYZ(thetaX, thetaY, thetaZ)
			props.CurrentSettings.Rotation = rotation
			props.UpdateSettings()
			return nil
		end,
		Unit = "°",
		LayoutOrder = props.LayoutOrder,
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

local REDUPE_CONFIG: PluginGuiTypes.PluginGuiConfig = {
	PluginName = "Redupe",
	PendingText = "Select at least one Part, Model, or Folder to duplicate.\nThen drag the handles to add or configure duplicates and hit Place to confirm.",
}

local function RedupeGui(props: {
	GuiState: PluginGuiTypes.PluginGuiMode,
	CanPlace: boolean,
	CurrentSettings: Settings.RedupeSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
})
	local nextOrder = createNextOrder()
	return e(PluginGui, {
		Config = REDUPE_CONFIG,
		State = {
			Mode = props.GuiState,
			Settings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			Panelized = props.Panelized,
		},
	}, {
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
	})
end

return RedupeGui
