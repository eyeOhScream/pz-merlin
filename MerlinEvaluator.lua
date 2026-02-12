local MerlinEvaluator = {}

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
}

function MerlinEvaluator:evaluate(actual, operator, expected)
    local opFunc = self.OPERATORS[operator]
    if not opFunc then
        error("Merlin: Unknown operator [" .. tostring(operator) .. "]")
    end
    return opFunc(actual, expected)
end

function MerlinEvaluator:getOperator(symbol)
    local operator = self.OPERATORS[symbol]

    if not operator then return self.OPERATORS["="] end

    return operator
end

function MerlinEvaluator:normalizeKey(key, operatorOrValue, value)
    -- Kinda neat but a little too lua for me.. i'd rather do it the way i have been because its more clear
    local operator = value == nil and "=" or operatorOrValue
    local expected = value == nil and operatorOrValue or value

    local operatorFunc = self.OPERATORS[operator]
    if not operatorFunc then
        ---@TODO another level of abstraction for error reporting...
        operatorFunc = self.OPERATORS["="] -- this is a lot of assumption..
    end

    return key, operatorFunc, expected
end

function MerlinEvaluator:resolve(item, key)
    -- something here - we'll see
    if type(item) == "table" then return nil end

    if item.get and type(item.get) == "function" then return item:get(key) end

    return item[key]
end

function MerlinEvaluator:satisfies(item, key, operatorFunc, expected)
    local actual = self:resolve(item, key)
    local success, result = pcall(operatorFunc, actual, expected)

    return success and result
end

return MerlinEvaluator