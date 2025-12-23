--!strict

export type GhostPreview = {
	hide: () -> (),
	create: (isPreview: boolean, positionOffset: Vector3, sizeOffset: Vector3) -> { Instance },
	trim: () -> (),
}

type PoolItem = {
	instances: { Instance },
}

local GHOST_TRANSPARENCY = 0.3

local function cloneTargets(targets: { Instance }): { Instance }
	local clones: { Instance } = {}
	for i, target in targets do
		clones[i] = target:Clone()
	end
	return clones
end

local function createGhostPreview(targets: { Instance }, cframe: CFrame, offset: Vector3, size: Vector3): GhostPreview
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
			-- Not cloned targets here because we want the
			-- original parent to parent to.
			for i, target in targets do
				existingItem.instances[i].Parent = target.Parent
			end
			return existingItem
		end

		local newItem = {
			instances = {},
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

	local function getScale(baseSize: Vector3, finalSize: Vector3): number
		return math.max(finalSize.X / baseSize.X, finalSize.Y / baseSize.Y, finalSize.Z / baseSize.Z)
	end

	local function adjustSingleInstance(item: Instance, target: Instance, scale: number, targetCFrame: CFrame, targetSize: Vector3): boolean
		if target:IsA("Model") then
			local itemModel = item :: Model
			local targetModel = target :: Model
			local extraOffsetFromSize = (targetSize - size) / 2
			local offsetFromBase = cframe:ToObjectSpace(targetModel:GetPivot()) * CFrame.new(-extraOffsetFromSize)
			local scaledOffsetFromBase = offsetFromBase.Rotation + offsetFromBase.Position
			itemModel:PivotTo(targetCFrame * scaledOffsetFromBase)
			itemModel:ScaleTo(target:GetScale() * scale)
			return true
		elseif target:IsA("BasePart") then
			local scale = targetSize / size
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

	local function adjustItemRecursive(item: Instance, target: Instance, scale: number, targetCFrame: CFrame, targetSize: Vector3)
		local didAdjust = adjustSingleInstance(item, target, scale, targetCFrame, targetSize)
		if not didAdjust then
			-- Recurse to children
			local itemChildren = item:GetChildren()
			local targetChildren = target:GetChildren()

			-- This invariant works because we clone the targets one additional
			-- time upfront. So every clone is a "clone of a clone" which should
			-- be idempotent in structure.
			assert(#itemChildren == #targetChildren, "Mismatched children count in ghost preview adjustment")
	
			for i = 1, #itemChildren do
				adjustItemRecursive(itemChildren[i], targetChildren[i], scale, targetCFrame, targetSize)
			end
		end
	end

	local function create(isPreview: boolean, targetCFrame: CFrame, targetSize: Vector3): { Instance }
		local scale = getScale(size, targetSize)
		local itemToSpawn = getItem(isPreview)
		for i, target in targets do
			local item = itemToSpawn.instances[i]
			adjustItemRecursive(item, target, scale, targetCFrame, targetSize)
		end
		-- Non-preview is permanent, don't need them in the placed list
		if isPreview then
			table.insert(placed, itemToSpawn)
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