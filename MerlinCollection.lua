local Merlin = require("Merlin")

---@class MerlinCollection : Merlin
local MerlinCollection = Merlin:derive("Collection")

local config = {
    storage = "__merlinCollection"
}

local insert = table.insert

function MerlinCollection:new(items)
    local collection = Merlin.new(self)

    collection:set(config.storage, items or {})

    return collection
end

---comment
---@param callback function
---@return table|MerlinCollection
function MerlinCollection:filter(callback)
    local items = self:get(config.storage, {})
    local filtered = {}

    for i = 1, #items do
        if callback(items[i], i) then insert(filtered, items[i]) end
    end

    -- Return a new collection
    return self._Class:new(filtered)
end

function MerlinCollection:each(callback)
    local items = self:get(config.storage, {})

    for i = 1, #items do
        if callback(items[i], i) == false then break end
    end

    return self
end

function MerlinCollection:where(key, value)
    local items = self:get(config.storage, {})
    local filtered = {}

    for i = 1, #items do
        local item = items[i]

        if item:get(key) == value then
            insert(filtered, item)
        end
    end

    -- Return a new collection
    return self._Class:new(filtered)
end

function MerlinCollection:firstWhere(key, value)
    local items = self:get(config.storage, {})

    for i = 1, #items do
        local item = items[i]

        if item:get(key) == value then
            return item
        end
    end

    return nil
end

return MerlinCollection