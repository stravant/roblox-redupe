export type Placement = {
    Position: CFrame,
    BoundsOffset: Vector3,
    Size: Vector3,
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

local function bendPlacement(placement: Placement, axis: Vector3, relativeBend: CFrame, touchSide: number)
    local relativeOffset = placement.Offset
    local referenceSize = placement.PreviousSize
    local paraSize = referenceSize:Dot(axis)
    local perpSize = referenceSize - axis * paraSize

    local forwardAxis = if axis:Dot(relativeOffset.Position) > 0 then axis else -axis
    local xDir = relativeBend.XVector:Dot(forwardAxis)
    local yDir = relativeBend.YVector:Dot(forwardAxis)
    local zDir = relativeBend.ZVector:Dot(forwardAxis)
    local directions = Vector3.new(approxSign(xDir), approxSign(yDir), approxSign(zDir))

    local perpOffset = CFrame.new(perpSize * directions * touchSide * 0.5)
    local paraOffset = CFrame.new(forwardAxis * referenceSize * 0.5)
    local offsetA = perpOffset * paraOffset
    local offsetB = offsetA:Inverse() * relativeOffset

    local boundsOffset = CFrame.new(placement.BoundsOffset)
    placement.Offset = offsetA * boundsOffset * relativeBend * offsetB * boundsOffset:Inverse()
end

return bendPlacement