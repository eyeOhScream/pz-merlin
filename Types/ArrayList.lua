local ArrayList = {}
ArrayList.__index = ArrayList

function ArrayList.is(value)
    if not value then return false end
    local t = type(value)
    if t ~= "userdata" and t ~= "table" then return false end

    -- Check if it is the Proxy via string tag (most reliable)
    local mt = getmetatable(value)
    if mt and mt.__merlin_type == "ArrayListProxy" then return true end
    
    -- Check if it is the raw Java/Mock object
    return value.size ~= nil and value.get ~= nil
end

function ArrayList.wrap(javaList)
    -- If it's already a proxy or NOT a list, return as-is
    local mt = getmetatable(javaList)
    if (mt and mt.__merlin_type == "ArrayListProxy") or not ArrayList.is(javaList) then 
        return javaList 
    end

    return setmetatable({}, {
        __merlin_type = "ArrayListProxy",
        __index = function(_, key)
            if type(key) == "number" then
                return javaList:get(key - 1)
            end
            local val = javaList[key]
            if type(val) == "function" then
                return function(_, ...) return val(javaList, ...) end
            end
            return val
        end
    })
end

return ArrayList