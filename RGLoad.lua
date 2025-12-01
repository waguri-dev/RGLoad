local RG = {}

if _ENV == nil then
    _ENV = _G
end

function RG.Def(name, value)
    _G[name] = value
end

function RG.Call(name, ...)
    local f = _G[name]
    if type(f) == "function" then
        pcall(f, ...)
    end
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function eval_value(s)
    s = trim(s)
    local long = s:match("^%[%[(.-)%]%]$")
    if long then return long end
    local str = s:match('^"(.-)"$')
    if str then return str end
    if s:match("^%$") then return _G[s:sub(2)] end
    if s == "true" then return true end
    if s == "false" then return false end
    if s:match("^%-?%d+$") or s:match("^%-?%d+%.%d+$") then
        return tonumber(s)
    end
    return s
end

local function eval_condition(cond)
    cond = trim(cond)
    local a, op, b = cond:match("^(.-)(==|~=|>=|<=|>|<)(.-)$")
    if a and op and b then
        local va = eval_value(trim(a))
        local vb = eval_value(trim(b))
        if op == "==" then return va == vb end
        if op == "~=" then return va ~= vb end
        if op == ">=" then return va >= vb end
        if op == "<=" then return va <= vb end
        if op == ">" then return va > vb end
        if op == "<" then return va < vb end
    else
        local val = eval_value(cond)
        return val and val ~= false
    end
end

local function split_first(line)
    local a, b = line:match("^(%S+)%s*(.*)$")
    return a, b
end

local function split_args(s)
    local args = {}
    for token in s:gmatch("%S+") do
        args[#args+1] = eval_value(token)
    end
    return table.unpack(args)
end

function RGLoad(code)
    local lines = {}
    for line in code:gmatch("[^\n]+") do
        lines[#lines + 1] = trim(line)
    end

    local function run_block(start_idx, end_idx)
        local i = start_idx
        while i <= end_idx do
            local line = lines[i]
            if line ~= "" then
                local cmd, rest = split_first(line)
                if cmd == "DEF" then
                    local name, val = rest:match("^(%S+)%s+(.+)$")
                    RG.Def(name, eval_value(val))
                elseif cmd == "CALL" then
                    local fname, args = rest:match("^(%S+)%s*(.*)$")
                    RG.Call(fname, split_args(args))
                elseif cmd == "IF" then
                    local j = i + 1
                    local matched = false
                    while j <= end_idx do
                        local l = lines[j]
                        local c, r = split_first(l)
                        if c == "ELSEIF" then
                            if not matched and eval_condition(r) then
                                run_block(j + 1, end_idx)
                                matched = true
                            end
                        elseif c == "ELSE" then
                            if not matched then
                                run_block(j + 1, end_idx)
                                matched = true
                            end
                        elseif c == "ENDIF" then
                            break
                        end
                        j = j + 1
                    end
                    i = j
                elseif cmd == "FOR" then
                    local var, startv, endv = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
                    startv = tonumber(startv) or 0
                    endv = tonumber(endv) or 0
                    local j = i + 1
                    local block_end = j
                    while block_end <= end_idx and lines[block_end] ~= "ENDFOR" do
                        block_end = block_end + 1
                    end
                    for v = startv, endv do
                        _G[var] = v
                        run_block(i + 1, block_end - 1)
                    end
                    i = block_end
                elseif cmd == "WHILE" then
                    local cond = rest
                    local j = i + 1
                    local block_end = j
                    while block_end <= end_idx and lines[block_end] ~= "ENDWHILE" do
                        block_end = block_end + 1
                    end
                    while eval_condition(cond) do
                        run_block(i + 1, block_end - 1)
                    end
                    i = block_end
                end
            end
            i = i + 1
        end
    end

    return function()
        run_block(1, #lines)
    end
end

return RG
