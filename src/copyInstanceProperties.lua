
local ReflectionService = game:GetService("ReflectionService")

local PROPERTIES_TO_COPY = {} :: {[string]: {string}?}

type GetPropertiesParams = {
	Security: SecurityCapabilities?,
	ExcludeInherited: boolean?,
	ExcludeDisplay: boolean?,
}

type ReflectedProperty = {
	Name: string,
	Serialized: boolean,
	Type: any,
	ContentType: Enum.AssetType?,
	Display: {
		Category: string,
		DeprecationMessage: string?,
		LayoutOrder: number,
	}?,
	Permits: {
		Read: SecurityCapabilities?,
		ReadParallel: SecurityCapabilities?,
		Write: SecurityCapabilities?,
		WriteParallel: SecurityCapabilities?,
	},
}

type ReflectedClass = {
	Name: string,
	Superclass: string?,
	Subclasses: {string},
	Display: {
		Category: string,
		DeprecationMessage: string?,

	}?,
	Permits: {
		GetService: SecurityCapabilities?,
		New: SecurityCapabilities?,
	}
}

local function getPropertiesToCopy(className: string): {string}
	local toCopy = PROPERTIES_TO_COPY[className]
	if toCopy then
		return toCopy
	else
		local propertyTable = {}
		for _, prop in ReflectionService:GetPropertiesOfClass(className) :: {ReflectedProperty} do
			if prop.Permits.Write and prop.Permits.Read then
				local name = prop.Name
				if name ~= "Parent" then
					table.insert(propertyTable, name)
				end
			end
		end
		PROPERTIES_TO_COPY[className] = propertyTable
		return propertyTable
	end
end

type BaseEntry = {
	Base: BaseEntry?,
	Name: string,
	Depth: number,
}

local BASE_ENTRY_CACHE = {} :: {[string]: BaseEntry}

local function getBaseEntry(className: string)
	local entry = BASE_ENTRY_CACHE[className]
	if entry then
		return entry
	elseif className == "Instance" then
		local newEntry = {
			Base = nil,
			Name = "Instance",
			Depth = 0,
		}
		BASE_ENTRY_CACHE[className] = newEntry
		return newEntry
	else
		local info = ReflectionService:GetClass(className) :: ReflectedClass
		local superclassInfo = getBaseEntry(info.Superclass)
		local newEntry = {
			Base = superclassInfo,
			Name = className,
			Depth = superclassInfo.Depth + 1,
		}
		BASE_ENTRY_CACHE[className] = newEntry
		return newEntry
	end
end

local function findSharedBaseClass(classA: string, classB: string): string
	if classA == classB then
		return classA
	end
	local deepEntry = getBaseEntry(classA)
	local shallowEntry = getBaseEntry(classB)
	if deepEntry.Depth < shallowEntry.Depth then
		deepEntry, shallowEntry = shallowEntry, deepEntry
	end
	while deepEntry.Depth > shallowEntry.Depth do
		deepEntry = deepEntry.Base
	end
	while deepEntry ~= shallowEntry do
		deepEntry = deepEntry.Base
		shallowEntry = shallowEntry.Base
	end
	return deepEntry.Name
end

local function copyInstanceProperties(source: Instance, destination: Instance)
	for _, propName in getPropertiesToCopy(findSharedBaseClass(source.ClassName, destination.ClassName)) do
		destination[propName] = source[propName]
	end
end

return copyInstanceProperties