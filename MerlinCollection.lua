local Merlin = require("Merlin")

---@class MerlinCollection : Merlin
local MerlinCollection = Merlin:derive("Collection")

local config = {
    storage = "__merlinCollection"
}

local table = table
local _insert = table.insert

---comment
---@param items any
---@return MerlinCollection|Merlin|table
function MerlinCollection:new(items)
    local collection = Merlin.new(self)

    collection:set(config.storage, items or {})

    return collection
end

function MerlinCollection:all() return self:get(config.storage, {}) end

function MerlinCollection:count() return #self:all() end

function MerlinCollection:destroy(recursive)
    local items = self:all()
    if not items then return nil end

    if recursive then
        for i = 1, #items do
            local item = items[i]
            if type(item) == "table" and item.destroy then
                item:destroy()
            end
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
---@return MerlinCollection|Merlin|table
function MerlinCollection:filter(callback)
    -- local collection = self._Class:new
    local items = self:get(config.storage, {})
    local filtered = {}

    for i = 1, #items do
        if callback(items[i], i) then _insert(filtered, items[i]) end
    end

    -- Return a new collection
    return self._Class:new(filtered)
end

function MerlinCollection:first()
    local items = self:all()
    return items[1]
end

function MerlinCollection:firstWhere(key, value)
    local items = self:get(config.storage, {})

    for i = 1, #items do
        local item = items[i]
        local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]

        if itemValue == value then
            return item
        end
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

function MerlinCollection:pluck(key)
    local items = self:get(config.storage, {})
    local values = {}

    for i = 1, #items do
        local item = items[i]
        local value = item.get and item:get(key) or item[key]

        _insert(values, value)
    end

    return self._Class:new(values)
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
    callback(self)
    return self
end

function MerlinCollection:toArray() return self:all() end

function MerlinCollection:when(condition, callback)
    if condition then
        return callback(self) or self
    end

    return self
end

function MerlinCollection:where(key, value)
    local items = self:all()
    local filtered = {}

    for i = 1, #items do
        local item = items[i]
        local itemValue = (type(item) == "table" and item.get) and item:get(key) or item[key]

        if itemValue == value then
            _insert(filtered, item)
        end
    end

    -- Return a new collection
    return self._Class:new(filtered)
end

return MerlinCollection