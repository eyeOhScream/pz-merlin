-- This file doesn't do anything yet - it's only here as a placeholder for me to tinker.
-- If you discover this don't judge me too harshly. I'm just testing out some of Lua's
-- features to understand how much "fun" stuff I can do to emulate OOP principles.

---@class Merlin
---@field config { debug: boolean, logPrefix: string, useIcons: boolean }
---@field _Type string
---@field _Parent table
---@field _attributes table
---@field _methods table
---@field __init function
Merlin = {}
Merlin.config = {
    debug = false,
    logPrefix = "[Merlin]", -- need a wand icon or something
    useIcons = true
}

local function beard(level, msg, ...)
    -- Hate all of the this
    ---@diagnostic disable-next-line: unknown-diag-code
    ---@diagnostic disable-next-line: unused-function, unnecessary-if
    if not Merlin.config.debug then return end
    local prefix = Merlin.config.logPrefix .. string.rep("  ", level)
    print(prefix .. string.format(msg, ...))
end

local LUA_METAMETHODS = {
    __tostring = true, __call = true, __concat = true,
    __add = true, __sub = true, __mul = true, __div = true,
    __mod = true, __pow = true, __unm = true, __len = true,
    __eq = true, __lt = true, __le = true, __gc = true
}

local function recursiveSearch(class, bucketName, key)
    -- This needs its own cache
    print("     -- recursive class crawl for [BUCKET] '" .. bucketName .. "'" )
    local current = class
    while current do
        local bucket = rawget(current, bucketName)
        local value = bucket and bucket[key]
        if value ~= nil then
            return value
        end

        current = rawget(current, "_Parent")
    end

    return nil
end

local function useStaff(subClass, typeName, parent)
    rawset(subClass, "_Type", typeName)
    rawset(subClass, "_Parent", parent)
    rawset(subClass, "_attributes", {})
    rawset(subClass, "_methods", {})

    local methodCache = setmetatable({}, { __mode = "v"} )
    local getterCache = setmetatable({}, { __mode = "k" })

    local staff = {
        __index = function(table, key)
            print("Magic GETTER: [KEY] '" .. key  .. "' on [TABLE] " .. tostring(table) .. "'")

            -- 1. Check method cache.
            print("     -- methodCache check")
            local cached = methodCache[key]
            if cached ~= nil then return cached end

            print("     -- instance _attributes check")
            local instanceAttributes = rawget(table, "_attributes")
            if instanceAttributes and instanceAttributes[key] ~= nil then return instanceAttributes[key] end

            print("     -- class _attributes check")
            local defaultAttributes = rawget(subClass, "_attributes")[key]
            if defaultAttributes ~= nil then return defaultAttributes end

            local recursiveAttribute = recursiveSearch(subClass, "_attributes", key)
            if recursiveAttribute ~= nil then return recursiveAttribute end

            local recursiveMethod = recursiveSearch(subClass, "_methods", key)
            if recursiveMethod ~= nil then
                -- This line could cause issues in the future with dynamically added methods/functions
                -- For that matter all method/function caches may struggle with this.
                methodCache[key] = recursiveMethod
                return recursiveMethod
            end
           
            print("     -- direct instance table check fallback")
            local result = rawget(table, key)
            if result ~= nil then return result end

            print("     -- return nil")
            return nil
        end,

        __newindex = function (table, key, value)
            print( "Magic SETTER: [KEY] '" .. key .. "' with [VALUE] '" .. tostring(value) .. "'")

            if LUA_METAMETHODS[key] then
                print("     -- system hook applied: " .. key)
                rawset(table, key, value)
                return
            end

            if type(value) == "function" then
                local methods = rawget(table, "_methods")
                if methods then
                    print("     -- method cached on class")
                    methods[key] = value
                else
                    print("     -- method cached on instance in attributes")
                    rawget(table, "_attributes")[key] = value
                end
                if key == "__init" then
                    rawset(subClass, "_initChain", nil)
                end
            else
                local attributes = rawget(table, "_attributes")
                if (attributes) then
                    print("     -- attribute cached on instance")
                    attributes[key] = value
                else
                    print("     -- fallback stored directly on table")
                    rawset(table, key, value)
                end
            end
        end
    }

    return setmetatable(subClass, staff)
end

useStaff(Merlin, "Merlin", nil)

function Merlin:derive(typeName)
    local subClass = {}
    return useStaff(subClass, typeName, self)
end

---@return table|Merlin
function Merlin:new(...)
    -- original 'new' code
    local instance = {
        _attributes = {},
        _Class = self,
        --  __init = {},
    }
    setmetatable(instance, getmetatable(self))

    local initChain = rawget(self, "_initChain")
    if not initChain then
        initChain = {}
        local current = self

        while current do
            local methods = rawget(current, "_methods")
            ---@type function|nil
            local init = methods and methods["__init"]
            if init then
                table.insert(initChain, 1, init) -- parent first
            end

            -- Next parent
            current = rawget(current, "_Parent")
        end
        rawset(self, "_initChain", initChain)
    end

    for _, init in ipairs(initChain) do
        init(instance, ...)
    end

    return instance
end

function Merlin:__init()
    print("__init fired on [Merlin]")
end

function Merlin:setAttribute(attribute, value)
    self._attributes[attribute] = value
end

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
function Merlin.getAttributeGetter(instance, attribute)
    -- local getterCache = rawget(instance, "_")
    local getterName = "get"  .. Merlin.firstToUpper(attribute)
    -- local attributeGetter = instance[getterName] -- or recursiveSearch(instance, "_methods", getterName)
    local attributeGetter = recursiveSearch(rawget(instance, "_Class") or instance, "_methods", getterName)

    return attributeGetter
end

function Merlin.firstToUpper(value)
    -- @TODO: throw an error here because we care about type safety
    if type(value) ~= "string" then print("should this be an error?") return value end

    return (value:gsub("^%l", string.upper))
end

return Merlin