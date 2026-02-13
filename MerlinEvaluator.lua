local MerlinEvaluator = {}

local _contains = function(expected, actual)
    ---@TODO Need a log entry
    if type(expected) ~= "table" then return false end

    -- Handle MerlinCollection
    if type(expected.each) == "function" then
        local found = false
        expected:each(function(item)
            if item == actual then 
                found = true
                return false -- Break 'each' loop
            end
        end)
        return found
    end

    -- Handle Raw Table
    for i = 1, #expected do
        if expected[i] == actual then 
            return true 
        end
    end
    
    return false
end

MerlinEvaluator.OPERATORS = {
    ['=']  = function(a, b) return a == b end,
    ['=='] = function(a, b) return a == b end,
    ['!='] = function(a, b) return a ~= b end,
    ['~='] = function(a, b) return a ~= b end,
    ['<>'] = function(a, b) return a ~= b end,
    ['>']  = function(a, b) return a > b end,
    ['>='] = function(a, b) return a >= b end,
    ['<']  = function(a, b) return a < b end,
    ['<='] = function(a, b) return a <= b end,
    ['in'] = function(actual, expected)
        return _contains(expected, actual)
    end,
    ['notin'] = function(actual, expected)
        return not _contains(expected, actual)
    end,
}

function MerlinEvaluator:evaluate(actual, operator, expected)
    local opFunc = self.OPERATORS[operator]
    if not opFunc then
        error("Merlin: Unknown operator [" .. tostring(operator) .. "]")
    end
    return opFunc(actual, expected)
end

function MerlinEvaluator.getOperator(op) return MerlinEvaluator.OPERATORS[op] or MerlinEvaluator.OPERATORS['='] end

function MerlinEvaluator:normalizeKey(key, operatorOrValue, value)
    if value == nil then
        value = operatorOrValue
        operatorOrValue = "="
    end
    -- Kinda neat but a little too lua for me.. i'd rather do it the way i have been because its more clear
    -- local operator = value == nil and "=" or operatorOrValue
    -- local expected = value == nil and operatorOrValue or value

    local operatorFunc = self.OPERATORS[operatorOrValue]
    if not operatorFunc then
        ---@TODO another level of abstraction for error reporting...
        operatorFunc = self.OPERATORS["="] -- this is a lot of assumption..
    end

    return key, operatorFunc, value
end

function MerlinEvaluator:resolve(item, key)
    -- something here - we'll see
    if type(item) ~= "table" then return nil end

    if item.get and type(item.get) == "function" then return item:get(key) end

    return item[key]
end

function MerlinEvaluator:satisfies(item, key, operatorFunc, expected)
    local actual = self:resolve(item, key)
    local success, result = pcall(operatorFunc, actual, expected)

    return success and result
end

return MerlinEvaluator