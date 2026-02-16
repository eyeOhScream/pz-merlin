local Merlin = require("Merlin")
-- local MerlinEvaluator = require("MerlinEvaluator")
-- local MerlinQueryBuilder = require("MerlinQueryBuilder")

---@class MerlinCollection : Merlin
local MerlinCollection = Merlin:derive("MerlinCollection")

_G.MERLINCOLLECTION_TEST_MODE = _G.MERLINCOLLECTION_TEST_MODE or nil

local table = table
local _insert = table.insert

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

local function _resolve(item, key)
    return (type(item) == "table" and item.get) and item:get(key) or item[key]
end

local function _matches(item, key, operatorFunc, value)
    local itemValue = _resolve(item, key)
    local success, result = pcall(operatorFunc, itemValue, value)
    return success and result
end

local function _log(level, message, ...)
    return Merlin.__logger(level, message, ...)
end

local function _typeError(method, parameter, expectedType, value, receivedTypeOverride)
    local receivedType = receivedTypeOverride or type(value)
    local message = string.format("%s expects %s to be %s but received `%s`.", method, parameter, expectedType, receivedType)
    return _log(1, message)
end

---@param items any
---@return MerlinCollection
function MerlinCollection:new(items)
    local ArrayList = require("Types.ArrayList")
    local collection = Merlin.new(self)

    if items then
        if ArrayList.is(items) then
            -- If it's a Java List, we wrap it and store it as the collection data
            collection:set("_attributes", ArrayList.wrap(items))
        else
            -- If it's a Lua table
            for key, value in pairs(items) do
                collection:set(key, value)
            end
        end
    end

    return collection
end

function MerlinCollection:add(item) return self:push(item) end

function MerlinCollection:all()
    -- Check for the Proxy first
    local attr = rawget(self, "_attributes")
    if attr then return attr end
    
    -- Fallback: The collection instance itself holds the Lua-table data
    return self
    -- return rawget(self, "_attributes")
end

function MerlinCollection:cast(className)
    local Class = Merlin._Registry[className]
    
    if not Class then
        _typeError("MerlinCollection:cast()", "className", "a class name of a class that has derived from Merlin", nil, className)
        return self
    end


    return self:map(function (item)
        -- Already a Merlin object so move on
        if type(item) == "table" and item._isMerlin then return item end

        return Class:new(item)
    end)
end

function MerlinCollection:contains(item)
    local items = self:all()
    local total = self:count()

    for i = 1, total do
        if items[i] == item then
            return true
        end
    end
    return false
end

function MerlinCollection:count()
    local items = self:all()
    local ArrayList = require("Types.ArrayList")

    if ArrayList.is(items) then return items:size() end

    return #items
end

function MerlinCollection:destroy(recursive)
    local items = self:all()
    if not items then return nil end

    if recursive then
        for i = 1, #items do
            local item = items[i]
            if type(item) == "table" and item.destroy then item:destroy() end
        end
    end

    return Merlin.destroy(self)
end

function MerlinCollection:each(callback)
    local items = self:all()
    local total = self:count()

    for i = 1, total do
        if callback(items[i], i) == false then break end
    end

    return self
end

---@param callback function
---@return MerlinCollection
function MerlinCollection:filter(callback)
    local items = self:all()
    local filtered = {}

    for i = 1, #items do
        if callback(items[i], i) then _insert(filtered, items[i]) end
    end

    return self._Class:new(filtered)
end

function MerlinCollection:first() return self:all()[1] end

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
        if _matches(item, key, operatorFunc, value) then return item end
    end

    return nil
end

function MerlinCollection:groupBy(key)
    local items = self:all()
    local groups = {}

    for i = 1, #items do
        local item = items[i] or {}
        local groupKey = (type(item) == "table" and item.get) and item:get(key) or item[key]

        groupKey = groupKey or tostring(groupKey or "undefined")

        if not groups[groupKey] then groups[groupKey] = MerlinCollection:new({}) end

        groups[groupKey]:push(item)
    end

    return MerlinCollection:new(groups)
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
        local item = items[i] or {}
        if _matches(item, key, operatorFunc, value) then return item end
    end

    return nil
end

function MerlinCollection:map(callback, keepNilValues)
    if keepNilValues == nil then keepNilValues = false end

    if type(keepNilValues) ~= "boolean" then
        _typeError("MerlinCollection:map()", "keepNilValues", "boolean or nil", keepNilValues)
        return self
    end

    if type(callback) ~= "function" then
        _typeError("MerlinCollection:map()", "callback", "function", callback)
        return self
    end

    local items = self:all()
    local mapped = {}

    for i = 1, #items do
        local result = callback(items[i], i)

        if result ~= nil then
            if keepNilValues then
                mapped[i] = result
            else
                _insert(mapped, result)
            end
        elseif result == nil and keepNilValues then
            -- Note: In Lua, assigning nil to a key is redundant, 
            -- but we keep the logic explicit for clarity.
            mapped[i] = nil
        end
        -- mapped[i] = callback(items[i], i)
    end

    return MerlinCollection:new(mapped)
end

function MerlinCollection:pipe(callback)
    ---@TODO add log entry here
    if type(callback) == "function" then return callback(self) end

    return self
end

function MerlinCollection:pluck(key)
    return self:map(function(item)
        return (type(item) == "table" and item.get) and item:get(key) or item[key]
    end)
end

function MerlinCollection:push(item)
    local items = rawget(self, "_attributes")
    return self:set(#items + 1, item)
end

function MerlinCollection:put(key, value) return self:set(key, value) end

function MerlinCollection:query()
    local MerlinQueryBuilder = require("MerlinQueryBuilder")
    return MerlinQueryBuilder:new(self)
end

function MerlinCollection:reduce(callback, initial)
    ---@TODO we need a log entry here
    if type(callback) ~= "function" then return self end

    local items = self:all()
    local accumulator = initial

    for i = 1, #items do
        local item = items[i]
        accumulator = callback(accumulator, item, i)
    end

    return accumulator
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
    if descending == nil then descending = false end

    ---@TODO we need to toss a log entry here
    if type(descending) ~= "boolean" then return self end

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

    return MerlinCollection:new(sorted)
end

function MerlinCollection:sortByDescending(key) return self:sortBy(key, true) end

function MerlinCollection:tap(callback)
    ---@TODO make this a type check and add a log entry
    if type(callback) == "function" then
        callback(self)
        return self
    end

    return self
end

function MerlinCollection:toArray() return self:all() end

function MerlinCollection:unless(condition, callback)
    ---@TODO type check and log entry
    if type(callback) == "function" then return self:when(not condition, callback) end

    return self
end

function MerlinCollection:when(condition, callback)
    ---@TODO type check and log entry
    if condition and type(callback) == "function" then return callback(self) or self end
    return self
end

--- @param key string
--- @operatorOrValue any
--- @value any|nil
--- @return MerlinCollection
function MerlinCollection:where(key, operatorOrValue, value) 
    return self:query():where(key, operatorOrValue, value):get()
end

function MerlinCollection:whereBetween(key, range)
    if type(range) ~= "table" or #range < 2 then
        _typeError("MerlinCollection:whereBetween()", "range", "table {min, max}", range)
        return self
    end

    local min, max = range[1], range[2]

    return self:filter(function(item)
        local val = _resolve(item, key)
        return type(val) == "number" and val >= min and val <= max
    end)
end

function MerlinCollection:whereIn(key, values) return self:query():whereIn(key, values):get() end

function MerlinCollection:whereInstanceOf(className)
    local Class = Merlin._Registry[className]
    
    if not Class then
        _typeError("MerlinCollection:whereInstanceOf()", "className", "registered Merlin class", nil, className)
        return self
    end

    return self:filter(function(item)
        return type(item) == "table" and item.instanceOf and item:instanceOf(Class)
    end)
end

function MerlinCollection:whereNotBetween(key, range)
    if type(range) ~= "table" or #range < 2 then
        _typeError("MerlinCollection:whereNotBetween()", "range", "table {min, max}", range)
        return self
    end

    local min, max = range[1], range[2]

    return self:filter(function(item)
        local val = _resolve(item, key)
        return type(val) == "number" and (val < min or val > max)
    end)
end

function MerlinCollection:whereNotIn(key, values) return self:query():whereNotIn(key, values):get() end

if _G.MERLINCOLLECTION_TEST_MODE then
    MerlinCollection._test = {
        _typeError = _typeError,
        _log = _log
    }
end

return MerlinCollection