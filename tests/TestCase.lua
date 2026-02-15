local Coverage = require("tests.Coverage")

local TestCase = {
    name = "TestCase",
    colors = {
        reset = "\27[0m",
        red   = "\27[31m",
        green = "\27[32m",
        cyan  = "\27[36m",
        yellow = "\27[33m",
        bold  = "\27[1m"
    },
}
TestCase.__index = TestCase

local function deepCompare(t1, t2)
    -- If they are the same reference, they are equal
    if t1 == t2 then return true end
    
    -- If types differ or one isn't a table, they aren't equal
    if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    
    -- Check all keys in t1 exist in t2 and match
    for k, v in pairs(t1) do
        if not deepCompare(v, t2[k]) then return false end
    end
    
    -- Check if t2 has keys that t1 doesn't
    for k in pairs(t2) do
        if t1[k] == nil then return false end
    end
    
    return true
end

local function tableToString(t)
    if type(t) ~= "table" then return tostring(t) end
    local items = {}
    for k, v in pairs(t) do
        -- Recursively stringify nested tables
        local val = type(v) == "table" and tableToString(v) or tostring(v)
        table.insert(items, string.format("%s=%s", tostring(k), val))
    end
    return "{ " .. table.concat(items, ", ") .. " }"
end

function TestCase:new(name)
    local object = { name = name or self.name }
    setmetatable(object, self)
    return object
end

-- Assertions with level 2 to point to the test file, not this file
function TestCase:assertEqual(expected, actual, message)
    if expected ~= actual then
        error(string.format("%s\n  Expected: %s\n  Actual:   %s", 
            message or "Value mismatch", tostring(expected), tostring(actual)), 2)
    end
end

function TestCase:assertIsTrue(condition, message)
    if not condition then
        error(message or "Assertion failed: expected true, got false", 2)
    end
end

function TestCase:assertNotNil(actual, message)
    if actual == nil then
        error(message or "Unexpected nil value", 2)
    end
end

function TestCase:assertTableEqual(expected, actual, message)
    if not deepCompare(expected, actual) then
        local err = string.format("%s\n  Expected: %s\n  Actual:   %s", 
            message or "Table content mismatch", 
            tableToString(expected), 
            tableToString(actual))
        error(err, 2)
    end
end

-- Shells for lifecycle
function TestCase:setUp() end
function TestCase:tearDown() end

function TestCase:run()
    Coverage:start()
    local passed, failed = 0, 0
    local failures = {}

    print(string.format("\n[ %s ]", self.name or "TestCase"))

    local tests = {}
    for name, func in pairs(self) do
        if type(func) == "function" and name:match("^Test") then
            -- Capture the line number where the test was defined
            local info = debug.getinfo(func, "S")
            local line = info and info.linedefined or 0
            
            table.insert(tests, { 
                name = name, 
                func = func, 
                line = line 
            })
        end
    end

    -- SORT: Keep the logic top-to-bottom as defined in your file
    table.sort(tests, function(a, b)
        return a.line < b.line
    end)

    for _, test in ipairs(tests) do
        -- Double-wrapped pcall preserved exactly as you had it
        local ok, err = pcall(function()
            local test_ok, test_err = pcall(function()
                self:setUp()
                test.func(self)
                self:tearDown()
            end)
            
            if not test_ok then
                error(test_err, 0) 
            end
        end)

        if ok then
            passed = passed + 1
            print("  \27[32m[OK]\27[0m " .. test.name)
        else
            failed = failed + 1
            print("  \27[31m[FAIL]\27[0m " .. test.name)
            table.insert(failures, { name = test.name, err = err })
        end
    end

    -- Failure summary and color logic preserved exactly
    if #failures > 0 then
        print("\n" .. self.colors.red .. self.colors.bold .. "FAILURES!" .. self.colors.reset)
        
        for i, failure in ipairs(failures) do
            print(string.rep("=", 60))
            print(string.format("%d) %s:%s", i, self.name, failure.name))
            print(string.rep("-", 60))
            
            print(failure.err) 
            print(string.rep("=", 60) .. "\n")
        end
    end

    local color = (failed == 0) and self.colors.green or self.colors.red
    print(string.format("%sSummary: %d Tests, %d Passed, %d Failed%s", 
        color, passed + failed, passed, failed, self.colors.reset))

    Coverage:stop()
    Coverage:report()
end

return TestCase