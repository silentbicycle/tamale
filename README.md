Tamale - a TAble MAtching Lua Extension

This is a Lua library to add basic structural pattern matching (as in
ML, Prolog, Erlang, Haskell, etc.).

In Lua terms: it takes a table of rules and returns a matcher function.
That function tests its input against each rule (via a rule iterator),
and the first rule that has a non-false result is the overall match
result. If it results in a function, that function is called with any
captures from the input.

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

Code structured as a series of rules (declarative programming) is easy
to reason about and maintain. Instead of writing a tangled series of
nested if / else if / else statements by hand, they can automatically be
generated from a table like this, and various implementation tricks
(such as indexing) can make the matching more efficient than linear
search.

For further usage examples, see the test suite. Also, since this style
of programming comes from more declarative languages, it may help to
study them direcly.

Particularly recommended:

* _The Art of Prolog_ by Leon Sterling & Ehud Shapiro
* _Programming Erlang_ by Joe Armstrong
