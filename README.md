# Tamale - a TAble MAtching Lua Extension

## Overview

Tamale is a [Lua][] library for structural pattern matching - kind of like regular expressions for *arbitrary data structures*, not just strings. (Or [Sinatra][] for data structures, rather than URLs.)

[Lua]: http://lua.org
[Sinatra]: http://www.sinatrarb.com

`tamale.matcher` reads a *rule table* and produces a *matcher function*. The table should list `{pattern, result}` rules, which are structurally compared in order against the input. The matcher returns the result for the first successful rule, or `(nil, "Match failed")` if none match.

### Basic Usage

    require "tamale"
    local V = tamale.var
    local M = tamale.matcher {
       { {"foo", 1, {} },      "one" },
       { 10,                   function() return "two" end},
       { {"bar", 10, 100},     "three" },
       { {"baz", V"X" },       V"X" },    -- V"X" is a variable
       { {"add", V"X", V"Y"},  function(cs) return cs.X + cs.Y end },
    }
 
    print(M({"foo", 1, {}}))   --> "one"
    print(M(10))               --> "two"
    print(M({"bar", 10, 100})) --> "three"
    print(M({"baz", "four"}))  --> "four"
    print(M({"add", 2, 3})     --> 5
    print(M({"sub", 2, 3})     --> nil, "Match failed"

The result can be either a literal value (number, string, etc.), a
variable, a table, or a function. Functions are called with a table containing the original input and captures (if any); its result is returned. Variables in the result (standalone or in tables) are
replaced with their captures.


### Benefits of Pattern Matching

 + Declarative (AKA "data-driven") programming is easy to locally reason about, maintain, and debug.
 + Structures do not need to be manually unpacked - pattern variables automatically capture the value from their position in the input.
 + "It fits or it doesn't fit" - the contract that code is expected to follow is very clear.
 + Rule tables can be compiled down to search trees, which are potentially more efficient than long, nested if / switch statements. (Tamale currently does not do this, but could in the future without any change to its interface. Also, see Indexing below.)

Imperative code to rebalance red-black trees can get pretty hairy. With pattern matching, the list of transformations *is* the code. 

    -- create red & black tags and local pattern variables
    local R,B,a,x,b,y,c,z,d = "R", "B", V"a", V"x", V"b", V"y", V"c", V"z", V"d"
    local balanced = { R, { B, a, x, b }, y, { B, c, z, d } }
                                                                                                                                     
    balance = tamale.matcher {
       { {B, {R, {R, a, x, b}, y, c}, z, d},  balanced },
       { {B, {R, a, x, {R, b, y, c,}}, z, d}, balanced },
       { {B, a, x, {R, {R, b, y, c,}, z, d}}, balanced },
       { {B, a, x, {R, b, y, {R, c, z, d}}},  balanced },
       { V"body", V"body" },      -- default case, keep the same
    }

(Adapted from Chris Okasaki's _Purely Functional Data Structures_.)

The style of pattern matching used in Tamale is closest to [Erlang](http://erlang.org)'s. Since pattern-matching comes from declarative languages, it may help to study them directly.

Particularly recommended:

* _The Art of Prolog_ by Leon Sterling & Ehud Shapiro
* _Programming Erlang_ by Joe Armstrong


## Rules

Each rule has the form `{ *pattern*, *result*, [when=function] }`.

The pattern can be a literal value, table, or function. For tables, every field is checked against every field in the input (and those
fields may in turn contain literals, variables, tables, or functions).

Functions are called on the input's corresponding field. If the function's first result is non-false, the field is considered a match, and all results are appended to the capture table. (See below) If the function returns false or nil, the match was a failure.

`tamale.P` marks strings as patterns that should be compared with string.match (possibly returning captures), rather than as a string literal. Use it like `{ P"aaa(.*)bbb", result}`.

Its entire implementation is just 

    function P(str)
        return function(v)
            if type(v) == "string" then return string.match(v, str) end
        end
    end


Rules also have two optional keyword arguments:

### Extra Restrictions - `when=function(captures)`

This is used to add further restrictions to a rule, such as a rule that can only take strings *which are also valid e-mail addresses*. (The function is passed the captures table.)

    -- is_valid(cs) checks cs[1] 
    { P"(.*)", register_address, when=is_valid }


### Partial patterns - `partial=true`

This flag allows a table pattern to match an table input value which has *more fields that are listed in the pattern*.

    { {tag="leaf"}, some_fun, partial=true }

could match against *any* table that has the value t.tag == "leaf", regardless of any other fields.


## Variables and Captures

The patterns specified in Tamale rules can have variables, which capture the contents of that position in the input. To create a Tamale variable, use `tamale.var('x')` (which can potentially aliased as `V'x'`, if you're into the whole brevity thing).

Variable names can be any string, though any beginning with _ are ignored during matching (i.e., `{V"_", V"_", V"X", V"_" }` will capture the third value from any four-value array). Variable names are not required to be uppercase, it's just a convention from Prolog and Erlang.

Also, note that declaring local variables for frequently used Tamale variables can make rule tables cleaner. Compare

    local X, Y, Z = V"X", V"Y", V"Z"
    M = tamale.matcher {
       { {X, X},    1},   -- capitalization helps to keep
       { {X, Y},    2},   -- the Tamale vars distinct from
       { {X, Y, Z}, 3},   -- the Lua vars
    }

with

    M = tamale.matcher {
       { {V'X', V'X'},       1},
       { {V'X', V'Y'},       2},
       { {V'X', V'Y', V'Z'}, 3},
    }

The _ example above could be reduced to `{_, _, X, _}`.

Finally, when the same variable appears in multiple fields in a rule pattern, such as { X, Y, X }, each repeated field must structurally match its other occurrances. `{X, Y, X}` would match `{6, 1, 6}`, but not `{5, 1, 7}`.


## The Rule Table

The function `tamale.matcher` takes a rule table and returns a matcher function. The matcher function takes one or more arguments; the first is matched against the rule table, and any further arguments are saved in captures.args.

The rule table also takes a couple other options, which are described below.


## Identifiers - `ids={List, Of, IDs}`

Tamale defaults to structural comparison of tables, but sometimes  tables are used as identifiers, e.g. `SENTINEL = {}`. The rule table can have an optional argument of `ids={LIST, OF, IDS}`, for values that should still be compared by `==` rather than structure. (Otherwise, *all* such IDs would match each other, and any empty table.)


## Indexing - `index=field`

Indexing in Tamale is like indexing in relational databases - Rather than testing every single rule to find a match, only those in the index need to be tested. Often, this singlehandedly eliminates most of the rules. By default, the rules are indexed by the first value.

When the rule table

    tamale.matcher {
        { {1, "a"}, 1 },
        { {1, "b"}, 2 },
        { {1, "c"}, 3 },
        { {2, "d"}, 4 },
    }

is matched against {2, "d"}, it only needs one test if the rule table is indexed by the first field - the fourth rule is the only one starting with 2. To specify a different index than `pattern[1]`, give the rule table a keyword argument of `index=I`, where I is either another key (such as 2 or "tag"), or a function. If a function is used, each rule will be indexed by the result of applying the function to it.

For example, with the rule table

    tamale.matcher {
       { {"a", "b", 1}, 1 },   -- index "ab"
       { {"a", "c", 1}, 2 },   -- index "ac"
       { {"b", "a", 1}, 3 },   -- index "ba"
       { {"b", "c", 1}, 4 },   -- index "bc"
       index=function(rule) return rule[1] .. rule[2] end
    }

each rule will be indexed based on the first two fields concatenated, rather than just the first. An input value of {"a", "c", 1} would only
need to check the second row, not the first.

Indexing should never change the *results* of pattern matching, just make the matcher function do less searching. Note that an indexing function needs to be deterministic - indexing by (say) `os.time()` will produce weird results. An argument of `index=false` turns indexing off.


## Debugging - `debug=true`

Tamale has several debugging traces. They can be enabled either by spetting `tamale.DEBUG` to true, or adding `debug=true` as a keyword argument to a rule table.

Matching `{ "a", "c", 1 }` against

    tamale.matcher {
       { {"a", "b", 1}, 1 },
       { {"a", "c", 1}, 2 },
       { {"b", "a", 1}, 3 },
       { {"b", "c", 1}, 4 },
       index=function(rule) return rule[1] .. rule[2] end,
       debug = true
    }

will print

    * rule 1: indexing on index(t)=ab
    * rule 2: indexing on index(t)=ac
    * rule 3: indexing on index(t)=ba
    * rule 4: indexing on index(t)=bc
    -- Checking rules: 2
    -- Trying rule 2...matched
    2

This can be used to check whether indexing is effective, if one rule is pre-empting another, etc.
