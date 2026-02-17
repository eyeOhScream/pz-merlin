local ArrayListMock = {}
ArrayListMock.__index = ArrayListMock

function ArrayListMock.new(list)
    -- We store data in _data so 'pairs' sees nothing in the main table
    local instance = {
        secretData = list or {},
        size = ArrayListMock.size,
        get = ArrayListMock.get
    }
    return setmetatable(instance, ArrayListMock)
end

function ArrayListMock:size()
    return #self.secretData
end

function ArrayListMock:get(i)
    -- Java index 0 = Lua index 1
    return self.secretData[i + 1]
end

return ArrayListMock