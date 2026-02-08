-- This file doesn't do anything yet - it's only here as a placeholder for me to tinker.
-- If you discover this don't judge me too harshly. I'm just testing out some of Lua's
-- features to understand how much "fun" stuff I can do to emulate OOP principles.

---@class Merlin
---@field config { debug: boolean, logPrefix: string }
---@field _Type string
---@field _Parent table
---@field _Registry table
---@field _attributes table|Merlin
---@field _methods table
---@field __init function
---@generic T
Merlin = {
    _Registry = {},
    config = {
        debug = false,
        logPrefix = "[Merlin]", -- need a wand icon or something
    },
}

local json = require("json")
-- who doesn't love some premature optimizations?
local rawget, rawset = rawget, rawset
local type, getmetatable = type, getmetatable

---@param typeName string
---@param class Merlin
local function registerClass(typeName, class)
    Merlin._Registry[typeName] = class
end

---@param level integer
---@param message string
---@param ... any
local function log(level, message, ...)
    ---@diagnostic disable-next-line: unnecessary-if
    if not (Merlin.config and Merlin.config.debug) then return end

    local indent = string.rep(" ", level or 0)
    local prefix = Merlin.config.logPrefix or "[Merlin] "

    pcall(function (...)
        print(string.format("%s%s%s", prefix, indent, string.format(message, ...)))
    end, ...)
    
end

local LUA_METAMETHODS = {
    __tostring = true, __call = true, __concat = true,
    __add = true, __sub = true, __mul = true, __div = true,
    __mod = true, __pow = true, __unm = true, __len = true,
    __eq = true, __lt = true, __le = true, __gc = true
}

---comment
---@param class Merlin|table
---@param bucketName string
---@param key any
---@param level? integer
---@return any
local function recursiveSearch(class, bucketName, key, level)
    level = level or 5
    -- log(level, "Crawling [%s.%s] for '%s'...",rawget(class, "_Type"), bucketName, key)
    local current = class
    while current do
        local bucket = rawget(current, bucketName)
        local value = bucket and bucket[key]
        if value ~= nil then
            -- log(level + 1, "Found in %s", rawget(current, "_Type") or "Unknown")
            return value
        end

        current = rawget(current, "_Parent")
    end

    -- log(level + 1, "[%s] Not found")
    return nil
end

---comment
---@param subject Merlin|table
---@return Merlin|table
local function deepCopy(subject)
    if type(subject) ~= table then return subject end

    local result = {}
    for key, value in pairs(subject) do result[deepCopy(key)] = deepCopy(value) end

    return result
end

---comment
---@param subClass table
---@param typeName string
---@param parent? Merlin|nil
---@return Merlin
local function useStaff(subClass, typeName, parent)
    rawset(subClass, "_Type", typeName)
    rawset(subClass, "_Parent", parent)
    rawset(subClass, "_attributes", {})
    rawset(subClass, "_methods", {})

    registerClass(typeName, subClass)

    -- local methodCache = setmetatable({}, { __mode = "v"} )
    -- local getterCache = setmetatable({}, { __mode = "k" })

    local staff = {
        __index = function(table, key)
            -- log(1, "GETTER: [KEY] '" .. key  .. "' on [TABLE] " .. tostring(table) .. "'")
            
            -- Instance attributes check
            -- log(4, "Instance Attributes Check")
            local instanceAttributes = rawget(table, "_attributes")
            if instanceAttributes and instanceAttributes[key] ~= nil then return instanceAttributes[key] end

            -- -- Check method cache
            -- log(4, "Method Cache Check")
            local cache = rawget(table, "_method_cache")
            if cache and cache[key] ~= nil then return cache[key] end

            local current = rawget(table, "_Class") or subClass
            while current do
                -- log(4, "Method Check on %s", rawget(current, "_Type"))
                local methods = rawget(current, "_methods")
                local value = methods and methods[key]

                if value ~= nil then
                    if type(value) == "function" then
                        -- log(4, "Found Method on %s", rawget(current, "_Type"))
                        cache = cache or {}
                        rawset(table, "_method_cache", cache)
                        cache[key] = value
                    end
                    return value
                end

                local currentAttributes = rawget(current, "_attributes")
                if currentAttributes and currentAttributes[key] ~= nil then return currentAttributes[key] end

                current = rawget(current, "_Parent")
            end
           
            -- log(4, "Direct Instance Table Check")
            local result = rawget(table, key)
            if result ~= nil then return result end

            -- log(4, "Return nil")
            return nil
        end,

        __newindex = function (table, key, value)
            -- log(1, "SETTER: [KEY] '" .. key .. "' with [VALUE] '" .. tostring(value) .. "'")

            local cache = rawget(table, "_method_cache")
            if cache and cache[key] then
                -- log(4, "Invalidated Cache: " .. key)
                cache[key] = nil
            end

            if LUA_METAMETHODS[key] then
                -- log(4, "System Hook Applied: " .. key)
                rawset(table, key, value)
                return
            end

            if type(value) == "function" then
                local methods = rawget(table, "_methods")
                if methods then
                    -- log(4, "Method Cached on Class")
                    methods[key] = value
                else
                    -- log(4, "Method/Function Cached in Instance Attributes")
                    rawget(table, "_attributes")[key] = value
                end
                if key == "__init" then
                    rawset(subClass, "_initChain", nil)
                end
            else
                local attributes = rawget(table, "_attributes")
                if (attributes) then
                    -- log(4, "Attribute Cached on Instance")
                    attributes[key] = value
                else
                    -- log(4, "Fallback Stored Directly on Table")
                    rawset(table, key, value)
                end
            end
        end
    }

    return setmetatable(subClass, staff)
end

useStaff(Merlin, "Merlin", nil)

---@generic T : Merlin
---@param typeName string
---@param ...? any
---@return table|T|Merlin
function Merlin:derive(typeName, ...)
    -- lets make sure the parent has been initialized
    self.__init(self, ...)
    local subClass = useStaff({}, typeName, self)
    -- useStaff(subClass, typeName, self)

    local parentAttributes = rawget(self, "_attributes")
    local childAttributes = rawget(subClass, "_attributes")

    for key, value in pairs(parentAttributes) do
        -- need to check for tables
        if type(value ) == "table" then
            childAttributes[key] = deepCopy(value)
        else
            childAttributes[key] = value
        end
    end

    return subClass
end

---@generic T : Merlin
---@param ...? any
---@return table|T
function Merlin:new(...)
    local instance = {
        _attributes = {},
        _Class = self,
    }
    setmetatable(instance, getmetatable(self))

    local init = self.__init
    init(instance, ...)

    return instance
end

function Merlin:__init(...)
    log(1, "__init called on %s", Merlin.config.logPrefix)
end

---comment
---@generic T : Merlin
---@param attribute any
---@param value any
---@return T
function Merlin:setAttribute(attribute, value)
    self._attributes[attribute] = value

    return self
end

---@param attribute any
---@param default any
---@return any
function Merlin:getAttribute(attribute, default)
    local attributeGetter = Merlin.getAttributeGetter(self, attribute)
    if attributeGetter and type(attributeGetter) == "function" then
        return attributeGetter(self)
    end

    local attributes = rawget(self, "_attributes")
    if attributes and attributes[attribute] then return attributes[attribute] end

    attribute = rawget(self, attribute)
    if attribute ~= nil then return attribute end

    return default
end

---@param typeName string
---@return boolean
function Merlin:belongsTo(typeName)
    local current = rawget(self, "_Class") or self

    while current do
        if rawget(current, "_Type") == typeName then
            return true
        end
        current = rawget(current, "_Parent")
    end

    return false
end

---@return Merlin
function Merlin:super()
    local cache = rawget(self, "_super_cache")
    
    if cache then
        log(1, "Super Cache Hit")
        return cache
    end

    local class = rawget(self, "_Class") or self
    local parent = rawget(class, "_Parent")

    if not parent then
        error(Merlin.config.logPrefix .. " " .. (rawget(class, "_Type") or "Unknown") .. " has no Parent")
    end

    local proxy = setmetatable({}, {
        __index = function(_, key)
            local method = parent[key]
            if type(method) == "function" then
                return function(_, ...)
                    return method(self, ...)
                end
            end
            return method
        end
    })
    
    log(1, "Super Proxy Cached")
    rawset(self, "_super_cache", proxy)
    return proxy
end

--- Called whenever an object has been deserialized.
function Merlin:onRestore()
    log(1, "onRestore called")
end

---@return string
function Merlin:toString()
    return self:toJson()
end

---@return string
function Merlin:toJson()
    return json.encode(self:flattenTable())
end

---@param seen any
---@return table|nil
function Merlin:flattenTable(seen)
    seen = seen or {}
    if seen[self] then return nil end
    seen[self] = true

    local class = rawget(self, "_Class") or self
    local typeName = rawget(class, "_Type") or "Merlin"

    local flattened = {}

    local function merge(target)
        local attributes = rawget(target, "_attributes") or {}

        for key, value in pairs(attributes) do
            local isNewData = (flattened[key] == nil) and (type(value) ~= "function")

            if isNewData then
                local isMerlin = type(value) == "table" and (value.flattenTable or rawget(value, "_Class"))

                flattened[key] = isMerlin and value:flattenTable(seen) or value
            end
        end
    end

    local current = self
    while current do
        merge(current)
        local nextTarget = rawget(self, "_Class") or rawget(current, "_Parent")

        if nextTarget == current then break end
        current = nextTarget
    end

    return {
        [typeName] = flattened
    }
end

--- @generic T : Merlin
--- @param data table|string    Raw datatable - this usually comes from json.decode or Merlin:fromJson
--- @param targetClass? `T`      Just used to help the IDE
--- @return T|table
function Merlin.fromData(data, targetClass)
    -- Another place we should throw an error
    if type(data) ~= "table" then return data end

    ---@type string|any, table|any
    local typeName, attributes = next(data)

    if type(attributes) == "table" and attributes._Type then typeName = attributes._Type end

    local class = Merlin._Registry[typeName]

    -- Probably an error here too
    if not class then return data end

    local instance = {
        _attributes = {},
        _Class = class
    }
    setmetatable(instance, getmetatable(class))

    for key, value in pairs(attributes) do
        if key ~= "_Type" then
            instance[key] = (type(value) == "table") and Merlin.fromData(value) or value
        end
    end

    if instance.onRestore and type(instance.onRestore) == "function" then instance:onRestore() end

    local result = instance

    return result
end

--- @generic T : Merlin
--- @param jsonString string
--- @param targetClass? `T`      Just used to help the IDE
--- @return T|table
function Merlin.fromJson(jsonString, targetClass)
    --- @type boolean, table|string
    local success, data = pcall(json.decode, jsonString)

    if not success then
        log(1, "JSON Decode Error: " .. tostring(data))
        return nil
    end

    return Merlin.fromData(data, targetClass)
end

---@param instance Merlin
---@param attribute any
---@return function|nil
function Merlin.getAttributeGetter(instance, attribute)
    local getterName = "get"  .. Merlin.firstToUpper(attribute)
    local attributeGetter = recursiveSearch(rawget(instance, "_Class") or instance, "_methods", getterName)

    return attributeGetter
end

function Merlin.firstToUpper(value)
    -- @TODO: throw an error here because we care about type safety
    if type(value) ~= "string" then print("should this be an error?") return value end

    return (value:gsub("^%l", string.upper))
end

return Merlin