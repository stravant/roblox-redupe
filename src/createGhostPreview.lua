--!strict
local DraggerService = game:GetService("DraggerService")
local DraggerFramework = require("../Packages/DraggerFramework")
local JointMaker = (require :: any)(DraggerFramework.Utility.JointMaker)

export type GhostPreview = {
	hide: () -> (),
	create: (isPreview: boolean, positionOffset: CFrame, sizeOffset: Vector3, extrudeAxis: Vector3) -> { Instance },
	trim: () -> (),
}

type OriginalSizeInfo = {
	Size: Vector3,
	CFrame: CFrame,
}
type OriginalSizeMap = { [Instance]: OriginalSizeInfo }

type WithEnabled = {
	Enabled: boolean,
}

type PoolItem = {
	instances: { Instance },
	jointsToReenable: { WithEnabled },
	originalSizeInfo: OriginalSizeMap,
}

local GHOST_TRANSPARENCY = 0.5

local function cloneTargets(targets: { Instance }): { Instance }
	local clones: { Instance } = {}
	for i, target in targets do
		clones[i] = target:Clone()
	end
	return clones
end

local function largestAxis(v: Vector3): Vector3
	local abs = v:Abs()
	if abs.X >= abs.Y and abs.X >= abs.Z then
		return Vector3.xAxis
	elseif abs.Y >= abs.Z then
		return Vector3.yAxis
	else
		return Vector3.zAxis
	end
end

local function enableJointsAndJoinToWorld(item: PoolItem)
	for _, joint in item.jointsToReenable do
		joint.Enabled = true
	end

	if DraggerService.JointsEnabled then
		local parts = {}
		for _, instance in item.instances do
			for _, part in (instance:QueryDescendants("BasePart") :: any) :: {BasePart} do
				table.insert(parts, part)
			end
		end
		local jointMaker = JointMaker.new(false)
		jointMaker:pickUpParts(parts)
		local jointPairs = jointMaker:computeJointPairs()
		jointPairs:createJoints()
	end
end

-- TODO: Handle PrimaryPart
-- TODO: Fall back to scale of model with lots of MeshParts or stuff like that?
local EXACTLY_CENTERED_DISAMBIGUATION = 0.01
local function extrudeModel(model: Model, basis: CFrame, sizeDelta: Vector3, original: OriginalSizeMap)
	-- Find joints that need to be adjusted afterwards. We need to record 
	local toAdjustC0C1: { [JointInstance]: CFrame } = {}
	for _, joint in (model:QueryDescendants("JointInstance") :: any) :: {JointInstance} do
		local part0 = joint.Part0
		local part1 = joint.Part1
		if part0 and part1 then
			local relativeTo = part0.CFrame:Lerp(part1.CFrame, 0.5)
			toAdjustC0C1[joint] = relativeTo:ToObjectSpace(part0.CFrame * joint.C0)
		end
	end

	-- Special case for returning the model to how it was if there's no size delta, because
	-- we don't have an axis to extrude on in that case.
	if sizeDelta:FuzzyEq(Vector3.zero) then
		for _, part in (model:QueryDescendants("BasePart") :: any) :: {BasePart} do
			local originalInfo = original[part]
			if originalInfo then
				part.Size = originalInfo.Size
				part.CFrame = originalInfo.CFrame
			end
		end
	else
		-- Extrude on the axis with the largest delta
		local extrudeAxis = largestAxis(sizeDelta)
		local extrudeAmount = sizeDelta:Dot(extrudeAxis)

		-- We only want basis to represent a rotation since we're pivoting the model to the origin
		-- to have a stable basis for scaling.
		basis = basis.Rotation
		for _, part in (model:QueryDescendants("BasePart") :: any) :: {BasePart} do
			-- Info to scale from
			local originalInfo = original[part]
			if not originalInfo then
				originalInfo = table.freeze({
					Size = part.Size,
					CFrame = part.CFrame,
				})
				original[part] = originalInfo
			end

			local originalCFrame = originalInfo.CFrame
			local localCFrame = basis:ToObjectSpace(originalCFrame)
			local worldSize = originalInfo.CFrame:VectorToWorldSpace(originalInfo.Size)
			local localSize = basis:VectorToObjectSpace(worldSize):Abs()

			local a = (localCFrame.Position + 0.5 * localSize):Dot(extrudeAxis) + EXACTLY_CENTERED_DISAMBIGUATION
			local b = (localCFrame.Position - 0.5 * localSize):Dot(extrudeAxis) + EXACTLY_CENTERED_DISAMBIGUATION
			if a * b < 0 then
				-- Spans zero, extrude
				local newSize = localSize + extrudeAxis * extrudeAmount
				local newSizeWorld = basis:VectorToWorldSpace(newSize)
				part.Size = originalInfo.CFrame:VectorToObjectSpace(newSizeWorld):Abs()
			else
				-- TODO: Tiebreaker zero
				local sign = math.sign(localCFrame.Position:Dot(extrudeAxis))
				local motion = extrudeAxis * extrudeAmount * 0.5 * sign
				part.CFrame = basis * (localCFrame + motion)
			end
		end
	end

	-- Adjust joints with a C0/C1
	for joint, localCenter in toAdjustC0C1 do
		local part0 = joint.Part0
		local part1 = joint.Part1
		if part0 and part1 then
			local relativeTo = part0.CFrame:Lerp(part1.CFrame, 0.5)
			local worldCenter = relativeTo * localCenter
			joint.C0 = (part0.CFrame:Inverse() * worldCenter):Orthonormalize()
			joint.C1 = (part1.CFrame:Inverse() * worldCenter):Orthonormalize()
		end
	end
end

local function disableJoints(hierarchy: Instance, jointsToReenable: { WithEnabled })
	for _, joint in (hierarchy:QueryDescendants("JointInstance") :: any) :: {JointInstance} do
		if joint.Enabled then
			joint.Enabled = false
			table.insert(jointsToReenable, (joint :: any) :: WithEnabled)
		end
		if joint.Part0 and not joint.Part0:IsDescendantOf(hierarchy) then
			joint:Destroy()
		end
		if joint.Part1 and not joint.Part1:IsDescendantOf(hierarchy) then
			joint:Destroy()
		end
	end
	for _, weldConstraint in (hierarchy:QueryDescendants("WeldConstraint") :: any) :: {WeldConstraint} do
		if weldConstraint.Enabled then
			weldConstraint.Enabled = false
			table.insert(jointsToReenable, (weldConstraint :: any) :: WithEnabled)
		end
		if weldConstraint.Part0 and not weldConstraint.Part0:IsDescendantOf(hierarchy) then
			weldConstraint:Destroy()
		end
		if weldConstraint.Part1 and not weldConstraint.Part1:IsDescendantOf(hierarchy) then
			weldConstraint:Destroy()
		end
	end
end

local function createGhostPreview(targets: { Instance }, cframe: CFrame, size: Vector3): GhostPreview
	local pool: { PoolItem } = {}
	local placed: { PoolItem } = {}
	local toTrim: number? = nil

	-- Clone the targets to get a known structure that will match
	-- during subsequent clones. (The first clone may lose some
	-- things like Archivable = false Instances)
	local clonedTargets = cloneTargets(targets)

	local function getItem(isPreview: boolean): PoolItem
		if isPreview and #pool > 0 then
			local existingItem = table.remove(pool)
			assert(existingItem, "Pool was not empty")
			-- Not cloned targets here because we want the
			-- original parent to parent to.
			for i, target in targets do
				existingItem.instances[i].Parent = target.Parent
			end
			return existingItem
		end

		local newItem = {
			instances = {},
			jointsToReenable = {},
			originalSizeInfo = {},
		}
		for i, clonedTarget in clonedTargets do
			local copy = clonedTarget:Clone()
			if isPreview then
				copy.Archivable = false
				if copy:IsA("Model") or copy:IsA("Folder") then
					for _, descendant in copy:GetDescendants() do
						if descendant:IsA("BasePart") then
							descendant.Transparency = GHOST_TRANSPARENCY
						end
					end
				elseif copy:IsA("BasePart") then
					copy.Transparency = GHOST_TRANSPARENCY
				else
					warn(`Unsupported target type {copy.ClassName} for ghost preview`)
				end
			end
			disableJoints(copy, newItem.jointsToReenable)
			copy.Parent = targets[i].Parent
			newItem.instances[i] = copy
		end
		return newItem
	end

	-- Deparent the unused item in the pool
	local function trim()
		if toTrim then
			for i = toTrim, #pool do
				local item = pool[i]
				for _, instance in item.instances do
					instance.Parent = nil
				end
			end
			toTrim = nil
		end
	end

	local function hide()
		trim()
		toTrim = #pool + 1
		for _, item in placed do
			table.insert(pool, item)
		end
		table.clear(placed)
	end

	local function adjustSingleInstance(item: Instance, target: Instance, extrudeAxis: Vector3, original: OriginalSizeMap, targetCFrame: CFrame, targetSize: Vector3): boolean
		local scale = targetSize / size
		if target:IsA("Model") then
			local itemModel = item :: Model
			local targetModel = target :: Model
			local pivotInBasis = cframe:ToObjectSpace(targetModel:GetPivot())
			local scalePivotInBasis = pivotInBasis.Rotation + pivotInBasis.Position
			itemModel:PivotTo(pivotInBasis)
			extrudeModel(itemModel, cframe, (targetSize - size), original)
			itemModel:PivotTo(targetCFrame * scalePivotInBasis)
			return true
		elseif target:IsA("BasePart") then
			local itemPart = item :: BasePart
			local targetPart = target :: BasePart
			local offsetFromBase = cframe:ToObjectSpace(targetPart:GetPivot())
			itemPart:PivotTo(targetCFrame * offsetFromBase)
			itemPart.Size = scale * targetPart.Size
			return true
		else
			return false
		end
	end

	local function adjustItemRecursive(item: Instance, target: Instance, extrudeAxis: Vector3, original: OriginalSizeMap, targetCFrame: CFrame, targetSize: Vector3)
		local didAdjust = adjustSingleInstance(item, target, extrudeAxis, original, targetCFrame, targetSize)
		if not didAdjust then
			-- Recurse to children
			local itemChildren = item:GetChildren()
			local targetChildren = target:GetChildren()

			-- This invariant works because we clone the targets one additional
			-- time upfront. So every clone is a "clone of a clone" which should
			-- be idempotent in structure.
			assert(#itemChildren == #targetChildren, "Mismatched children count in ghost preview adjustment")

			for i = 1, #itemChildren do
				adjustItemRecursive(itemChildren[i], targetChildren[i], extrudeAxis, original, targetCFrame, targetSize)
			end
		end
	end

	local function create(isPreview: boolean, targetCFrame: CFrame, targetSize: Vector3, extrudeAxis: Vector3): { Instance }
		local itemToSpawn = getItem(isPreview)
		for i, clonedTarget in clonedTargets do
			local item = itemToSpawn.instances[i]
			adjustItemRecursive(item, clonedTarget, extrudeAxis, itemToSpawn.originalSizeInfo, targetCFrame, targetSize)
		end
		-- Non-preview is permanent, don't need them in the placed list
		if isPreview then
			table.insert(placed, itemToSpawn)
		else
			enableJointsAndJoinToWorld(itemToSpawn)
		end
		return itemToSpawn.instances
	end

	return {
		hide = hide,
		create = create,
		trim = trim,
	}
end

return createGhostPreview