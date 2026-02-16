-- local Coverage = require("tests.Coverage")
-- Coverage:start()

-- local Merlin = require("Merlin")
local TestCase = require("tests.TestCase")
local MerlinTests = TestCase:new("MerlinTests")

function MerlinTests:setUp()
    package.loaded["Merlin"] = nil
    self.Merlin = require("Merlin")
end

function MerlinTests:TestBasicDerive()
    local Merlin = self.Merlin
    local Derived = Merlin:derive("Derived")

    self:assertIsTrue(Derived:isClass())
end

function MerlinTests:TestNewRespectsTableProperties()
    local Merlin = self.Merlin

    local TestingObject = {
        name = "TestObject",
        someValue = 111,
    }

    function TestingObject:justReturnTrue() return true end
    
    local Derived = Merlin:derive("TestingObject")
    local instance = Derived:new(TestingObject)

    self:assertEqual("TestObject", instance.name)
    self:assertIsTrue(instance:justReturnTrue())
end

MerlinTests:run()

return MerlinTests