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

return MerlinEvaluator