-- Wyrm - a tool language built on Lua

--[[
;; Wyrm is a Tcl that uses structured data, not just strings.q
;; this means that its both less powerful syntatically than Tcl, but is still very expressive.
;; my goal is to reduce the footguns of Tcl, while keeping the incredible extensibility of Tcl.

;; this is example Wyrm code

fun factorial {n} do
    if {[< n 2]} do 
        return 1
    else 
        return [ * n [factorial [- n 1 ] ]
    end
end

;; like Tcl '{' '}' quotes everything inside, so {n} becomes a quoted list with symbol 'n'.

var map {
    a b  
    y [z] ; in this case, '[' ']' will evaluate the command within
}

;; there are special symbols that map to one or more other symbols, 
;; these are reader commands and are evaluated in a pre pass and only on the token stream. 
;; 'do', 'end', 'else' are some examples of reader commands
;; after the reader commands run, the previous factorial code would be transformed into.

fun factorial {n} {
    if {[< n 2]} {
        return 1
    } else {
        return [ * n [factorial [- n 1 ] ]
    }
}

;; notice that 'else' expands into multiple symbols '}' 'else' '{'.
;; because Wyrm is more structured than Tcl, comments are actaul comments, strings are literal strings. 
;; string literals are considered a single token.
]]

-- Tokenizer
-- turns text into a list of tokens

local ReaderCommands = {
    ['do'] = function() return {'{'} end,
    ['end'] = function() return {'}'} end,
    ['else'] = function() return { '}', 'else', '{' } end,
}

local function tokenize(contents)
    local it, tokens = 1, {}

    local function chr()
        return contents:sub(it, it)
    end

    local function at_eof()
        return it > #contents
    end

    local function is_chr(xs)
        if type(xs) == 'string' then
            return chr() == xs
        end
        for i = 1, #xs do
            if xs[i] == chr() then
                return true
            end
        end
        return false
    end

    local function at_ws()
        return is_chr { ' ', '\t', '\r' }
    end

    local function skip_ws()
        while not at_eof() and at_ws() do
            it = it + 1
        end
    end
 
    while not at_eof() do
        skip_ws()
        if chr() == '\n' then
            table.insert(tokens, '\n')
            it = it + 1
            goto continue
        end
        if at_eof() then break end
        local start = it
        while not at_eof() and not at_ws() and chr() ~= '\n' do
            it = it + 1
        end
        table.insert(tokens, contents:sub(start, it - 1))
        ::continue::
    end

    local final_tokens = {}
    for i = 1, #tokens do
        local tok = tokens[i]
        if ReaderCommands[tok] then
            local ts = ReaderCommands[tok]()
            for t = 1, #ts do table.insert(final_tokens, ts[t]) end
        else
            table.insert(final_tokens, tok)
        end
    end

    return final_tokens
end

local function set_tag(tbl, tag)
    return setmetatable(tbl, { tag = tag })
end

local function get_tag(tbl)
    return (getmetatable(tbl ) or {}).tag
end

local function tag_is(tbl, check)
    return get_tag(tbl) == check
end

local function group(tokens)
    -- The tokenizer splits on whitespace only, so delimiters can be fused
    -- to adjacent text (e.g. "{n}" or "{[<" or "2]}").  Detach them first.
    local split = {}
    local is_delim = {
        ['{'] = true, ['}'] = true,
        ['['] = true, [']'] = true,
        ['('] = true, [')'] = true,
    }
    for _, tok in ipairs(tokens) do
        if tok == '\n' then
            table.insert(split, tok)
        else
            local buf = ""
            for i = 1, #tok do
                local c = tok:sub(i, i)
                if is_delim[c] then
                    if #buf > 0 then table.insert(split, buf); buf = "" end
                    table.insert(split, c)
                else
                    buf = buf .. c
                end
            end
            if #buf > 0 then table.insert(split, buf) end
        end
    end

    local pos = 1

    -- opener -> closer, closer -> opener, opener -> tag
    local match_close = { ['{'] = '}',  ['['] = ']',  ['('] = ')' }
    local match_open  = { ['}'] = '{',  [']'] = '[',  [')'] = '(' }
    local tag_for     = { ['{'] = 'braces', ['['] = 'eval', ['('] = 'paren' }

    -- Parse a sequence of commands until `closer` is reached (or EOF at top level).
    -- Returns a plain list of commands; caller is responsible for tagging.
    local function parse(closer)
        local cmds = {}
        local cmd  = {}

        while pos <= #split do
            local tok = split[pos]

            -- Matched the closer we were looking for
            if tok == closer then
                pos = pos + 1
                if #cmd > 0 then table.insert(cmds, cmd) end
                return cmds
            end

            -- Any other closer here is a mismatch
            if match_open[tok] then
                error("group: unexpected '" .. tok .. "'" ..
                    (closer and (", expected '" .. closer .. "'") or ""))
            end

            if tok == '\n' then
                pos = pos + 1
                if #cmd > 0 then
                    table.insert(cmds, cmd)
                    cmd = {}
                end
            elseif match_close[tok] then
                -- Opening delimiter: recurse, tag the result, push as a word
                local opener = tok
                pos = pos + 1
                table.insert(cmd, set_tag(parse(match_close[opener]), tag_for[opener]))
            else
                -- Plain word
                pos = pos + 1
                table.insert(cmd, tok)
            end
        end

        -- Reached EOF
        if closer then
            error("group: unclosed '" .. match_open[closer] .. "'")
        end
        if #cmd > 0 then table.insert(cmds, cmd) end
        return cmds
    end

    return set_tag(parse(nil), "script")
end

local function read(code)
    local tokens = tokenize(code)
    local grouped = group(tokens)


    return grouped
end

local ast = read [[
    var hello 100
]]

return {
    tokenize = tokenize,
    group    = group,
    read     = read,
    set_tag  = set_tag,
    get_tag  = get_tag,
    tag_is   = tag_is,
}
