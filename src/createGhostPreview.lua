--!strict
--!native
local DraggerService = game:GetService("DraggerService")
local DraggerFramework = require("../Packages/DraggerFramework")
local JointMaker = (require :: any)(DraggerFramework.Utility.JointMaker)

export type GhostPreview = {
	hide: () -> (),
	create: (isPreview: boolean, scaleMode: string, positionOffset: CFrame, sizeOffset: Vector3, extrudeAxis: Vector3) -> { Instance },
	trim: () -> (),
}

type OriginalSizeInfo = {
	Size: Vector3,
	CFrame: CFrame,
	OriginalMeshScale: Vector3?,
	DataModelMesh: DataModelMesh?,
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

-- Returns the amount of size on the axis of interest in basis, and the "rest" of the size
local function sizeToWorldSpace(basis: CFrame, axisOfInterest: Vector3, size: Vector3): (number, Vector3)
	-- Take the amount of size on the axis, and leave the rest in rest
	local xFactor = math.abs(basis.XVector:Dot(axisOfInterest))
	local sizeOnX = xFactor * size.X
	local sizeOffX = (1 - xFactor) * size.X

	local yFactor = math.abs(basis.YVector:Dot(axisOfInterest))
	local sizeOnY = yFactor * size.Y
	local sizeOffY = (1 - yFactor) * size.Y

	local zFactor = math.abs(basis.ZVector:Dot(axisOfInterest))
	local sizeOnZ = zFactor * size.Z
	local sizeOffZ = (1 - zFactor) * size.Z

	local onAxis = sizeOnX + sizeOnY + sizeOnZ
	local rest = Vector3.new(sizeOffX, sizeOffY, sizeOffZ)
	return onAxis, rest
end

local function sizeToObjectSpace(basis: CFrame, axisOfInterest: Vector3, size: Vector3, sizeOnAxis: number): Vector3
	local xFactor = math.abs(basis.XVector:Dot(axisOfInterest)) * size.X
	local yFactor = math.abs(basis.YVector:Dot(axisOfInterest)) * size.Y
	local zFactor = math.abs(basis.ZVector:Dot(axisOfInterest)) * size.Z

	local totalFactor = xFactor + yFactor + zFactor
	if totalFactor == 0 then
		return Vector3.zero
	end
	local xPortion = xFactor / totalFactor
	local yPortion = yFactor / totalFactor
	local zPortion = zFactor / totalFactor

	return Vector3.new(xPortion, yPortion, zPortion) * sizeOnAxis
end

local function getOriginalInfo(part: BasePart, original: OriginalSizeMap): OriginalSizeInfo
	local originalInfo = original[part]
	if not originalInfo then
		local mesh = part:FindFirstChildWhichIsA("DataModelMesh")
		local newInfo = table.freeze({
			Size = part.Size,
			CFrame = part.CFrame,
			DataModelMesh = mesh,
			OriginalMeshScale = if mesh then mesh.Scale else nil,
		})
		original[part] = newInfo
		originalInfo = newInfo
	end
	return originalInfo
end

local function resetToOriginalInfo(part: BasePart, original: OriginalSizeMap)
	local originalInfo = original[part]
	if originalInfo then
		part.Size = originalInfo.Size
		part.CFrame = originalInfo.CFrame
		part.LocalTransparencyModifier = 0
		if originalInfo.DataModelMesh and originalInfo.OriginalMeshScale then
			originalInfo.DataModelMesh.Scale = originalInfo.OriginalMeshScale
		end
	end
end

local EXACTLY_CENTERED_DISAMBIGUATION = 0.01
local function extrudePart(part: BasePart, originalInfo: OriginalSizeInfo, extrudeAxis: Vector3, extrudeAmount: number, isPreview: boolean): (CFrame, Vector3)
	-- Since the model is at origin, the raw part CFrame is already in local space
	local localCFrame = originalInfo.CFrame
	local localSize, restOfSize = sizeToWorldSpace(originalInfo.CFrame, extrudeAxis, originalInfo.Size)

	local positionOnAxis = localCFrame.Position:Dot(extrudeAxis)
	local halfSize = 0.5 * localSize
	local a = positionOnAxis + halfSize + EXACTLY_CENTERED_DISAMBIGUATION
	local b = positionOnAxis - halfSize + EXACTLY_CENTERED_DISAMBIGUATION
	if a * b < 0 then
		-- Spans zero, extrude
		local newSizeOnAxis = localSize + extrudeAmount
		if newSizeOnAxis > 0 then
			local newSize = sizeToObjectSpace(originalInfo.CFrame, extrudeAxis, originalInfo.Size, newSizeOnAxis) + restOfSize
			if originalInfo.DataModelMesh and originalInfo.OriginalMeshScale then
				originalInfo.DataModelMesh.Scale = (newSize / originalInfo.Size) * originalInfo.OriginalMeshScale
			end
			-- Make sure it's shown if it was hidden previously
			part.LocalTransparencyModifier = 0
			return originalInfo.CFrame, newSize
		else
			-- Collasped to zero, hide or remove it
			if isPreview then
				part.LocalTransparencyModifier = 1
			else
				part.Parent = nil
			end
			return originalInfo.CFrame, originalInfo.Size
		end
	else
		local sign = math.sign(localCFrame.Position:Dot(extrudeAxis))
		local motion = extrudeAxis * extrudeAmount * 0.5 * sign
		local newCFrame = localCFrame + motion
		part.LocalTransparencyModifier = 0
		return newCFrame, originalInfo.Size
	end
end

function resizeWithWorldScale(basis: CFrame, size: Vector3, worldScale: Vector3): Vector3
	local xDir = basis.XVector:Abs()
	local yDir = basis.YVector:Abs()
	local zDir = basis.ZVector:Abs()
	return size * Vector3.new(
		(xDir * worldScale).Magnitude,
		(yDir * worldScale).Magnitude,
		(zDir * worldScale).Magnitude
	)
end

local function resizeModelViaExtrude(model: Model, scaleFactor: Vector3, sizeDelta: Vector3, original: OriginalSizeMap, isPreview: boolean)
	-- Special case for returning the model to how it was if there's no size delta, because
	-- we don't have an axis to extrude on in that case.
	if sizeDelta:FuzzyEq(Vector3.zero) then
		for _, part in (model:QueryDescendants("BasePart") :: any) :: {BasePart} do
			resetToOriginalInfo(part, original)
		end
	else
		-- Extrude on the axis with the largest delta
		local extrudeAxis = largestAxis(sizeDelta)
		local otherAxis = Vector3.one - extrudeAxis
		local scaleForOtherAxis = otherAxis * scaleFactor + extrudeAxis
		local extrudeAmount = sizeDelta:Dot(extrudeAxis)

		for _, part in (model:QueryDescendants("BasePart") :: any) :: {BasePart} do
			-- Info to scale from
			local originalInfo = getOriginalInfo(part, original)

			-- Extrude on extrude axis
			local cframe, size = extrudePart(part, originalInfo, extrudeAxis, extrudeAmount, isPreview)
			
			-- Stretch on other axis
			size = resizeWithWorldScale(cframe, size, scaleForOtherAxis)
			local position = cframe.Position
			cframe = cframe.Rotation + position * scaleForOtherAxis

			-- Apply
			part.Size = size
			part.CFrame = cframe
		end
	end
end

local function resizeModelViaStretch(model: Model, scaleFactor: Vector3, original: OriginalSizeMap, isPreview: boolean)
	-- Special case for returning the model to how it was if there's no size delta, because
	-- we don't have an axis to extrude on in that case.
	if scaleFactor:FuzzyEq(Vector3.one) then
		for _, part in (model:QueryDescendants("BasePart") :: any) :: {BasePart} do
			resetToOriginalInfo(part, original)
		end
	else
		for _, part in (model:QueryDescendants("BasePart") :: any) :: {BasePart} do
			-- Info to scale from
			local originalInfo = getOriginalInfo(part, original)

			-- Since the model is at origin, the raw part CFrame is already in local space
			local localCFrame = originalInfo.CFrame
			local localSize = originalInfo.Size
			local newSize = resizeWithWorldScale(originalInfo.CFrame, localSize, scaleFactor)
			part.Size = newSize
			part.CFrame = localCFrame.Rotation + localCFrame.Position * scaleFactor
			if originalInfo.DataModelMesh and originalInfo.OriginalMeshScale then
				originalInfo.DataModelMesh.Scale = (newSize / originalInfo.Size) * originalInfo.OriginalMeshScale
			end
			-- Make sure it's shown if it was hidden previously (can't happen in this branch
			-- but can happen if we switched from extrude to stretch)
			part.LocalTransparencyModifier = 0
		end
	end
end

-- Return the most powerful scaling (up or down) being applied on an axis
local function largestScale(scaleFactor: Vector3): number
	local maxScale = math.max(scaleFactor.X, scaleFactor.Y, scaleFactor.Z)
	local minScale = math.min(scaleFactor.X, scaleFactor.Y, scaleFactor.Z)
	if 1 / minScale > maxScale then
		return minScale
	else
		return maxScale
	end
end

local function resizeModelViaScaleTo(model: Model, scaleFactor: Vector3, original: OriginalSizeMap)
	-- Restore parts before we do anything if we previously did an edit to the model
	if next(original) then
		for _, part in (model:QueryDescendants("BasePart") :: any) :: {BasePart} do
			resetToOriginalInfo(part, original)
		end
		-- Clear so we don't keep restoring unnecessarily
		table.clear(original)
	end

	model:ScaleTo(model:GetScale() * largestScale(scaleFactor))
end

local function scaleModel(model: Model, scaleMode: string, basis: CFrame, originalSize: Vector3, newSize: Vector3, original: OriginalSizeMap, isPreview: boolean)
	-- Find joints that need to be adjusted afterwards.
	local toAdjustC0C1: { [JointInstance]: CFrame } = {}
	for _, joint in (model:QueryDescendants("JointInstance") :: any) :: {JointInstance} do
		local part0 = joint.Part0
		local part1 = joint.Part1
		if part0 and part1 then
			local relativeTo = part0.CFrame:Lerp(part1.CFrame, 0.5)
			toAdjustC0C1[joint] = relativeTo:ToObjectSpace(part0.CFrame * joint.C0)
		end
	end

	local scaleFactor = newSize / originalSize
	local appliedScale
	if scaleMode == "Extrude" then
		local sizeDelta = newSize - originalSize
		resizeModelViaExtrude(model, scaleFactor, sizeDelta, original, isPreview)
		appliedScale = Vector3.one
	elseif scaleMode == "Stretch" then
		resizeModelViaStretch(model, scaleFactor, original, isPreview)
		appliedScale = scaleFactor
	elseif scaleMode == "Uniform" then
		local initialScale = model:GetScale()
		resizeModelViaScaleTo(model, scaleFactor, original)
		appliedScale = Vector3.one * (model:GetScale() / initialScale)
	else
		error(`Unknown scale mode {scaleMode}`)
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

	return appliedScale
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
						if descendant:IsA("BasePart") and descendant.Transparency < 1 then
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

	local function adjustSingleInstance(item: Instance, target: Instance, scaleMode: string, extrudeAxis: Vector3, original: OriginalSizeMap, targetCFrame: CFrame, targetSize: Vector3, isPreview: boolean): boolean
		local scale = targetSize / size
		if target:IsA("Model") then
			local itemModel = item :: Model
			local targetModel = target :: Model
			local pivotInBasis = cframe:ToObjectSpace(targetModel:GetPivot())
			itemModel:PivotTo(CFrame.identity)
			-- Note, this call only adds extra work in ScaleTo mode which will be
			-- uncommon and faster than the other modes to execute so do it for
			-- implementation simplicity. We're going to scale it again after so
			-- work could be saved here by not doing two ScaleTo calls each frame.
			itemModel:ScaleTo(targetModel:GetScale())
			local appliedScale = scaleModel(itemModel, scaleMode, cframe, size, targetSize, original, isPreview)
			itemModel:PivotTo(targetCFrame * (pivotInBasis.Rotation + pivotInBasis.Position * appliedScale))
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

	local function adjustItemRecursive(item: Instance, target: Instance, scaleMode: string, extrudeAxis: Vector3, original: OriginalSizeMap, targetCFrame: CFrame, targetSize: Vector3, isPreview: boolean)
		local didAdjust = adjustSingleInstance(item, target, scaleMode, extrudeAxis, original, targetCFrame, targetSize, isPreview)
		if not didAdjust then
			-- Recurse to children
			local itemChildren = item:GetChildren()
			local targetChildren = target:GetChildren()

			-- This invariant works because we clone the targets one additional
			-- time upfront. So every clone is a "clone of a clone" which should
			-- be idempotent in structure.
			assert(#itemChildren == #targetChildren, "Mismatched children count in ghost preview adjustment")

			for i = 1, #itemChildren do
				adjustItemRecursive(itemChildren[i], targetChildren[i], scaleMode, extrudeAxis, original, targetCFrame, targetSize, isPreview)
			end
		end
	end

	local function create(isPreview: boolean, scaleMode: string, targetCFrame: CFrame, targetSize: Vector3, extrudeAxis: Vector3): { Instance }
		local itemToSpawn = getItem(isPreview)
		for i, clonedTarget in clonedTargets do
			local item = itemToSpawn.instances[i]
			adjustItemRecursive(item, clonedTarget, scaleMode, extrudeAxis, itemToSpawn.originalSizeInfo, targetCFrame, targetSize, isPreview)
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