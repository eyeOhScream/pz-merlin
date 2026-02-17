local TestCase = require("tests.TestCase")
local ArrayList = require("Types.ArrayList")
local ArrayListMock = require("tests.mocks.ArrayListMock")
local MerlinCollection = require("MerlinCollection")

local MerlinCollectionTests = TestCase:new("MerlinCollectionTests")

function MerlinCollectionTests:setUp()
    local player1 = {
        getFullName = function() return "Player 1" end,
        getHealth = function() return 1.0 end
    }
    local player2 = {
        getFullName = function() return "Player 2" end,
        getHealth = function() return 0.5 end
    }

    self.pzPlayers = ArrayListMock.new({ player1, player2 })
end

MerlinCollectionTests:run()

return MerlinCollectionTests