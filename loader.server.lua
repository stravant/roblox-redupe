local DEVELOPMENT = false

-- When not in development, just directly run the plugin
if not DEVELOPMENT then
	require(script.Parent.Src.main)(plugin)
	return
end

-- Otherwise, mock the plugin to allow reloading...

local CoreGui = game:GetService("CoreGui")

local Signal = require(script.Parent.Packages.Signal)

local function getHolder(str): ObjectValue
	local ident = "Holder" .. str
	local holder = CoreGui:FindFirstChild(ident)
	if not holder then
		holder = Instance.new("ObjectValue")
		holder.Name = ident
		holder.Parent = CoreGui
	end
	return holder
end

local function getToolbar(name: string): PluginToolbar
	local toolbarHolder = getHolder(name)
	if not toolbarHolder.Value then
		toolbarHolder.Value = plugin:CreateToolbar(name)
	end
	return toolbarHolder.Value
end

local function makeMockToolbar(toolbarName)
	local mockToolbar = setmetatable({
		_instance = getToolbar(toolbarName),
		CreateButton = function(self, id, tooltip, icon, text)
			local buttonHolder = getHolder(toolbarName .. id)
			if not buttonHolder.Value then
				local button = self._instance:CreateButton(id, tooltip, icon, text)
				buttonHolder.Value = button
			end
			return buttonHolder.Value
		end,
	}, {
		__index = function(self, key)
			return self._instance[key]
		end,
		__newindex = function(self, key, value)
			self._instance[key] = value
		end,
	})
	return mockToolbar
end

local MockPlugin = setmetatable({
	_instance = plugin,
	Unloading = Signal.new(),
	CreateToolbar = function(self, name)
		return makeMockToolbar(name)
	end,
	GetMouse = function(self)
		return plugin:GetMouse()
	end,
}, {
	__index = function(self, key)
		local value = plugin[key]
		if typeof(value) == "function" then
			return function(mockSelf, ...)
				return value(plugin, ...)
			end
		else
			return value
		end
	end,
	__newindex = function(self, key, value)
		plugin[key] = value
	end,
})

require(script.Parent.Src.main)(MockPlugin)