--!native
--!optimize 2
type ResizeAlignInfo = {
	CFrame: CFrame,
	Offset: Vector3,
	Size: Vector3,
}

export type ResizeAlignPairsCache = {
	[number]: boolean?, -- Is Wedge fillable mesh
}

local RESIZE_TAG = "RD_S"
local FILL_TAG = "RD_W"
local FILL_NAME_SUFFIX = "FillW"

local MIN_ZFIGHT_AREA = 0.5
local SPANS_FULL_WIDTH_EPSILON = 0.051

local copyInstanceProperties = require("./copyInstanceProperties")
local isWedgeFillable = require("./isWedgeFillable")

--[[
	The return value `t` is a number such that `r1o + t * r1d` is the point of
	closest approach on the first ray between the two rays specified by the
	arguments.
]]
local function intersectRayRay(r1o, r1d, r2o, r2d)
	local n =
		(r2o - r1o):Dot(r1d) * r2d:Dot(r2d) +
		(r1o - r2o):Dot(r2d) * r1d:Dot(r2d)
	local d =
		r1d:Dot(r1d) * r2d:Dot(r2d) -
		r1d:Dot(r2d) * r1d:Dot(r2d)
	if d == 0 then
		return false
	else
		return true, n / d
	end
end

-- Insersect Ray(a + t*b) with plane (origin: o, normal: n), return t of the interesection
function intersectRayPlane(a, b, o, n)
	return (o - a):Dot(n) / b:Dot(n)
end

local function isRotationWorldAlignedModulo90Degrees(cframe: CFrame): boolean
	local x = cframe.XVector:Abs()
	local y = cframe.YVector:Abs()
	local z = cframe.ZVector:Abs()
	if math.abs(x.X + x.Y + x.Z - 1) > 0.001 then
		return false
	end
	if math.abs(y.X + y.Y + y.Z - 1) > 0.001 then
		return false
	end
	if math.abs(z.X + z.Y + z.Z - 1) > 0.001 then
		return false
	end
	return true
end

local function isCandidateForResizing(a: Part, aBasis: ResizeAlignInfo, axis: Vector3): boolean
	local cframeInBasis = aBasis.CFrame:ToObjectSpace(a.CFrame)
	if not isRotationWorldAlignedModulo90Degrees(cframeInBasis) then
		return false
	end

	-- Already resized once, always allow even if it doesn't exactly span the
	-- bounds along the axis anymore.
	if a:HasTag(RESIZE_TAG) then
		return true
	end

	-- Check that the part exactly spans the bounds along the axis.

	-- Size must match
	local sizeInBasis = aBasis.CFrame:VectorToObjectSpace(a.CFrame:VectorToWorldSpace(a.Size)):Abs()
	local size = sizeInBasis:Dot(axis)
	if math.abs(size - aBasis.Size:Dot(axis)) > SPANS_FULL_WIDTH_EPSILON * 2 then -- Deliberately a bit loose of an epsilon here
		return false
	end

	-- Position must be centered
	local positionInBounds = cframeInBasis.Position - aBasis.Offset
	local position = positionInBounds:Dot(axis)
	if math.abs(position) > SPANS_FULL_WIDTH_EPSILON then
		return false
	end

	-- Checks for appropriate part shape
	if a:IsA("Part") then
		if a.Shape == Enum.PartType.Ball then
			-- Nothing to do for balls
			return false
		elseif a.Shape == Enum.PartType.Cylinder then
			-- Check for correct orientation (can only resize along cylinder axis)
			local cylinderAxis = aBasis.CFrame:VectorToObjectSpace(a.CFrame.XVector):Abs()
			if not cylinderAxis:FuzzyEq(axis) then
				return false
			end
		end
	end

	return true
end

local function approxSign(n: number)
	if math.abs(n) < 0.0001 then
		return 0
	else
		return math.sign(n)
	end
end

local function closestUnitVector(forCFrame: CFrame, to: Vector3): Vector3
	local bestDot = -math.huge
	local bestVector = Vector3.zero
	local candidates = {
		forCFrame.XVector,
		forCFrame.YVector,
		forCFrame.ZVector,
		-forCFrame.XVector,
		-forCFrame.YVector,
		-forCFrame.ZVector,
	}
	for _, candidate in candidates do
		local dot = candidate:Dot(to)
		if dot > bestDot then
			bestDot = dot
			bestVector = candidate
		end
	end
	return bestVector
end

local function maybeRemoveWedgeAtLocation(location: Vector3, expectedName: string)
	local found = workspace:GetPartBoundsInRadius(location, 0.001)
	for _, part in found do
		if part:HasTag(FILL_TAG) and part.Name == expectedName then
			part.Parent = nil
		end
	end
end

local function getPartSizeIncludingSpecialMeshScale(part: Part): (Vector3, Vector3, Vector3)
	local mesh = part:FindFirstChildWhichIsA("DataModelMesh")
	if mesh then
		return part.Size * mesh.Scale, mesh.Scale, mesh.Offset
	else
		return part.Size, Vector3.one, Vector3.zero
	end
end

-- Make a wedge as similar to a given BasePart as possible
local function makeWedge(a: BasePart)
	if a:IsA("Part") then
		local copy = Instance.fromExisting(a)
		copy.Shape = Enum.PartType.Wedge
		copy.PivotOffset = CFrame.identity
		return copy
	else
		local wedge = Instance.new("Part")
		copyInstanceProperties(a, wedge)
		wedge.Shape = Enum.PartType.Wedge
		wedge.PivotOffset = CFrame.identity
		return wedge
	end
end

local function makeBall(a: BasePart)
	local wedge = makeWedge(a)
	wedge.Shape = Enum.PartType.Ball
	return wedge
end

local function smallestNonZeroComponent(v: Vector3): number
	local best = math.huge
	if v.X > 0.01 then
		best = v.X
	end
	if v.Y > 0.01 and v.Y < best then
		best = v.Y
	end
	if v.Z > 0.01 and v.Z < best then
		best = v.Z
	end
	return best
end

local function resizeAlignPair(a: Part, b: Part, aBasis: ResizeAlignInfo, bBasis: ResizeAlignInfo, axis: Vector3, cache: ResizeAlignPairsCache, cacheIndex: number, resultList: {Instance}?)
	if not isCandidateForResizing(a, aBasis, axis) then
		return
	end

	-- aBasis.Basis * offset = bBasis.Basis
	assert(aBasis.CFrame ~= bBasis.CFrame, "Same?")
	local localOffset = aBasis.CFrame:ToObjectSpace(bBasis.CFrame)
	local localSign = math.sign(localOffset.Position:Dot(axis))
	local localSignedAxis = localSign * axis
	local aWorldAxis = aBasis.CFrame:VectorToWorldSpace(localSignedAxis)
	local bWorldAxis = bBasis.CFrame:VectorToWorldSpace(localSignedAxis)

	local aSize, aSizeScale, aVisualOffset = getPartSizeIncludingSpecialMeshScale(a)
	local bSize, bSizeScale, bVisualOffset = getPartSizeIncludingSpecialMeshScale(b)
	local aWorldVisualOffset = a.CFrame:VectorToWorldSpace(aVisualOffset)
	local bWorldVisualOffset = b.CFrame:VectorToWorldSpace(bVisualOffset)

	-- sizingAxis and perpendicular axis in the space of the part
	local sizingAxis = a.CFrame:VectorToObjectSpace(aBasis.CFrame:VectorToWorldSpace(axis)):Abs()
	local perpAxis = Vector3.one - axis
	local sizingPerpToAxis = a.CFrame:VectorToObjectSpace(aBasis.CFrame:VectorToWorldSpace(perpAxis)):Abs()

	-- Side to offset towards in the space of the part
	local relativeOffset = aBasis.CFrame:ToObjectSpace(bBasis.CFrame)
	local xDir = relativeOffset.XVector:Dot(localSignedAxis)
	local yDir = relativeOffset.YVector:Dot(localSignedAxis)
	local zDir = relativeOffset.ZVector:Dot(localSignedAxis)
	local directions = Vector3.new(approxSign(xDir), approxSign(yDir), approxSign(zDir))
	local sizingPerpDirections = a.CFrame:VectorToObjectSpace(aBasis.CFrame:VectorToWorldSpace(directions))	
	local offsetPerpCorrectSideA = sizingPerpToAxis * sizingPerpDirections * aSize * 0.5
	local offsetPerpCorrectSideB = sizingPerpToAxis * sizingPerpDirections * bSize * 0.5
	if not offsetPerpCorrectSideA:FuzzyEq(offsetPerpCorrectSideB) then
		-- Not interested in weird asymmetric fills here
		-- We could do something here but since we're doing each resize-align pairwise
		-- only without an overarching plan, this case will oscillate between
		-- different kinds of fill with when called multiple times for different
		-- sized things along the duplication path giving a bad feel.
		return
	end

	-- If the two objects are exactly overlapping we can't determine which side
	-- the rotation was towards.
	if directions == Vector3.zero then
		return
	end

	-- Do intersection
	local alignOuterPointA = a.CFrame:PointToWorldSpace(-offsetPerpCorrectSideA)
	local alignOuterPointB = b.CFrame:PointToWorldSpace(-offsetPerpCorrectSideB)
	local alignInnerPointA = a.CFrame:PointToWorldSpace(offsetPerpCorrectSideA)
	local alignInnerPointB = b.CFrame:PointToWorldSpace(offsetPerpCorrectSideB)

	local good1, aBaseOuterLength = intersectRayRay(alignOuterPointA, aWorldAxis, alignOuterPointB, -bWorldAxis)
	local good2, bBaseOuterLength = intersectRayRay(alignOuterPointB, -bWorldAxis, alignOuterPointA, aWorldAxis)
	local good3, aBaseInnerLength = intersectRayRay(alignInnerPointA, aWorldAxis, alignInnerPointB, -bWorldAxis)
	local good4, bBaseInnerLength = intersectRayRay(alignInnerPointB, -bWorldAxis, alignInnerPointA, aWorldAxis)
	if not good1 or not good2 or not good3 or not good4 then
		warn("Failed to intersect rays for resize-align?")
		return
	end

	local aOriginalLength = (aSize * sizingAxis).Magnitude
	local bOriginalLength = (b.Size * sizingAxis).Magnitude

	-- First attempt at wedge heights via ray intersection
	local wedgeHeightA = aBaseInnerLength - aBaseOuterLength
	local wedgeHeightB = bBaseInnerLength - bBaseOuterLength

	if wedgeHeightA < 0 or wedgeHeightB < 0 then
		-- Bring A up to B rather than having them meet in the middle, will be almost
		-- the same thing because the ends are already well aligned.
		local basisSizeOnAxisA = (aBasis.Size:Dot(axis) * 0.5)
		local basisSizeOnAxisB = (bBasis.Size:Dot(axis) * 0.5)
		local pointOnBasisA = aBasis.CFrame.Position + aWorldAxis * basisSizeOnAxisA
		local pointOnBasisB = bBasis.CFrame.Position - bWorldAxis * basisSizeOnAxisB
		local outerAToSelf = intersectRayPlane(alignOuterPointA, aWorldAxis, pointOnBasisA, aWorldAxis)
		local outerAToOther = intersectRayPlane(alignOuterPointA, aWorldAxis, pointOnBasisB, bWorldAxis)
		local outerAExtra = outerAToOther - outerAToSelf
		aBaseOuterLength = outerAToSelf + 0.5 * outerAExtra

		local innerAToSelf = intersectRayPlane(alignInnerPointA, aWorldAxis, pointOnBasisA, aWorldAxis)
		local innerAToOther = intersectRayPlane(alignInnerPointA, aWorldAxis, pointOnBasisB, bWorldAxis)
		local innerAExtra = innerAToOther - innerAToSelf
		aBaseInnerLength = innerAToSelf + 0.5 * innerAExtra

		local outerBToSelf = intersectRayPlane(alignOuterPointB, -bWorldAxis, pointOnBasisB, -bWorldAxis)
		local outerBToOther = intersectRayPlane(alignOuterPointB, -bWorldAxis, pointOnBasisA, aWorldAxis)
		local outerBExtra = outerBToOther - outerBToSelf
		bBaseOuterLength = outerBToSelf + 0.5 * outerBExtra

		local innerBToSelf = intersectRayPlane(alignInnerPointB, -bWorldAxis, pointOnBasisB, -bWorldAxis)
		local innerBToOther = intersectRayPlane(alignInnerPointB, -bWorldAxis, pointOnBasisA, aWorldAxis)
		local innerBExtra = innerBToOther - innerBToSelf
		bBaseInnerLength = innerBToSelf + 0.5 * innerBExtra
	end

	-- Second attempt at wedge heights via plane intersection
	wedgeHeightA = aBaseInnerLength - aBaseOuterLength
	wedgeHeightB = bBaseInnerLength - bBaseOuterLength
	if wedgeHeightA < 0 or wedgeHeightB < 0 then
		warn("Failed to compute wedge heights for resize-align using either approach")
		wedgeHeightA = math.max(0, wedgeHeightA)
		wedgeHeightB = math.max(0, wedgeHeightB)
	end

	local offsetUnsigned = offsetPerpCorrectSideA:Abs()
	local mainOffset = math.max(offsetUnsigned.X, offsetUnsigned.Y, offsetUnsigned.Z)
	local zFightAreaA = wedgeHeightA * mainOffset * 0.5
	local zFightAreaB = wedgeHeightB * mainOffset * 0.5
	local zFightArea = math.max(zFightAreaA, zFightAreaB)

	local nonWedgeFillableMesh = false
	if a:IsA("MeshPart") or a:IsA("PartOperation") then
		local cachedIsWedgeFillable = cache[cacheIndex]
		if cachedIsWedgeFillable == nil then
			cachedIsWedgeFillable = isWedgeFillable(a)
			cache[cacheIndex] = cachedIsWedgeFillable
		end
		nonWedgeFillableMesh = not cachedIsWedgeFillable
	end

	-- Always create wedge if it's a cylinder (we already checked that it's the right orientation
	-- in isCandidateForResizing)
	local enoughZFightForWedge = not directions:FuzzyEq(Vector3.zero) and zFightArea > MIN_ZFIGHT_AREA
	local isCylinder = a:IsA("Part") and a.Shape == Enum.PartType.Cylinder
	local hasGoodWedgeHeights = wedgeHeightA > 0 and wedgeHeightB > 0
	local createFill = (enoughZFightForWedge or isCylinder) and hasGoodWedgeHeights and not nonWedgeFillableMesh

	local aDeltaLength = (createFill and aBaseOuterLength or aBaseInnerLength) - aOriginalLength * 0.5
	local bDeltaLength = (createFill and bBaseOuterLength or bBaseInnerLength) - bOriginalLength * 0.5
	if isCylinder then
		aDeltaLength += wedgeHeightA * 0.5
		bDeltaLength += wedgeHeightB * 0.5
	end

	-- Remove any fill wedges that were making this side of the model whole
	-- before from a previous redupe operation. This will happen if you redupe
	-- in that direction and then delete the result but that leaves behind an
	-- unpaired resizealigned edge with wedges.
	local checkForWedgeToRemoveLocationA = a.Position + aWorldAxis * aOriginalLength * 0.5
	local checkForWedgeToRemoveLocationB = b.Position - bWorldAxis * bOriginalLength * 0.5
	maybeRemoveWedgeAtLocation(checkForWedgeToRemoveLocationA, a.Name .. FILL_NAME_SUFFIX)
	maybeRemoveWedgeAtLocation(checkForWedgeToRemoveLocationB, b.Name .. FILL_NAME_SUFFIX)

	if createFill then
		if isCylinder then
			-- For cylinders fill intersection with one ball
			local ball = makeBall(a)
			ball.Name ..= FILL_NAME_SUFFIX
			ball.CFrame = CFrame.fromMatrix(
				a.Position + aWorldAxis * (aBaseOuterLength + wedgeHeightA * 0.5),
				closestUnitVector(a.CFrame, -offsetPerpCorrectSideA):Cross(aWorldAxis),
				aWorldAxis
			) + aWorldVisualOffset
			ball.Size = Vector3.one * smallestNonZeroComponent(sizingPerpToAxis * aSize)
			ball:AddTag(FILL_TAG)
			ball.Parent = a.Parent
		else
			-- For boxes fill intersection with two wedges
			local desiredZVectorForA = a.CFrame:VectorToWorldSpace(-offsetPerpCorrectSideA)
			local wedgeA = makeWedge(a)
			wedgeA.Name ..= FILL_NAME_SUFFIX
			wedgeA.CFrame = CFrame.fromMatrix(
				a.Position + aWorldAxis * (aBaseOuterLength + wedgeHeightA * 0.5),
				closestUnitVector(a.CFrame, desiredZVectorForA):Cross(aWorldAxis),
				aWorldAxis
			) + aWorldVisualOffset
			local aPerSizeInBasis = aBasis.CFrame:VectorToObjectSpace(a.CFrame:VectorToWorldSpace(sizingPerpToAxis * aSize))
			local aSizeInBasis = axis * wedgeHeightA + aPerSizeInBasis
			wedgeA.Size = wedgeA.CFrame:VectorToObjectSpace(aBasis.CFrame:VectorToWorldSpace(aSizeInBasis)):Abs()
			wedgeA:AddTag(FILL_TAG)
			wedgeA.Parent = a.Parent
			if resultList then
				table.insert(resultList, wedgeA)
			end

			local desiredZVectorForB = b.CFrame:VectorToWorldSpace(-offsetPerpCorrectSideB)
			local wedgeB = makeWedge(b)
			wedgeB.Name ..= FILL_NAME_SUFFIX
			wedgeB.CFrame = CFrame.fromMatrix(
				b.Position - bWorldAxis * (bBaseOuterLength + wedgeHeightB * 0.5),
				-closestUnitVector(b.CFrame, desiredZVectorForB):Cross(bWorldAxis),
				-bWorldAxis
			) + bWorldVisualOffset
			local bPerSizeInBasis = bBasis.CFrame:VectorToObjectSpace(b.CFrame:VectorToWorldSpace(sizingPerpToAxis * bSize))
			local bSizeInBasis = axis * wedgeHeightB + bPerSizeInBasis
			wedgeB.Size = wedgeB.CFrame:VectorToObjectSpace(bBasis.CFrame:VectorToWorldSpace(bSizeInBasis)):Abs()
			wedgeB:AddTag(FILL_TAG)
			wedgeB.Parent = b.Parent
			if resultList then
				table.insert(resultList, wedgeB)
			end
		end
	end

	local aNewSize = a.Size + (sizingAxis * aDeltaLength) / aSizeScale
	if aNewSize:Dot(sizingAxis) <= 0.001 then
		a.Parent = nil
	else
		a.Size = aNewSize
		a.CFrame += aWorldAxis * aDeltaLength * 0.5
		a:AddTag(RESIZE_TAG)
	end

	local bNewSize = b.Size + (sizingAxis * bDeltaLength) / bSizeScale
	if bNewSize:Dot(sizingAxis) <= 0.001 then
		b.Parent = nil
	else
		b.Size = bNewSize
		b.CFrame -= bWorldAxis * bDeltaLength * 0.5
		b:AddTag(RESIZE_TAG)
	end
end

local function filterChildList(children: {Instance}): {Instance}
	local filteredList = {}
	for _, ch in children do
		if not ch.Archivable then
			continue
		end
		if ch:HasTag(FILL_TAG) then
			continue
		end
		table.insert(filteredList, ch)
	end
	return filteredList
end

local function resizeAlignPairsRecursive(a: {Instance}, b: {Instance}, aBasis: ResizeAlignInfo, bBasis: ResizeAlignInfo, axis: Vector3, cache: ResizeAlignPairsCache, cacheIndex: number, resultList: {Instance}?): number
	assert(#a == #b, "Mismatched number of instances to resize-align recursive")
	for i, itemA in a do
		local itemB = b[i]
		if itemA.ClassName ~= itemB.ClassName then
			warn("Mismatched instance types in resize-align:", itemA.ClassName, itemB.ClassName)
			continue
		end
		if itemA.Name ~= itemB.Name then
			warn("Mismatched instance names in resize-align:", itemA.Name, itemB.Name)
			continue
		end
		if itemA:IsA("BasePart") and itemB:IsA("BasePart") then
			resizeAlignPair(itemA, itemB, aBasis, bBasis, axis, cache, cacheIndex, resultList)
			cacheIndex += 1
		else
			local childListA = filterChildList(itemA:GetChildren())
			local childListB = filterChildList(itemB:GetChildren())
			cacheIndex = resizeAlignPairsRecursive(childListA, childListB, aBasis, bBasis, axis, cache, cacheIndex, nil)
		end
	end
	return cacheIndex
end

local function resizeAlignPairs(a: {Instance}, b: {Instance}, aBasis: ResizeAlignInfo, bBasis: ResizeAlignInfo, axis: Vector3, cache: ResizeAlignPairsCache): {{Instance}}
	assert(#a == #b, "Mismatched number of instances to resize-align")
	local allResults = {}
	for i, item in a do
		local resultsForItem = {}
		resizeAlignPairsRecursive({a[i]}, {b[i]}, aBasis, bBasis, axis, cache, 1, resultsForItem)
		allResults[i] = resultsForItem
	end
	return allResults
end

return resizeAlignPairs