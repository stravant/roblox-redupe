
local Workspace = game:GetService("Workspace")

local Packages = script.Parent.Parent.Parent.Packages
local Roact = require(Packages.Roact)
local DraggerFramework = require(Packages.DraggerFramework)
local Math = require(DraggerFramework.Utility.Math)

local getEngineFeatureModelPivotVisual = require(DraggerFramework.Flags.getEngineFeatureModelPivotVisual)

local CULLING_MODE = Enum.AdornCullingMode.Never

local MoveHandleView = Roact.PureComponent:extend("MoveHandleView")

local BASE_HANDLE_RADIUS = 0.10
local BASE_HANDLE_HITTEST_RADIUS = BASE_HANDLE_RADIUS * 4 -- Handle hittests bigger than it looks
local BASE_HANDLE_OFFSET = 0.60
local BASE_HANDLE_LENGTH = 2.50
local DOUBLE_HANDLE_LENGTH = 4.00
local BASE_TIP_OFFSET = 0.20
local BASE_TIP_LENGTH = 0.25
local TIP_RADIUS_MULTIPLIER = 3
local SCREENSPACE_HANDLE_SIZE = 6
local HANDLE_DIM_TRANSPARENCY = 0.45
local HANDLE_THIN_BY_FRAC = 0.34
local HANDLE_THICK_BY_FRAC = 1.5
local DUPLICATE_SIZE = Vector3.new(0.9, 0.9, 0.15)
local DUPLICATE_SIZE_ADJUST = Vector3.new(0.1, 0.1, 0)
local DUPLICATE_OFFSET_AMOUNT = 0.4

function MoveHandleView:init()
end

function MoveHandleView:render()
	local scale = self.props.Scale

	local doubleHandle = self.props.DoubleHandle
	local length = scale * BASE_HANDLE_LENGTH
	if doubleHandle then
		length = scale * DOUBLE_HANDLE_LENGTH
	end
	local radius = scale * BASE_HANDLE_RADIUS
	local offset = scale * BASE_HANDLE_OFFSET
	if getEngineFeatureModelPivotVisual() then
		offset = offset + length * (self.props.Outset or 0)
	end
	offset += self.props.FixedOutset
	local tipLength = length * BASE_TIP_LENGTH
	if self.props.Thin then
		radius = radius * HANDLE_THIN_BY_FRAC
	end
	if self.props.Hovered then
		radius = radius * HANDLE_THICK_BY_FRAC
		tipLength = tipLength * HANDLE_THICK_BY_FRAC
	end

	local coneAtCFrame = self.props.Axis * CFrame.new(0, 0, -(offset + length))
	local cone2AtCFrame = coneAtCFrame * CFrame.new(0, 0, 0.5 * scale)

	coneAtCFrame *= CFrame.new(0, 0, scale * 0.3)
	length -= scale * 0.3

	local children = {}
	if not self.props.Hovered then
		children.Shaft = Roact.createElement("CylinderHandleAdornment", {
			Adornee = Workspace.Terrain, -- Just a neutral anchor point
			ZIndex = 0,
			Radius = radius,
			Height = length,
			CFrame = self.props.Axis * CFrame.new(0, 0, -(offset + length * 0.5)),
			Color3 = self.props.Color,
			AlwaysOnTop = false,
			AdornCullingMode = CULLING_MODE,
		})
		if not self.props.Thin then
			if doubleHandle then
				for i = 0, 2 do
					children["Head"..i] = Roact.createElement("BoxHandleAdornment", {
						Adornee = Workspace.Terrain,
						ZIndex = 2,
						Size = (DUPLICATE_SIZE - DUPLICATE_SIZE_ADJUST * i) * scale,
						CFrame = coneAtCFrame * CFrame.new(0, 0, -i * scale * DUPLICATE_OFFSET_AMOUNT),
						Color3 = self.props.Color,
						AlwaysOnTop = false,
						Transparency = 0.6,
						AdornCullingMode = CULLING_MODE,
					})
				end
			else
				children.Head = Roact.createElement("ConeHandleAdornment", {
					Adornee = Workspace.Terrain,
					ZIndex = 0,
					Radius = TIP_RADIUS_MULTIPLIER * radius,
					Height = tipLength,
					CFrame = cone2AtCFrame,
					Color3 = self.props.Color,
					AlwaysOnTop = false,
					AdornCullingMode = CULLING_MODE,
				})
			end
		end
	end

	children.DimmedShaft = Roact.createElement("CylinderHandleAdornment", {
		Adornee = Workspace.Terrain, -- Just a neutral anchor point
		ZIndex = 0,
		Radius = radius,
		Height = length,
		CFrame = self.props.Axis * CFrame.new(0, 0, -(offset + length * 0.5)),
		Color3 = self.props.Color,
		AlwaysOnTop = true,
		Transparency = self.props.Hovered and 0.0 or HANDLE_DIM_TRANSPARENCY,
		AdornCullingMode = CULLING_MODE,
	})
	if not self.props.Thin then
		if doubleHandle then
			for i = 0, 2 do
				children["HeadOnTop"..i] = Roact.createElement("BoxHandleAdornment", {
					Adornee = Workspace.Terrain,
					ZIndex = 0,
					Size = (DUPLICATE_SIZE - DUPLICATE_SIZE_ADJUST * i) * scale,
					CFrame = coneAtCFrame * CFrame.new(0, 0, -i * scale * DUPLICATE_OFFSET_AMOUNT),
					Color3 = self.props.Color,
					AlwaysOnTop = true,
					Transparency = self.props.Hovered and 0.0 or 0.5,
					AdornCullingMode = CULLING_MODE,
				})
			end
		else
			children.Head = Roact.createElement("ConeHandleAdornment", {
				Adornee = Workspace.Terrain,
				ZIndex = 0,
				Radius = TIP_RADIUS_MULTIPLIER * radius,
				Height = tipLength,
				CFrame = cone2AtCFrame,
				Color3 = self.props.Color,
				AlwaysOnTop = true,
				Transparency = self.props.Hovered and 0.0 or HANDLE_DIM_TRANSPARENCY,
				AdornCullingMode = CULLING_MODE,
			})
		end
	end

	return Roact.createElement("Folder", {}, children)
end

function MoveHandleView.hitTest(props, mouseRay)
	local scale = props.Scale

	local length = scale * BASE_HANDLE_LENGTH
	if props.DoubleHandle then
		length = scale * DOUBLE_HANDLE_LENGTH
	end
	local radius = scale * BASE_HANDLE_HITTEST_RADIUS
	local tipRadius = radius * TIP_RADIUS_MULTIPLIER
	local offset = scale * BASE_HANDLE_OFFSET
	if getEngineFeatureModelPivotVisual() then
		offset = offset + length * (props.Outset or 0)
	end
	offset += props.FixedOutset
	local tipOffset = scale * BASE_TIP_OFFSET
	local tipLength = length * BASE_TIP_LENGTH
	local shaftEnd = offset + length

	if not props.AlwaysOnTop then
		-- Check the always on top 2D element at the tip of the vector
		local tipAt = props.Axis * Vector3.new(0, 0, -(offset + length + tipOffset))
		local tipAtScreen, _ = Workspace.CurrentCamera:WorldToScreenPoint(tipAt)
		local mouseAtScreen = Workspace.CurrentCamera:WorldToScreenPoint(mouseRay.Origin)
		local halfHandleSize = 0.5 * SCREENSPACE_HANDLE_SIZE
		if mouseAtScreen.X > tipAtScreen.X - halfHandleSize and
			mouseAtScreen.Y > tipAtScreen.Y - halfHandleSize and
			mouseAtScreen.X < tipAtScreen.X + halfHandleSize and
			mouseAtScreen.Y < tipAtScreen.Y + halfHandleSize
		then
			return 0
		end
	end

	local hasIntersection, hitDistance =
		Math.intersectRayRay(
			props.Axis.Position, props.Axis.LookVector,
			mouseRay.Origin, mouseRay.Direction.Unit)

	if not hasIntersection then
		return nil
	end

	-- Must have an intersection if the above intersect did
	local _, distAlongMouseRay =
		Math.intersectRayRay(
			mouseRay.Origin, mouseRay.Direction.Unit,
			props.Axis.Position, props.Axis.LookVector)

	local hitRadius =
		((props.Axis.Position + props.Axis.LookVector * hitDistance) -
		(mouseRay.Origin + mouseRay.Direction.Unit * distAlongMouseRay)).Magnitude

	if hitRadius < radius and hitDistance > offset and hitDistance < shaftEnd then
		return distAlongMouseRay
	elseif hitRadius < tipRadius and hitDistance > shaftEnd and hitDistance < shaftEnd + tipLength then
		return distAlongMouseRay
	else
		return nil
	end
end

--[[
	Returns:
		float Offset - From base CFrame
		float Size - Extending from CFrame + Offset
]]
function MoveHandleView.getHandleDimensionForScale(scale, outset, fixedOutset, doubled)
	local length = scale * BASE_HANDLE_LENGTH
	if doubled then
		length = scale * DOUBLE_HANDLE_LENGTH
	end
	local offset = scale * BASE_HANDLE_OFFSET
	if getEngineFeatureModelPivotVisual() then
		offset = offset + length * (outset or 0)
	end
	offset += fixedOutset
	local tipLength = length * BASE_TIP_LENGTH
	return offset, length + tipLength
end

return MoveHandleView