--!strict
local Plugin = script.Parent.Parent.Parent
local Packages = Plugin.Packages

local React = require(Packages.React)
local e = React.createElement

local NumberInput = require("./NumberInput")

local function Vector3Input(props: {
	Value: Vector3,
	ValueEntered: (newValue: Vector3) -> Vector3?,
	LayoutOrder: number?,
	Unit: string?,
})
	local value = props.Value
	local unit = props.Unit
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
			Unit = unit,
			Value = value.X,
			Grow = true,
			ChipColor = Color3.fromRGB(255, 0, 0),
			ValueEntered = function(newValue: number)
				local result = props.ValueEntered(Vector3.new(newValue, value.Y, value.Z))
				return result and result.X or nil
			end,
			LayoutOrder = 1,
		}),
		YCoord = e(NumberInput, {
			Unit = unit,
			Value = value.Y,
			Grow = true,
			ChipColor = Color3.fromRGB(0, 255, 0),
			ValueEntered = function(newValue: number)
				local result = props.ValueEntered(Vector3.new(value.X, newValue, value.Z))
				return result and result.Y or nil
			end,
			LayoutOrder = 2,
		}),
		ZCoord = e(NumberInput, {
			Unit = unit,
			Value = value.Z,
			Grow = true,
			ChipColor = Color3.fromRGB(0, 0, 255),
			ValueEntered = function(newValue: number)
				local result = props.ValueEntered(Vector3.new(value.X, value.Y, newValue))
				return result and result.Z or nil
			end,
			LayoutOrder = 3,
		}),
	})
end

return Vector3Input