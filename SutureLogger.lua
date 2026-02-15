local SutureLogger = {}
SutureLogger.__index = SutureLogger


function SutureLogger.new(config)
    config = config or {}
    local self = setmetatable({}, SutureLogger)
    self.prefix = config.prefix or "Merlin"
    self.version = config.version or "0.0.0"
    self.debugMode = config.debug ~= false -- Default to true if not specified
    return self
end

function SutureLogger:_log(levelName, indentLevel, message, ...)
    local indent = string.rep(" ", indentLevel or 0)
    -- [Prefix Version LEVEL] format
    local header = string.format("[%s %s %s]", self.prefix, self.version, levelName)

    local status, formattedMsg = pcall(string.format, message, ...)
    
    if status then
        print(string.format("%s %s%s", header, indent, formattedMsg))
    else
        print(string.format("%s LOG ERROR: Invalid format string -> %s", header, message))
    end
end

function SutureLogger:typeError(method, parameter, expectedType, value, receivedTypeOverride)
    local receivedType = receivedTypeOverride or type(value)
    local message = string.format("%s expects %s to be %s but received `%s`.", method, parameter, expectedType, receivedType)

    return self:error(message)
end

function SutureLogger:info(message, ...) return self:_log("INFO", 0, message, ...) end
function SutureLogger:error(message, ...) return self:_log("ERROR", 0, message, ...) end
function SutureLogger:debug(message, ...) return self:_log("DEBUG", 0, message, ...) end

return SutureLogger