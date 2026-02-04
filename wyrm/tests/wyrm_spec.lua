local wyrm     = require "wyrm"
local tokenize = wyrm.tokenize
local read     = wyrm.read
local tag_is   = wyrm.tag_is

-- Recursive array comparison, ignoring metatables.
-- Tags are checked explicitly in tests via tag_is.
local function eq(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    if #a ~= #b then return false end
    for i = 1, #a do
        if not eq(a[i], b[i]) then return false end
    end
    return true
end

-- ---------------------------------------------------------------
-- tokenize
-- ---------------------------------------------------------------

describe("tokenize", function()
    it("splits words on spaces", function()
        assert(eq(tokenize("a b c"), {"a", "b", "c"}))
    end)

    it("treats tabs as whitespace", function()
        assert(eq(tokenize("a\tb\tc"), {"a", "b", "c"}))
    end)

    it("collapses multiple spaces", function()
        assert(eq(tokenize("a    b"), {"a", "b"}))
    end)

    it("skips leading whitespace", function()
        assert(eq(tokenize("   a b"), {"a", "b"}))
    end)

    it("emits newlines as tokens", function()
        assert(eq(tokenize("a\nb"), {"a", "\n", "b"}))
    end)

    it("trailing newline produces a newline token", function()
        assert(eq(tokenize("a\n"), {"a", "\n"}))
    end)

    it("consecutive newlines each produce a token", function()
        assert(eq(tokenize("a\n\nb"), {"a", "\n", "\n", "b"}))
    end)

    it("empty input produces empty list", function()
        assert(eq(tokenize(""), {}))
    end)

    it("whitespace-only input produces empty list", function()
        assert(eq(tokenize("   \t  "), {}))
    end)

    -- reader commands
    it("expands 'do' into '{'", function()
        assert(eq(tokenize("if x do"), {"if", "x", "{"}))
    end)

    it("expands 'end' into '}'", function()
        assert(eq(tokenize("stuff end"), {"stuff", "}"}))
    end)

    it("expands 'else' into '} else {'", function()
        assert(eq(tokenize("else"), {"}", "else", "{"}))
    end)

    it("does not expand reader commands that appear as substrings", function()
        assert(eq(tokenize("done endgame endo"), {"done", "endgame", "endo"}))
    end)

    -- tokenizer does NOT split on grouping chars -- that is group's job
    it("preserves grouping chars fused to text", function()
        assert(eq(tokenize("{n}"), {"{n}"}))
        assert(eq(tokenize("{[<"), {"{[<"}))
        assert(eq(tokenize("2]}"), {"2]}"}))
    end)
end)

-- ---------------------------------------------------------------
-- group  (tested through read = tokenize + group)
-- ---------------------------------------------------------------

describe("group", function()
    -- --- basic structure ---

    it("single command becomes one-element script", function()
        local ast = read "var hello 100"
        assert(tag_is(ast, "script"))
        assert(#ast == 1)
        assert(eq(ast[1], {"var", "hello", "100"}))
    end)

    it("newlines separate commands", function()
        local ast = read "a b\nc d"
        assert(#ast == 2)
        assert(eq(ast[1], {"a", "b"}))
        assert(eq(ast[2], {"c", "d"}))
    end)

    it("consecutive newlines do not produce empty commands", function()
        local ast = read "a\n\n\nb"
        assert(#ast == 2)
        assert(eq(ast[1], {"a"}))
        assert(eq(ast[2], {"b"}))
    end)

    it("empty input produces empty script", function()
        local ast = read ""
        assert(tag_is(ast, "script"))
        assert(#ast == 0)
    end)

    -- --- braces ---

    it("standalone braces become a braces-tagged group", function()
        local ast = read "x { a b }"
        local braces = ast[1][2]
        assert(tag_is(braces, "braces"))
        assert(#braces == 1)                -- one command inside
        assert(eq(braces[1], {"a", "b"}))
    end)

    it("fused braces {n} are split and grouped", function()
        local ast = read "x {n}"
        local braces = ast[1][2]
        assert(tag_is(braces, "braces"))
        assert(#braces == 1)
        assert(eq(braces[1], {"n"}))
    end)

    it("multiline body inside braces", function()
        local ast = read "fn {\n a 1\n b 2\n}"
        local body = ast[1][2]
        assert(tag_is(body, "braces"))
        assert(#body == 2)
        assert(eq(body[1], {"a", "1"}))
        assert(eq(body[2], {"b", "2"}))
    end)

    it("empty braces produce an empty braces group", function()
        local ast = read "x {}"
        local braces = ast[1][2]
        assert(tag_is(braces, "braces"))
        assert(#braces == 0)
    end)

    -- --- eval ---

    it("brackets become an eval-tagged group", function()
        local ast = read "x [+ 1 2]"
        local ev = ast[1][2]
        assert(tag_is(ev, "eval"))
        assert(#ev == 1)
        assert(eq(ev[1], {"+", "1", "2"}))
    end)

    it("fused brackets [cmd] are split and grouped", function()
        local ast = read "x [z]"
        local ev = ast[1][2]
        assert(tag_is(ev, "eval"))
        assert(eq(ev[1], {"z"}))
    end)

    -- --- parens ---

    it("parens become a paren-tagged group", function()
        local ast = read "x (+ 1 2)"
        local paren = ast[1][2]
        assert(tag_is(paren, "paren"))
        assert(eq(paren[1], {"+", "1", "2"}))
    end)

    -- --- nesting ---

    it("eval nested inside braces", function()
        -- {[< n 2]} is one token; split into { [ < n 2 ] }
        local ast = read "if {[< n 2]}"
        local braces = ast[1][2]
        assert(tag_is(braces, "braces"))
        local ev = braces[1][1]             -- first cmd, first word
        assert(tag_is(ev, "eval"))
        assert(eq(ev[1], {"<", "n", "2"}))
    end)

    it("eval nested inside eval", function()
        -- [factorial [- n 1]]
        local ast = read "x [factorial [- n 1]]"
        local outer = ast[1][2]
        assert(tag_is(outer, "eval"))
        assert(outer[1][1] == "factorial")
        local inner = outer[1][2]
        assert(tag_is(inner, "eval"))
        assert(eq(inner[1], {"-", "n", "1"}))
    end)

    it("three levels deep", function()
        local ast = read "x [a [b [c]]]"
        local l1 = ast[1][2]                -- eval: a ...
        assert(tag_is(l1, "eval"))
        local l2 = l1[1][2]                 -- eval: b ...
        assert(tag_is(l2, "eval"))
        local l3 = l2[1][2]                 -- eval: c
        assert(tag_is(l3, "eval"))
        assert(eq(l3[1], {"c"}))
    end)

    it("braces containing multiline with nested eval", function()
        local ast = read "fn {\n ret [+ x 1]\n}"
        local body = ast[1][2]
        assert(tag_is(body, "braces"))
        assert(#body == 1)
        assert(body[1][1] == "ret")
        local ev = body[1][2]
        assert(tag_is(ev, "eval"))
        assert(eq(ev[1], {"+", "x", "1"}))
    end)

    -- --- reader commands produce correct structure ---

    it("do/end produce braces around the body", function()
        local ast = read "fn do\n body\nend"
        local body = ast[1][2]
        assert(tag_is(body, "braces"))
        assert(eq(body[1], {"body"}))
    end)

    it("if/else/end produces the expected command shape", function()
        -- "if cond do\n a\n else\n b\n end"
        -- reader expands to: if cond { \n a \n } else { \n b \n }
        local ast = read "if cond do\n a\n else\n b\n end"
        local cmd = ast[1]
        assert(cmd[1] == "if")
        assert(cmd[2] == "cond")
        assert(tag_is(cmd[3], "braces"))    -- then-body
        assert(eq(cmd[3][1], {"a"}))
        assert(cmd[4] == "else")
        assert(tag_is(cmd[5], "braces"))    -- else-body
        assert(eq(cmd[5][1], {"b"}))
    end)

    -- --- error cases ---

    it("errors on mismatched closer", function()
        local ok, err = pcall(read, "{ a ]")
        assert(not ok)
        assert(err:match("unexpected '%]'"))
    end)

    it("errors on unclosed group", function()
        local ok, err = pcall(read, "{ a b")
        assert(not ok)
        assert(err:match("unclosed '%{'"))
    end)

    it("errors on stray closer at top level", function()
        local ok, err = pcall(read, "a }")
        assert(not ok)
        assert(err:match("unexpected '%}'"))
    end)
end)
