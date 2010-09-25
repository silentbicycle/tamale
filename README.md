This is a Lua library to add basic structural pattern matching (as in
ML, Prolog, Erlang, Haskell, etc.).

**Basic usage:**

    require "tamale"
    local V, P = tamale.var, tamale.P --for marking variables & string patterns
    local function is_number(t) return type(t.X) == "number" end
    local function handle_pair(t) return { t.X, t.Y } end

    -- this builds a match-and-dispatch function from the rule table
    local m = tamale.matcher {
        { V"X", 1, when=is_number },
        { "y", 2 },
        { P"num (%d+)",
            function(cs) return tonumber(cs[1]) end },
        { { "num", V"X" },
            function(cs) return cs.X end },
        { { "pair", { V"Tag", V"X" }, {V"Tag", V"Y" } },
            handle_pair },
        { { "swap", V"X", V"Y"},    { V"Y", V"X" } },
        { { V"_", V"_", V"X" },     { V"X"} },
        -- debug=true -- uncomment to show progress
    }
    m(23)               --> 1
    m("y")              --> 2
    m("num 55")         --> 55
    m({"num", 55})      --> 55
    m({"swap", 10, 20}) --> {20, 10}

    -- using the same variable names means the tags must match
    m({"pair", {"x", 1}, {"x", 2}})
        --> calls handle_pair({X=1, Y=2}), which returns {1, 2}

    -- variables starting with "_" are ignored
    m({1, 2, 3})        --> {3}

Code structured as a series of rules (declarative programming) is often
easy to reason about, maintain, etc. Instead of writing a tangled series
of nested if / else if / else statements by hand, they can automatically
be generated from a table like this.

The rules are tried in order, so more general rules will match before
later, more specific rules. Tamale indexes the pattern table by literal
values (strings, numbers, etc.) and the first value in tables (p[1]),
among other things, so many impossible tests are actually eliminated
upfront, when the matcher function is built.

For further usage examples, see the test suite. Also, as this is a
technique imported from other, more declarative, languages, its real
potential may be better understood by studying them direcly.

Particularly recommended:

* _The Art of Prolog_ by Leon Sterling & Ehud Shapiro
* _Programming Erlang_ by Joe Armstrong
