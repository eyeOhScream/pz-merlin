local MerlinEvaluator = require("MerlinEvaluator")
-- local MerlinCollection = require("MerlinCollection")


local MerlinQueryBuilder = {}
MerlinQueryBuilder.__index = MerlinQueryBuilder

local _insert = table.insert

local processItem = function(item, pipeline, pipelineCount)
    for i = 1, pipelineCount do
        local instruction = pipeline[i]
        if instruction.type == "where" then
            if not MerlinEvaluator:satisfies(item, instruction.key, instruction.operatorFunc , instruction.expected) then
                return false
            end
        end
        -- Add future instruction types (orWhere, etc.) here
    end
    return true
end

function MerlinQueryBuilder:new(collection)
    local instance = {
        _collection = collection,
        _pipeline = {},
    }

    return setmetatable(instance, self)
end

function MerlinQueryBuilder:first()
    local pipeline = self._pipeline
    local pipelineCount = #pipeline
    local foundItem = nil

    self._collection:each(function(item)
        if processItem(item, pipeline, pipelineCount) then
            foundItem = item
            return false -- OPTIONAL: If your 'each' supports breaking by returning false
        end
    end)

    return foundItem
end

function MerlinQueryBuilder:get()
    local results = {}
    local pipeline = self._pipeline
    local pCount = #pipeline

    self._collection:each(function(item)
        if processItem(item, pipeline, pCount) then
            _insert(results, item)
        end
    end)

    local MerlinCollection = require("MerlinCollection")
    return MerlinCollection:new(results)
end

function MerlinQueryBuilder:where(key, operatorOrValue, value)
    local k, operatorFunc, expected = MerlinEvaluator:normalizeKey(key, operatorOrValue, value)

    _insert(self._pipeline, {
        type = "where",
        key = k,
        operatorFunc = operatorFunc,
        expected = expected
    })

    return self
end

function MerlinQueryBuilder:whereIn(key, values)
    _insert(self._pipeline, {
        type = "where",
        key = key,
        operatorFunc = MerlinEvaluator.getOperator("in"),
        expected = values
    })
    return self
end

function MerlinQueryBuilder:whereNotIn(key, values)
    _insert(self._pipeline, {
        type = "where",
        key = key,
        operatorFunc = MerlinEvaluator.getOperator("notin"),
        expected = values
    })
    return self
end

return MerlinQueryBuilder