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

_G.lua_tostring = tostring

local _lua_keywords = {
    ["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true, ["elseif"]=true,
    ["end"]=true, ["false"]=true, ["for"]=true, ["function"]=true, ["goto"]=true,
    ["if"]=true, ["in"]=true, ["local"]=true, ["nil"]=true, ["not"]=true,
    ["or"]=true, ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
    ["until"]=true, ["while"]=true,
}

local function is_identifier(s)
    return type(s) == "string"
        and s:match("^[%a_][%w_]*$")
        and not _lua_keywords[s]
end

function tostring(value)
   local function _tostring(value, seen, depth)
        if type(value) == "string" then
            return string.format("%q", value)
        end
        if type(value) ~= "table" then
            return _G.lua_tostring(value)
        end
        seen = seen or {}
        depth = depth or 0
        if seen[value] then
            return seen[value]
        end
        seen[value] = "{...}"
        local tag = (getmetatable(value) or {}).tag
        local indent      = string.rep("  ", depth)
        local inner_indent = string.rep("  ", depth + 1)
        local n = #value
        local total = 0
        for _ in pairs(value) do total = total + 1 end
        local is_array = (total == n)

        local lines = { "{" }
        if tag then
            table.insert(lines, inner_indent .. "_tag = " .. string.format("%q", tag) .. ",")
        end
        if is_array then
            for i = 1, n do
                table.insert(lines, inner_indent .. _tostring(value[i], seen, depth + 1) .. ",")
            end
        else
            local keys = {}
            for k in pairs(value) do table.insert(keys, k) end
            table.sort(keys, function(a, b)
                if type(a) == type(b) then return a < b end
                return type(a) < type(b)
            end)
            for _, k in ipairs(keys) do
                local key_str = is_identifier(k)
                    and k
                    or  "[" .. _tostring(k, seen, depth + 1) .. "]"
                table.insert(lines, inner_indent .. key_str .. " = " .. _tostring(value[k], seen, depth + 1) .. ",")
            end
        end
        table.insert(lines, indent .. "}")
        local result = table.concat(lines, "\n")
        seen[value] = result
        return result
   end
   return _tostring(value)
end

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
    return setmetatable(tbl, { tag = tag, __tostring = tostring })
end

local function get_tag(tbl)
    return (getmetatable(tbl) or {}).tag
end

local function tag_is(tbl, check)
    return get_tag(tbl) == check
end

local function group(tokens)
    local split = {}
    local is_delim = {
        ['{'] = true, ['}'] = true,
        ['['] = true, [']'] = true,
        ['('] = true, [')'] = true,
    }
    for _, tok in ipairs(tokens) do
        if tok == '\n' then
	   table.insert(split, tok)
        elseif type(tok) == 'number' then
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
    local match_close = { ['{'] = '}',  ['['] = ']',  ['('] = ')' }
    local match_open  = { ['}'] = '{',  [']'] = '[',  [')'] = '(' }
    local tag_for     = { ['{'] = 'script', ['['] = 'group', ['('] = 'paren' }

    local function parse(closer)
        local cmds = {}
        local cmd  = {}
        while pos <= #split do
            local tok = split[pos]
            if tok == closer then
                pos = pos + 1
                if #cmd > 0 then table.insert(cmds, cmd) end
                return cmds
            end
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
                local opener = tok
                pos = pos + 1
                local parsed = parse(match_close[opener])
                -- braces are blocks (list of commands); group/paren are single expressions
                if opener == '{' then
                    table.insert(cmd, set_tag(parsed, tag_for[opener]))
                else
                    table.insert(cmd, set_tag(parsed[1] or {}, tag_for[opener]))
                end
            else
                pos = pos + 1
                table.insert(cmd, tok)
            end
        end
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
   for i = 1, #tokens do
      local n = tonumber(tokens[i])
      if n ~= nil then
	 tokens[i] = n
      end
   end
   local grouped = group(tokens)
   return grouped
end

-- Note, this is a bootstrapping evaluator, only meant to allow evaluating the code generator
-- which is written in wyrm, and outputs 'lua' to be evaluated with ~load~.

local function next_env(env)
   return {
      parent = env,
      scope = {}
   }
end

local function env_get(env, key)
    if env.scope[key] ~= nil then
        return env.scope[key]
    end
    if env.parent ~= nil then
        return env_get(env.parent, key)
    end
    return nil
end

local function env_set(env, key, value)
   env.scope[key] = value
   return value
end

_G.env = {
   scope = {
      ['print'] = function(args)
	 io.write(tostring(args[2]))
	 io.write("\n")
	 return nil
      end,
      ['var'] = function(args, env)
	 env_set(env, args[2], args[3])
	 return nil
      end,
      ['fun'] = function(args, env)
	 -- args[3] is the params script {x y ...}, unwrap the single command to get the name list
	 -- args[4] is the body script, kept unevaluated
	 env_set(env, args[2], set_tag({ args[3][1], args[4] }, "fun"))
	 return nil
      end,
      ['+'] = function(args) return args[2] + args[3] end,
      ['*'] = function(args) return args[2] * args[3] end,
      ['/'] = function(args) return args[2] / args[3] end,
      ['-'] = function(args) return args[2] - args[3] end,
   }
}

local function apply(args, env, eval)
    if #args == 0 then
        return args
    end
    local cmd = env_get(env, args[1])
    if cmd == nil then
        return nil
    end
    if type(cmd) == "table" and tag_is(cmd, "fun") then
       env = next_env(env)
       local params = cmd[1]
       local body = cmd[2]
       for i = 2, #args do
	  env_set(env, params[i - 1], args[i])
       end
       return eval(body, env)
    end
    if type(cmd) == "function" then
       return cmd(args, env)
    end
end

local function evaluate(exp, env)
   assert(env)
   if tag_is(exp, "script") then
      local value = nil
      for i = 1, #exp do
	 value = evaluate(exp[i], env)
      end
      return value
   end
   if type(exp) == "string" and exp:sub(1, 1) == "$" then
      return env_get(env, exp:sub(2))
   end
   if type(exp) == "table" then
      -- Apply the arguments (including the command name)
      -- script-tagged tables are quoted: leave them unevaluated
      for i = 1, #exp do
	 if not tag_is(exp[i], "script") then
	    exp[i] = evaluate(exp[i], env)
	 end
      end

      return apply(exp, env, evaluate)
   end
   return exp
end

local ast = read [[
fun a {x} do
  var y [+ $x 1]
  + $x $y
end

a 10

]]

print(ast)
print(evaluate(ast, env))

return {
    tokenize = tokenize,
    group    = group,
    read     = read,
    set_tag  = set_tag,
    get_tag  = get_tag,
    tag_is   = tag_is,
}
