local ArrayListMock = {}
ArrayListMock.__index = ArrayListMock

function ArrayListMock.new(list)
    local instance = {
        _data = list or {},
        -- Attach these directly so ArrayList.is() sees them immediately
        size = ArrayListMock.size,
        get = ArrayListMock.get
    }
    return setmetatable(instance, ArrayListMock)
end

function ArrayListMock:size()
    return #self._data
end

function ArrayListMock:get(i)
    -- Simulates Java 0-based indexing
    return self._data[i + 1]
end

return ArrayListMock