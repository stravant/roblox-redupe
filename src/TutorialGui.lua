--!strict
local Plugin = script.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local PluginGuiTypes = require("./PluginGui/Types")

type Cursor = {
	Image: number,
	Hotspot: Vector2,
}

type TutorialFrame = {
	Name: string?,
	Image: number,
	Cursor: Cursor,
	CursorTo: Vector2,
	Time: number,
	Patch: {
		Image: number,
		Offset: Vector2,
		Size: Vector2,
	}?,
}

local ARROW_CURSOR = {
	Image = 128057478178427,
	Hotspot = Vector2.new(0, 0),
}

local HAND_CURSOR = {
	Image = 134484825430690,
	Hotspot = Vector2.new(14, 0),
}

local DRAG_CURSOR = {
	Image = 132203529888501,
	Hotspot = Vector2.new(22, 22),
}

local DIAGONAL_MOVE_TIME = 0.15

local TUTORIAL_FRAMES: { TutorialFrame } = {
	{
		Name = "1-Initial",
		Image = 75050221081608,
		Cursor = ARROW_CURSOR,
		CursorTo = Vector2.new(48, 70),
		Time = 0.7,
	},
	{
		Name = "2-Hovered",
		Image = 75050221081608,
		Cursor = HAND_CURSOR,
		CursorTo = Vector2.new(48, 70),
		Time = 0.5,
		Patch = {
			Image = 86606991484716,
			Offset = Vector2.new(26, 44),
			Size = Vector2.new(74, 52),
		},
	},
	{
		Name = "3-Dragged",
		Image = 75050221081608,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(68, 78),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 108080532060445,
			Offset = Vector2.new(12, 4),
			Size = Vector2.new(166, 156),
		},
	},
	{
		Name = "4-Dragged-1",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(88, 86),
		Time = DIAGONAL_MOVE_TIME,
	},
	{
		Name = "5-Dragged-2",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(111, 96),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 111320293274480,
			Offset = Vector2.new(50, 50),
			Size = Vector2.new(140, 96),
		}
	},
	{
		Name = "6-Dragged-3",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(134, 105),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 138697761644022,
			Offset = Vector2.new(50, 50),
			Size = Vector2.new(160, 110),
		}
	},
	{
		Name = "7-Dragged-4",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(158, 115),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 136482821433845,
			Offset = Vector2.new(50, 50),
			Size = Vector2.new(180, 118),
		}
	},
	{
		Name = "8-Dragged-5",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(184, 125),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 122065601160295,
			Offset = Vector2.new(50, 50),
			Size = Vector2.new(202, 128),
		}
	},
	{
		Name = "9-Dragged-6",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(211, 137),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 74680082884381,
			Offset = Vector2.new(50, 50),
			Size = Vector2.new(230, 142),
		}
	},
	{
		Name = "10-Dragged-7",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(240, 149),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 128559094321411,
			Offset = Vector2.new(50, 50),
			Size = Vector2.new(260, 150),
		}
	},
	{
		Name = "11-Dragged-8",
		Image = 80415272551302,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(240, 149),
		Time = DIAGONAL_MOVE_TIME,
		Patch = {
			Image = 94248666015643,
			Offset = Vector2.new(50, 50),
			Size = Vector2.new(290, 150),
		}
	},
	{
		Name = "12-Ready-for-Resize",
		Image = 140562938083636,
		Cursor = ARROW_CURSOR,
		CursorTo = Vector2.new(310, 153),
		Time = 0.7,
	},
	{
		Name = "13-Resize-Hovered",
		Image = 140562938083636,
		Cursor = HAND_CURSOR,
		CursorTo = Vector2.new(310, 153),
		Time = 0.5,
		Patch = {
			Image = 94112898903367,
			Offset = Vector2.new(296, 140),
			Size = Vector2.new(30, 26),
		}
	},
	{
		Name = "14-Resize-Pressed",
		Image = 136564990635799,
		Cursor = DRAG_CURSOR,
		CursorTo = Vector2.new(331, 24),
		Time = 0.8,
	},
	{
		Name = "15-Resize-Done",
		Image = 77520850237094,
		Cursor = ARROW_CURSOR,
		CursorTo = Vector2.new(331, 24),
		Time = 0.5,
	},
	{
		Name = "16-Final",
		Image = 85709093730575,
		Cursor = ARROW_CURSOR,
		CursorTo = Vector2.new(70, 179),
		Time = 0.7,
	},
	{
		Name = "16-Final-MouseStayStill",
		Image = 85709093730575,
		Cursor = HAND_CURSOR,
		CursorTo = Vector2.new(70, 179),
		Time = 1.5,
	},
	{
		Name = "17-Grouped-Result",
		Image = 106152498074872,
		Cursor = ARROW_CURSOR,
		CursorTo = Vector2.new(70, 179),
		Time = 1.0,
	},
}

local function populateFrame(tutorialFrame: TutorialFrame, image: ImageLabel, patch: ImageLabel)
	image.ImageContent = Content.fromAssetId(tutorialFrame.Image)
	if tutorialFrame.Patch then
		patch.Visible = true
		patch.ImageContent = Content.fromAssetId(tutorialFrame.Patch.Image)
		patch.ImageRectSize = tutorialFrame.Patch.Size
		patch.Position = UDim2.fromOffset(
			tutorialFrame.Patch.Offset.X / 2,
			tutorialFrame.Patch.Offset.Y / 2
		)
		patch.Size = UDim2.fromOffset(
			tutorialFrame.Patch.Size.X / 2,
			tutorialFrame.Patch.Size.Y / 2
		)
	else
		patch.Visible = false
	end
end

local function runTutorial(image: ImageLabel)
	local ended = false
	local patchFrame = Instance.new("ImageLabel")
	patchFrame.BackgroundTransparency = 1
	patchFrame.ImageContent = Content.none
	patchFrame.Parent = image
	local cursor = Instance.new("ImageLabel")
	cursor.BackgroundTransparency = 1
	cursor.ImageContent = Content.none
	cursor.Size = UDim2.fromOffset(32, 32)
	cursor.Parent = image

	-- Gather assetIds to preload
	local assetIdsToPreload: { [number]: boolean } = {}
	for _, tutorialFrame in TUTORIAL_FRAMES do
		assetIdsToPreload[tutorialFrame.Image] = true
		assetIdsToPreload[tutorialFrame.Cursor.Image] = true
		if tutorialFrame.Patch then
			assetIdsToPreload[tutorialFrame.Patch.Image] = true
		end
	end
	local hiddenFrames = {} :: { [number]: ImageLabel }
	for assetId, _ in assetIdsToPreload do
		local hiddenFrame = Instance.new("ImageLabel")
		hiddenFrame.BackgroundTransparency = 1
		hiddenFrame.ImageTransparency = 0.99
		hiddenFrame.ImageContent = Content.fromAssetId(assetId)
		hiddenFrame.Size = UDim2.fromOffset(1, 1)
		hiddenFrame.Visible = true
		hiddenFrame.Parent = image
		hiddenFrames[assetId] = hiddenFrame
	end

	local function getAssetIdsForFrame(tutorialFrame: TutorialFrame): { number }
		local ids = { tutorialFrame.Image, tutorialFrame.Cursor.Image }
		if tutorialFrame.Patch then
			table.insert(ids, tutorialFrame.Patch.Image)
		end
		return ids
	end

	task.spawn(function()
		local frame = 1
		while not ended do
			if frame == 1 then
				-- Reset cursor position
				cursor.Position = UDim2.fromOffset(0, 0)
			end
			local tutorialFrame = TUTORIAL_FRAMES[frame]
			for _, assetId in getAssetIdsForFrame(tutorialFrame) do
				while not hiddenFrames[assetId].IsLoaded do
					task.wait()
				end
			end
			populateFrame(tutorialFrame, image, patchFrame)
			cursor.ImageContent = Content.fromAssetId(tutorialFrame.Cursor.Image)
			cursor.AnchorPoint = Vector2.new(
				tutorialFrame.Cursor.Hotspot.X / 64,
				tutorialFrame.Cursor.Hotspot.Y / 64
			)
			local frameTime = tutorialFrame.Time
			local cursorTo = UDim2.fromOffset(
				tutorialFrame.CursorTo.X / 2,
				tutorialFrame.CursorTo.Y / 2
			)
			cursor:TweenPosition(cursorTo, Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, frameTime, true)
			-- Next frame
			frame += 1
			if frame > #TUTORIAL_FRAMES then
				frame = 1
			end
			task.wait(frameTime)
		end
	end)
	return function()
		cursor:Destroy()
		patchFrame:Destroy()
		for _, hiddenFrame in hiddenFrames do
			hiddenFrame:Destroy()
		end
		ended = true
	end
end

local function TutorialGui(props: PluginGuiTypes.TutorialElementProps)
	-- Run the tutorial in the tutorial frame using imperative code
	local ref = React.createRef()
	React.useEffect(function()
		if ref.current then
			return runTutorial(ref.current)
		else
			return function() end
		end
	end, {ref.current})

	return e("ImageButton", {
		Size = UDim2.fromOffset(228, 100),
		Position = UDim2.fromOffset(255, 5),
		BackgroundColor3 = Color3.new(0.372549, 0.372549, 0.372549),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 0,
		ZIndex = 2, -- on top of the SessionView in the MainGui
	}, {
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = 4,
		}),
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		AnimatedLabel = e("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(228, 100),
			ImageContent = Content.none,
			ZIndex = 2,
			ref = ref,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
		}),
		HowToText = e("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(4, 0),
			BackgroundTransparency = 1,
			Text = "How to use:",
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Enum.Font.SourceSansBold,
			TextSize = 20,
			ZIndex = 3,
		}, {
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		}),
		GotItButton = e("TextButton", {
			Size = UDim2.fromOffset(60, 24),
			Position = UDim2.new(1, 10, 1, 10),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = Color3.fromRGB(0, 170, 0),
			Text = "Got it!",
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.SourceSansBold,
			TextSize = 20,
			ZIndex = 4,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.ClickedDone()
			end,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			TextStroke = e("UIStroke", {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
			BorderStroke = e("UIStroke", {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
	})
end

return TutorialGui