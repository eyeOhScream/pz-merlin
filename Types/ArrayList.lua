local ArrayList = {}
local PROXY_TAG = "MERLIN_ARRAYLIST_PROXY"

function ArrayList.is(value)
    if not value or (type(value) ~= "table" and type(value) ~= "userdata") then return false end

    -- 1. Check for Proxy Tag
    local mt = getmetatable(value)
    if mt and mt[PROXY_TAG] then return true end

    -- 2. Check for Java/Mock capability (Size and Get must exist)
    -- We check the field directly
    local hasSize = value.size ~= nil
    local hasGet = value.get ~= nil

    return hasSize and hasGet
end

function ArrayList.wrap(javaList)
    if not ArrayList.is(javaList) then return javaList end

    return setmetatable({}, {
        [PROXY_TAG] = true,
        
        __index = function(_, key)
            if type(key) == "number" then
                return javaList:get(key - 1)
            end

            local val = javaList[key]
            if type(val) == "function" then
                return function(_, ...) 
                    return val(javaList, ...) 
                end
            end
            
            return val
        end
    })
end

return ArrayList