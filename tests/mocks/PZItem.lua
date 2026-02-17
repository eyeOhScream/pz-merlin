local PZItem = {}
PZItem.__index = PZItem

function PZItem.new(data)
    local self = setmetatable(data or {}, PZItem)
    -- Add a Java-style getter
    self.getType = function() return self.type end
    return self
end

return PZItem