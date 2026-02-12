local MerlinQueryBuilder = {}
MerlinQueryBuilder.__index = MerlinQueryBuilder

function MerlinQueryBuilder:new(collection)
    local instance = {
        _collection = collection,
        _pipeline = {},
    }

    return setmetatable(instance, self)
end