local TestCase = require("tests.TestCase")
local ArrayList = require("Types.ArrayList")
local ArrayListMock = require("tests.mocks.ArrayListMock")
local MerlinCollection = require("MerlinCollection")

local MerlinCollectionTests = TestCase:new("MerlinCollectionTests")

function MerlinCollectionTests:setUp()
    self.rawTable = { {name = "Axe"}, {name = "Saw"} }
    self.javaMock = ArrayListMock.new(self.rawTable)
end

function MerlinCollectionTests:TestItCanInstantiateFromLuaTable()
    local col = MerlinCollection:new(self.rawTable)
    self:assertEqual(2, #col:all())
    self:assertEqual("Axe", col:all()[1].name)
end

function MerlinCollectionTests:TestItCanInstantiateFromJavaArrayList()
    -- This triggers the ArrayList.wrap logic in your new MerlinCollection:new
    local col = MerlinCollection:new(self.javaMock)
    local data = col:all()
    
    -- Verify the Proxy is translating 1-based Lua to 0-based Java
    self:assertEqual(2, col:count(), "Count should match Java size")
    self:assertEqual("Axe", data[1].name, "Index 1 should map to Java 0")
    self:assertEqual("Saw", data[2].name, "Index 2 should map to Java 1")
end

function MerlinCollectionTests:TestContainsDetectsExistingItem()
    local col = MerlinCollection:new(self.rawTable)
    local target = self.rawTable[1]
    
    self:assertIsTrue(col:contains(target), "Should find item in Lua collection")
end

function MerlinCollectionTests:TestContainsWorksWithJavaProxy()
    local col = MerlinCollection:new(self.javaMock)
    local target = self.rawTable[2] -- The "Saw"
    
    self:assertIsTrue(col:contains(target), "Should find item via Proxy loop")
end

function MerlinCollectionTests:TestContainsReturnsFalseForMissingItem()
    local col = MerlinCollection:new(self.rawTable)
    self:assertIsTrue(not col:contains({name = "Hammer"}), "Should not find non-existent item")
end

MerlinCollectionTests:run()

return MerlinCollectionTests