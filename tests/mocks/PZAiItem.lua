local PZAiItem = {}

function PZAiItem.new(id, type, weight)
    local data = {
        _id = id,
        _type = type,
        _weight = weight,
        _isBroken = false
    }

    -- PZ items use Getters for everything
    local instance = {
        getID = function() return data._id end,
        getType = function() return data._type end,
        getWeight = function() return data._weight end,
        isBroken = function() return data._isBroken end,
        setBroken = function(self, val) data._isBroken = val end
    }

    return instance -- No raw properties! This forces Merlin to use the Bridge.
end

return PZAiItem