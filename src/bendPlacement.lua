export type Placement = {
    Position: CFrame,
    Size: Vector3,
    PreviousSize: Vector3,
    Offset: CFrame,
}

local function bendPlacement(placement: Placement, axis: Vector3, angles: CFrame)
    -- Divide the offset proportionally based on size (this approach works even if
    -- there is overlap between the two)
    local offset = placement.Offset
    local sizeA = placement.PreviousSize:Dot(axis)
    local sizeB = placement.Size:Dot(axis)
    local fracA = sizeA / (sizeA + sizeB)
    local offsetA = CFrame.new():Lerp(offset, fracA)
    local offsetB = offsetA:ToObjectSpace(offset)

    placement.Offset = offsetA * angles * offsetB
end

return bendPlacement