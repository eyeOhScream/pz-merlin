local Merlin = require("Merlin")
local MerlinCollection = require("MerlinCollection")
local MerlinEvaluator = require("MerlinEvaluator")

local function stressTestAttributes()
    local obj = Merlin:bridge({}, "StressTest")
    local iterations = 100000 -- 100k operations
    local start = os.clock()

    for i = 1, iterations do
        -- Stresses: Merlin:set -> _attributes assignment -> __newindex -> isDirty
        obj:set("key_" .. (i % 100), i)
        local _ = obj:get("key_" .. (i % 100))
    end

    local duration = os.clock() - start
    print(string.format("ATTRIBUTE STRESS: 100k set/get took %.4f seconds", duration))
end

local function stressTestCollectionChains()
    local rawData = {}
    for i = 1, 1000 do table.insert(rawData, {id = i, val = i % 10}) end
    
    local col = MerlinCollection:new(rawData)
    local start = os.clock()

    for _ = 1, 500 do
        -- Stresses: New table creation and iteration for each link
        local results = col:where("val", 5)
                           :filter(function(item) return item.id > 100 end)
                           :all()
    end

    local duration = os.clock() - start
    print(string.format("COLLECTION STRESS: 500 chains on 1k items took %.4f seconds", duration))
end

local function stressTestDirtyReset()
    local horde = {}
    for i = 1, 2000 do
        horde[i] = Merlin:bridge({id = i}, "Horde_"..i)
        horde[i]:set("moved", true) -- Set them all to dirty
    end

    local start = os.clock()
    for i = 1, 2000 do
        -- Accessing raw field vs. method performance
        horde[i]._isDirty = false 
    end
    local duration = os.clock() - start
    print(string.format("DIRTY RESET STRESS: 2k objects took %.4f seconds", duration))
end

local function testResolvePerformance()
    print("Running Test: Resolve Performance (Shallow vs Deep)")
    
    local deepObj = {
        stats = {
            xp = {
                strength = 100
            }
        }
    }
    
    local iterations = 1000
    
    -- TEST 1: Shallow Access (Should be near 0.000s)
    local start1 = os.clock()
    for i = 1, iterations do
        local _ = deepObj.stats -- Standard Lua
    end
    print(string.format("  - Shallow Access: %.4fs", os.clock() - start1))

    -- TEST 2: Current Merlin:resolve (Deep)
    -- This simulates what happened in your 1.6s stress test
    local start2 = os.clock()
    for i = 1, iterations do
        -- If Merlin:resolve is splitting strings here, this will spike
        local _ = MerlinEvaluator:resolve(deepObj, "stats.xp.strength")
    end
    print(string.format("  - Merlin:resolve (Deep): %.4fs", os.clock() - start2))
end

stressTestAttributes()
stressTestCollectionChains()
stressTestDirtyReset()
testResolvePerformance()