export type Placement = {
	Position: CFrame,
	BoundsOffset: Vector3,
	Size: Vector3,
	SizePadding: Vector3,
	PreviousSize: Vector3,
	Offset: CFrame,
}

local function approxSign(n: number)
	if math.abs(n) < 0.001 then
		return 0
	else
		return math.sign(n)
	end
end

local function fixZeroSize(v: Vector3): Vector3
	return Vector3.new(
		(v.X > 0.01) and v.X or 1,
		(v.Y > 0.01) and v.Y or 1,
		(v.Z > 0.01) and v.Z or 1
	)
end

local function bendPlacement(placement: Placement, axis: Vector3, relativeBend: CFrame,
	touchSide: number, paddingAmount: number, spacingMultiplier: number)
	local relativeOffset = placement.Offset
	local referenceSize = placement.PreviousSize
	local paraSize = referenceSize:Dot(axis)
	local perpSize = referenceSize - axis * paraSize

	local forwardAxis = if axis:Dot(relativeOffset.Position) > 0 then axis else -axis
	local xDir = relativeBend.XVector:Dot(forwardAxis)
	local yDir = relativeBend.YVector:Dot(forwardAxis)
	local zDir = relativeBend.ZVector:Dot(forwardAxis)
	local directions = Vector3.new(approxSign(xDir), approxSign(yDir), approxSign(zDir))

	-- Apply padding and spacing before using the reference size
	-- (bit messy, I shouldn't really be scaling the perp components here
	-- but they don't get used in the subsequent code)
	referenceSize *= spacingMultiplier
	referenceSize += axis * paddingAmount
	referenceSize = fixZeroSize(referenceSize) -- Ensure the settings didn't result in zero size

	local perpOffset = CFrame.new(perpSize * directions * touchSide * 0.5)
	local paraOffset = CFrame.new(forwardAxis * referenceSize * 0.5)
	local offsetA = perpOffset * paraOffset
	local offsetB = offsetA:Inverse() * relativeOffset

	local boundsOffset = CFrame.new(placement.BoundsOffset)
	placement.Offset = offsetA * boundsOffset * relativeBend * offsetB * boundsOffset:Inverse()
end

return bendPlacement