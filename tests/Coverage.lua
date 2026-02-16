-- Mostly AI written not gonna lie. I do plan to really comb through this later,
-- but I really wanted coverage without an outside library. There are plenty
-- of edge cases this will not catch, but as long as it covers my cases -
-- who cares.

---@TODO - Keep this in mind as a future feature: npx nodemon -e lua --exec "lua tests/MerlinTests.lua"

local debugInfo = debug.getinfo(1, "S") or {}

local Coverage = {
    data = {},
    ignored_source = debugInfo.source,
    colors = {
        reset = "\27[0m",
        red   = "\27[31m",
        green = "\27[32m",
        cyan  = "\27[36m",
        yellow = "\27[33m",
        bold  = "\27[1m"
    },
    config = {
        exclude = {
            ".vscode/",
            "tests/",
            "json.lua",
            "Coverage.lua",
            "lldebugger.lua",
            "aiTests.lua",
        }
    },
}

local skip_cache = {}

local function should_ignore(source)
    if skip_cache[source] ~= nil then return skip_cache[source] end

    -- 1. Clean the path: Remove '@', change '\' to '/' for consistency
    local clean_path = source:sub(2):gsub("\\", "/")
    
    -- 2. Check against exclude list
    for _, pattern in ipairs(Coverage.config.exclude) do
        -- Use string.find with plain=true, or use pattern matching
        -- If pattern is "tests/", it will now match "tests/MerlinTests.lua"
        if clean_path:find(pattern, 1, true) then 
            skip_cache[source] = true
            return true
        end
    end

    skip_cache[source] = false
    return false
end

local function is_executable(line)
    -- 1. Strip comments and whitespace
    line = line:gsub("%-%-.*$", "")
    local code = line:match("^%s*(.-)%s*$")
    if not code or code == "" then return false end
    
    -- 2. Logic to ignore table markers and delimiters
    ---@type table<string, boolean>
    local ignore_keywords = {
        ["end"] = true, ["else"] = true, ["do"] = true,
        ["repeat"] = true, ["{"] = true, ["}"] = true,
        ["},"] = true, ["};"] = true, [")"] = true, ["})"] = true,
    }
    
    if ignore_keywords[code] then return false end

    -- 3. Check for the function definitions as before
    local is_func_decl = code:match("^local%s+function") or 
                         code:match("^function%s+[%w%.%:]+%s*%(") or
                         code:match("[%w%.%:]+%s*=%s*function%s*%(")
    
    if is_func_decl then return false end

    return true
end

local function hook(event, line)
    local info = debug.getinfo(2, "S") or {}
    local src = info.source

    -- 1. Ignore if no source or if it's a C-function
    if not src or src:sub(1,1) ~= "@" then return end
    
    -- print("Tracking: " .. src)

    -- 2. Fast-path: Check our cached exclusions
    if should_ignore(src) then return end
    
    -- 3. Record the hit
    Coverage.data[src] = Coverage.data[src] or {}
    Coverage.data[src][line] = (Coverage.data[src][line] or 0) + 1
end

function Coverage:start()
    debug.sethook(hook, "l")
end

function Coverage:stop()
    ---@diagnostic disable-next-line: missing-parameter
    debug.sethook()
end

function Coverage:report()
    -- 1. Generate LCOV for VS Code
    local lcov = io.open("lcov.info", "w")

    if lcov == nil then return end
    
    -- 2. Prepare Terminal Summary
    print("\n" .. self.colors.bold .. self.colors.cyan .. "LUA COVERAGE REPORT" .. self.colors.reset)
    print(string.format("%-40s | %-10s", "File", "Coverage"))
    print(string.rep("-", 55))

    for source, tracked in pairs(self.data) do
        local path = source:sub(2)
        local total, hit = 0, 0
        
        local f = io.open(path, "r")
        if f then
            lcov:write("SF:" .. path .. "\n")
            local ln = 1
            for line in f:lines() do
                if is_executable(line) then
                    total = total + 1
                    local count = tracked[ln] or 0
                    if count > 0 then hit = hit + 1 end
                    lcov:write("DA:" .. ln .. "," .. count .. "\n")
                end
                ln = ln + 1
            end
            f:close()
            lcov:write("end_of_record\n")

            local pct = (total > 0) and (hit / total * 100) or 100
            local color = pct < 75 and self.colors.red or (pct < 90 and self.colors.yellow or self.colors.green)
            print(string.format("%-40s | %s%6.1f%%%s", path:sub(-40), color, pct, self.colors.reset))
        end
    end
    lcov:close()
end

return Coverage