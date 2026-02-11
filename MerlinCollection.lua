local Merlin = require("Merlin")

---@class MerlinCollection : Merlin
local MerlinCollection = Merlin:derive("Collection")

local config = {
    storage = "__merlinCollection"
}

local table = table
local _insert = table.insert
local function _matches(item, key, operatorFunc, value)
    local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]
    local success, result = pcall(operatorFunc, itemValue, value)
    return success and result
end

-- Query Operators
local OPERATORS = {
    ["="]   = function(a, b) return a == b end,
    ["=="]  = function(a, b) return a == b end,
    ["!="]  = function(a, b) return a ~= b end,
    ["<>"]  = function(a, b) return a ~= b end,
    [">"]   = function(a, b) return a > b end,
    ["<"]   = function(a, b) return a < b end,
    [">="]  = function(a, b) return a >= b end,
    ["<="]  = function(a, b) return a <= b end,
    -- This might be fun..
    ["like"] = function(a, b) return tostring(a):find(tostring(b), 1, true) ~= nil end
}

---comment 
---@param items any
---@return MerlinCollection|Merlin|table
function MerlinCollection:new(items)
    local collection = Merlin.new(self)

    collection:set(config.storage, items or {})
    return collection
end

function MerlinCollection:all() return self:get(config.storage, {}) end

function MerlinCollection:cast(className)
    local Class = Merlin._Registry[className]
    if not Class then return self end

    return self:map(function (item)
        if type(item) == "table" and item._isMerlin then return item end
        return Class:new(item)
    end)
end

function MerlinCollection:count() return #self:all() end

function MerlinCollection:destroy(recursive)
    local items = self:all()
    if not items then return nil end

    if recursive then
        for i = 1, #items do
            local item = items[i]
            if type(item) == "table" and item.destroy then item:destroy() end
        end
    end

    self:set(config.storage, nil)

    return Merlin.destroy(self)
end

function MerlinCollection:each(callback)
    local items = self:get(config.storage, {})

    for i = 1, #items do
        if callback(items[i], i) == false then break end
    end

    return self
end

---comment
---@param callback function
---@return MerlinCollection
function MerlinCollection:filter(callback)
    -- local collection = self._Class:new
    local items = self:get(config.storage, {})
    local filtered = {}

    for i = 1, #items do
        if callback(items[i], i) then _insert(filtered, items[i]) end
    end

    return self._Class:new(filtered)
end

function MerlinCollection:first()
    local items = self:all()
    return items[1]
end

function MerlinCollection:firstWhere(key, operatorOrValue, value)
    if value == nil then
        value = operatorOrValue
        operatorOrValue = "="
    end

    local operatorFunc = OPERATORS[operatorOrValue]
    ---@TODO another place we need to log
    if not operatorFunc then return nil end

    local items = self:all()
    for i = 1, #items do
        local item = items[i]
        -- local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]
        -- local success, result = pcall(operatorFunc, itemValue, value)
        -- return success and result
        return _matches(item, key, operatorFunc, value)
        -- local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]
        -- local success, result = pcall(operatorFunc, itemValue, value)
        -- if success and result then
        --     return item
        -- end
    end

    return nil
end

function MerlinCollection:groupBy(key)
    local items = self:all()
    local groups = {}

    for i = 1, #items do
        local item = items[i]
        
        -- Try instance get, then check the class for metadata like _Type
        local groupKey = (type(item) == "table" and item.get) and item:get(key) or item[key]
        
        -- Fallback for Class-level metadata (like _Type or _Name)
        if groupKey == nil and type(item) == "table" then
            local class = rawget(item, "_Class")
            groupKey = class and rawget(class, key)
        end

        groupKey = tostring(groupKey or "Unknown")

        if not groups[groupKey] then groups[groupKey] = {} end
        _insert(groups[groupKey], item)
    end

    for gKey, gItems in pairs(groups) do
        groups[gKey] = self._Class:new(gItems)
    end

    return self._Class:new(groups)
end

function MerlinCollection:isEmpty() return #self:all() == 0 end

function MerlinCollection:isNotEmpty() return not self:isEmpty() end

function MerlinCollection:last()
    local items = self:all()
    return items[#items]
end

function MerlinCollection:lastWhere(key, operatorOrValue, value)
    if value == nil then
        value = operatorOrValue
        operatorOrValue = "="
    end

    local operatorFunc = OPERATORS[operatorOrValue]
    ---@TODO log an error here
    if not operatorFunc then return nil end

    local items = self:all()
    -- Iterate backwards
    for i = #items, 1, -1 do
        local item = items[i]

        -- local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]
        -- local success, result = pcall(operatorFunc, itemValue, value)
        -- return success and result
        return _matches(item, key, operatorFunc, value)
        -- local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]
        -- local success, result = pcall(operatorFunc, itemValue, value)
        -- if success and result then
        --     return item
        -- end
    end

    return nil
end

function MerlinCollection:map(callback)
    if type(callback) ~= "function" then return self end

    local items = self:all()
    local mapped = {}

    for i = 1, #items do
        mapped[i] = callback(items[i], i)
    end

    return self._Class:new(mapped)
end

function MerlinCollection:pipe(callback)
    if type(callback) == "function" then return callback(self) end

    return self
end

function MerlinCollection:pluck(key)
    return self:map(function(item)
        return (type(item) == "table" and item.get) and item:get(key) or item[key]
    end)
end

function MerlinCollection:select(...)
    local keys = {...}
    return self:map(function(item)
        local newItem = {}
        for _, key in ipairs(keys) do
            newItem[key] = (item.get and item:get(key)) or item[key]
        end

        return newItem
    end)
end

function MerlinCollection:sortBy(key, descending)
    local items = self:all()
    local sorted = {}

    for i = 1, #items do sorted[i] = items[i] end

    table.sort(sorted, function(a, b)
        local valA = (type(a) == "table" and a.get) and a:get(key) or a[key]
        local valB = (type(b) == "table" and b.get) and b:get(key) or b[key]

        if valA == nil then return false end
        if valB == nil then return true end

        if descending then return valA > valB end
        return valA < valB
    end)

    return self._Class:new(sorted)
end

function MerlinCollection:sortByDescending(key) return self:sortBy(key, true) end

function MerlinCollection:tap(callback)
    if type(callback) == "function" then
        callback(self)
        return self
    end

    return self
end

function MerlinCollection:toArray() return self:all() end

function MerlinCollection:unless(condition, callback)
    if type(callback) == "function" then return self:when(not condition, callback) end

    return self
end

function MerlinCollection:when(condition, callback)
    if condition and type(callback) == "function" then return callback(self) or self end
    return self
end

--- @param key string
--- @operatorOrValue any
--- @value any|nil
--- @return MerlinCollection
function MerlinCollection:where(key, operatorOrValue, value)
    if value == nil then
        value = operatorOrValue
        operatorOrValue = "="
    end

    local operatorFunc = OPERATORS[operatorOrValue]
    if not operatorFunc then
        ---@TODO We need access to Merlins log function - log some stuff about invalid operator
        return self
    end

    return self:filter(function(item)
        return _matches(item, key, operatorFunc, value)
        -- local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]
        -- local success, result = pcall(operatorFunc, itemValue, value)
        -- return success and result
    end)
end

function MerlinCollection:whereIn(key, values)
    local lookup = {}

    for _, value in ipairs(values) do lookup[value] = true end

    return self:filter(function(item)
        local itemValue = (type(item)  == "table" and item.get) and item:get(key)
        return lookup[itemValue] ~= nil
    end)
end

return MerlinCollection