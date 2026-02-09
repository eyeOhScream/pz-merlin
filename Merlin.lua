-- This file doesn't do anything yet - it's only here as a placeholder for me to tinker.
-- If you discover this don't judge me too harshly. I'm just testing out some of Lua's
-- features to understand how much "fun" stuff I can do to emulate OOP principles.


-- who doesn't love some premature optimizations?
local rawget, rawset, type = rawget, rawset, type
local getmetatable, setmetatable = getmetatable, setmetatable
local pairs, ipairs, next = pairs, ipairs, next

local json = require("json")

---@class Merlin
---@field config { debug: boolean, logPrefix: string }
---@field jsonProvider table JSON provider that should have an encode and decode function/method
---@field _Type string
---@field _Parent table
---@field _Registry table
---@field _attributes table|Merlin
---@field _methods table
---@field _getterCache table
---@field __init function
---@generic T
Merlin = {
    _Registry = setmetatable({}, { __mode = "v" }),
    _getterCache = {},
    config = {
        debug = false,
        logPrefix = "[Merlin]", -- need a wand icon or something
    },
}

Merlin.jsonProvider = json

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

local function firstToUpper(value)
    if type(value) ~= "string" then
        log(1, "firstToUpper expects a string but was given: %s", tostring(value))
        return nil
    end

    return (value:sub(1,1):upper() .. value:sub(2))
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

    local staff = {
        -- __call = function(cls, ...) return cls:new(...) end, -- need to work on this
        __tostring = function (table) return table:toString() end,
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
            if LUA_METAMETHODS[key] then
                log(4, "System Hook Applied: " .. key)
                rawset(table, key, value)
                return
            end

            local attributes = rawget(table, "_attributes")
            if attributes and attributes[key] == value then return end

            local wasDirty = rawget(table, "_isDirty")

            rawset(table, "_isDirty", true)
            rawset(table, "_json_cache", nil)

            if not wasDirty then
                local onDirty = table.onDirty
                if type(onDirty) == "function" then
                    onDirty(table, key, value)
                end
            end

            local cache = rawget(table, "_method_cache")
            if cache and cache[key] then
                -- log(4, "Invalidated Cache: " .. key)
                cache[key] = nil
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

function Merlin:get(attribute, default) return self:getAttribute(attribute, default) end

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

function Merlin:getAttributes() return rawget(self, "_attributes") or {} end

---@param instance Merlin
---@param attribute any
---@return function|nil
function Merlin.getAttributeGetter(instance, attribute)
    local getterName = Merlin._getterCache[attribute]

    if not getterName then 
        getterName = "get"  .. firstToUpper(attribute)
        Merlin._getterCache[attribute] = getterName
    end
    
    local attributeGetter = recursiveSearch(rawget(instance, "_Class") or instance, "_methods", getterName)
    if type( attributeGetter) == "function" then return attributeGetter end

    return nil
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

--- @param classOrName string|table The class name (string) or the Class object.
--- @return boolean
function Merlin:isA(classOrName)
    local targetName = type(classOrName) == "table" and rawget(classOrName, "_Type") or classOrName
    
    return self:belongsTo(targetName)
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

function Merlin:copy()
    local class = rawget(self, "_Class") or self
    local twin = class:new()

    local originalAttributes = rawget(self, "_attributes")
    local twinAttributes = rawget(twin, "_attributes")

    for key, value in pairs(originalAttributes) do
        if type(value) == "table" then
            twinAttributes[key] = deepCopy(value)
        else
            twinAttributes[key] = value
        end
    end

    if twin.onCopy then
        twin:onCopy(self)
    end

    return twin
end


--- Called whenever an object has been deserialized.
function Merlin:onRestore()
    log(1, "onRestore called")
end

local function deepCopyDataOnly(obj, seen)
    if type(obj) ~= "table" then return obj end
    
    seen = seen or {}
    if seen[obj] then return nil end
    seen[obj] = true

    local res = {}
    for k, v in pairs(obj) do
        -- Skip logic and internal keys
        if type(v) ~= "function" and type(k) ~= "function" and tostring(k):sub(1,1) ~= "_" then
            res[k] = deepCopyDataOnly(v, seen)
        end
    end

    return res
end

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
            -- Guard: Skip if already handled or if it's a function
            if flattened[key] == nil and type(value) ~= "function" then
                
                -- 1. Check if it's a Merlin object first
                local isMerlin = type(value) == "table" and rawget(value, "_Class") ~= nil
                
                if isMerlin then
                    -- Direct recursion for Merlin objects
                    flattened[key] = value:flattenTable(seen)
                else
                    -- 2. Standard Data/Tables
                    -- Pass 'seen' to handle circular refs in plain tables
                    flattened[key] = deepCopyDataOnly(value, seen)
                end
            end
        end
    end

    merge(self)  -- Instance overrides
    merge(class) -- Class defaults (which include parent defaults via derive)

    flattened._Type = typeName
    return { [typeName] = flattened }
end

---comment
---@param source table|Merlin
---@param overwrite? boolean
---@return table|Merlin
function Merlin:merge(source, overwrite)
    if overwrite == nil then overwrite = true end

    local isMerlin = type(source) == "table" and rawget(source, "_Class") ~= nil
    local sourceData = isMerlin and rawget(source, "_attributes") or source

    if type(sourceData) ~= "table" then
        log(1, "ERROR: merge() expects a table or Merlin object.")
        -- error(Merlin.config.logPrefix .. "merge() expects a table or Merlin object")
        return self
    end

    local currentAttributes = rawget(self, "_attributes")

    for key, value in pairs(sourceData) do
        local isData = type(value) ~= "function" and tostring(key):sub(1,1) ~= "_"
        local canWrite = overwrite or currentAttributes[key] == nil

        if isData and canWrite then
            local isTable = type(value) == "table"
            currentAttributes[key] = isTable and deepCopyDataOnly(value) or value
        end
    end

    return self
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

    -- Let's make sure the restored object is set to clean being that it likely came from a data store
    rawset(instance, "_isDirty", false)

    if instance.onRestore and type(instance.onRestore) == "function" then instance:onRestore() end

    local result = instance

    return result
end

function Merlin.setJsonProvider(provider) Merlin.jsonProvider = provider end

--- @generic T : Merlin
--- @param jsonString string
--- @param targetClass? `T`      Just used to help the IDE
--- @return T|table
function Merlin.fromJson(jsonString, targetClass)
    --- @type boolean, table|string
    local success, data = pcall(Merlin.jsonProvider.decode, jsonString)

    if not success then
        log(1, "JSON Decode Error: " .. tostring(data))
        return nil
    end

    return Merlin.fromData(data, targetClass)
end

---@return string
function Merlin:toString()
    local class = rawget(self, "_Class") or self
    local isInstance = rawget(self, "_Class") ~= nil
    local prefix = isInstance and "" or "Class:"
    local typeName = rawget(class, "_Type") or "Merlin"
    
    -- first we have to strip the metatable
    local holdThis = getmetatable(self)
    setmetatable(self, nil)
    local addr = tostring(self):gsub("table: ", "")
    setmetatable(self, holdThis)
    
    
    local attributes = rawget(self, "_attributes")
    local label = attributes and attributes.id or ""
    if label ~= "" then label = " '" .. tostring(label) .. "'" end

    return string.format("[%s%s] (%s)", prefix .. typeName, label, addr)
end

---@return string
function Merlin:toJson()
    local cachedJson = rawget(self, "_json_cache")

    if not self:isDirty() and cachedJson ~= nil then return cachedJson end

    local data = self:flattenTable()
    local jsonString = Merlin.jsonProvider.encode(data)

    rawset(self, "_json_cache", jsonString)
    rawset(self, "_isDirty", false)

    return jsonString
end

function Merlin:onDirty(key, value)
    log(1, "onDirty fired on %s for %s = %s", tostring(self), tostring(key) , tostring(value))
end

function Merlin:isDirty() return rawget(self, "_isDirty") == true end

function Merlin:clean() rawset(self, "_isDirty", false) end

function Merlin:markDirty(key, value)
    key = key or "manual"
    local wasDirty = rawget(self, "_isDirty")

    if not wasDirty and type(self.onDirty) == "function" then
        self:onDirty(key or "manual", value)
    end

    rawset(self, "_isDirty", true)
    rawset(self, "_json_cache", nil)
end

function Merlin.isMerlin(value)
    return type(value) == "table" and rawget(value, "_Class") ~= nil
end

if not _G.Merlin then _G.Merlin = Merlin end

return Merlin