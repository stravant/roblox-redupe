-- Does it make sense to wedge fill a given part when extruding? It only makes sense if the part extends
-- out to all 6 corners of its bounding box.
local WEDGE_FILLABLE_CLOSENESS_TO_CORNER = 0.02
local corners = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

local WEDGE_FILLABLE_TEST_PART;
local function getTestPart(position: Vector3)
	if not WEDGE_FILLABLE_TEST_PART then
		WEDGE_FILLABLE_TEST_PART = Instance.new("Part")
		WEDGE_FILLABLE_TEST_PART.Size = Vector3.one * 0.01
	end
	WEDGE_FILLABLE_TEST_PART.Position = position
	return WEDGE_FILLABLE_TEST_PART
end

local function isWedgeFillable(a: Part): boolean
	for _, corner in corners do
		local offset = corner * (a.Size * 0.5 - Vector3.one * WEDGE_FILLABLE_CLOSENESS_TO_CORNER)
		local worldPoint = a.CFrame:PointToWorldSpace(offset)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params:AddToFilter(a)
		if #workspace:GetPartsInPart(getTestPart(worldPoint), params) == 0 then
			return false
		end
	end
	return true
end

return isWedgeFillable