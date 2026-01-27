--!strict
local TextService = game:GetService("TextService")

local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local Colors = require("./Colors")

local function _GoodSubPanel(props: {
	Title: string,
	Padding: UDim?,
	LayoutOrder: number?,
	children: React.ReactElement<any>?,
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
			Color3 = Colors.OFFWHITE,
			ref = outlineRef,
		}),
		TitleLabel = e("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromOffset(INSET * 2, -3),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			TextColor3 = Colors.OFFWHITE,
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

local function SubPanel(props: {
	Title: string,
	Padding: UDim?,
	LayoutOrder: number?,
	children: React.ReactElement<any>?,
})
	local TITLE_PADDING = 2
	local INSET = 6
	local TITLE_SIZE = 2 * INSET + 2

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
		TitleLabel = e("TextLabel", {
			Size = UDim2.fromScale(0, 0),
			Position = UDim2.fromOffset(INSET * 2, -4),
			AutomaticSize = Enum.AutomaticSize.XY,
			BorderSizePixel = 0,
			BackgroundColor3 = Colors.BLACK,
			TextColor3 = Colors.OFFWHITE,
			Text = props.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.SourceSansBold,
			TextSize = TITLE_SIZE,
			ZIndex = 2,
		}, {
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, TITLE_PADDING),
				PaddingRight = UDim.new(0, TITLE_PADDING),
			}),
		}),
		BorderHolder = e("Frame", {
			Position = UDim2.fromOffset(INSET, INSET),
			Size = UDim2.new(1, -(INSET * 2), 1, 0),
			BackgroundTransparency = 1,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 5),
			}),
			Stroke = e("UIStroke", {
				Color = Colors.OFFWHITE,
				BorderOffset = UDim.new(0, -1),
				Thickness = 1.6,
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

return SubPanel