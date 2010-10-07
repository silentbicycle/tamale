require "tamale"
require "lunatest"

local V, P = tamale.var, tamale.P

local M

function setup(name)
   M = tamale.matcher {
      { 27, "twenty-seven" },
      { "str", "string" },
      { { 1, 2, 3},
        function(t) return "one two three" end },
      { { 1, {2, "three"}, 4}, function(t) return "success" end },
      { { "gt3", V"X"}, function(t) return 10 * t.X end,
        when=function (t) return t.X > 3 end },
      { { V"a", V"b", V"c", V"b" }, function(t) return "ABCB" end },
      { { "a", {"b", V"X" }, "c", V"X"},
        function(t) return "X is " .. t.X end },
      { { "extract", { V"_", V"_", V"third", V"_" } },
        function(t) return t.third end }
   }
end

function test_m()
   assert_true(M)
end

function test_literal_num()
   assert_equal("twenty-seven", M(27))
end

function test_literal_str()
   assert_equal("string", M "str")
end

function test_literal_num_trio()
   assert_equal("one two three", M {1, 2, 3})
end

function test_literal_num_trio_too_many()
   assert_false(M {1, 2, 3, 4})
end

function test_nomatch()
   assert_false(M {1, 2, 4})
end

function test_matchvar()
   assert_equal(70, M {"gt3", 7})
end

function test_matchvar_fail()
   assert_false(M {"gt3", "boo"})
end

function test_matchvar_nested()
   assert_equal("success", (M {1, {2, "three"}, 4}))
end

function test_match_repeated_num_var()
   assert_equal("ABCB", M {1, 2, 3, 2})
end

function test_match_repeated_str_var()
   assert_equal("ABCB", M {"apple", "banana", "corn", "banana"})
end

function test_match_repeated_table_var()
   local apple, banana, corn = {}, {}, {}
   assert_equal("ABCB", M {apple, banana, corn, banana})
end

function test_match_repeated_table_var_FAIL_out_of_order()
   local apple, banana, corn = {}, {}, {}
   assert_false(M {apple, corn, banana, banana})
end

function test_destructuring()
   assert_equal("X is FOO", M { "a", { "b", "FOO" }, "c", "FOO"})
end

function test_dont_care()
   assert_equal("third",
                M { "extract",
                  { "first", "second", "third", "fourth" }})
end

function test_match_any()
   local m = tamale.matcher {
      { V"_", function(t) return t end }
   }
   assert_true(m "any string", "match any string")
   assert_true(m(4), "match a number")
   assert_true(m {"x", "y", "z"}, "match a table")
end


--Match against three values that add up to 35, and use
--structural matching to check that the first and third are the same.
local aba_pt_match = tamale.matcher {
      { { x=V"X", y=V"Y", z=V"X" },
        function(t) return t.X + t.Y + t.X end }
   }

function test_kv_match()
   assert_equal(35, aba_pt_match {x=15, y=5, z=15 })
end

function test_kv_match_fail()
   assert_false(aba_pt_match {x=10, y=20, z=5 })
end


--Empty tables can also be used as sentinel values, so make it
--possibly to force comparison by identity rather than structure.
function test_match_IDs()
   local a, b, c = {}, {}, {}

   local m = tamale.matcher {
      { {a, b, c}, "PASS" },
      ids={a, b, c},
   }
   assert_equal("PASS", m {a, b, c})
   -- (b and c are equal by structure but not identity)
   assert_false(m {a, c, b})
end


function test_IDs_2()
   local a, b, c = {}, {}, {}
   local m = tamale.matcher {
      { {a, 1}, 1},
      { {b, 1}, 2},
      { {c, 1}, 3},
      ids={a, b, c},
   }
   assert_equal(1, m{a, 1}, "a")
   assert_equal(2, m{b, 1}, "b")
   assert_equal(3, m{c, 1}, "c")
end


--Result tables with variables in them should have their captures substituted.
function test_substitution()
   local m = tamale.matcher {
      { {x=V"x", y=V"y" }, {y=V"x", z=V"y" } },
      { {"swap", V"x", V"y" }, {V"y", V"x" } }
   }

   local res = m {x=10, y=20}
   assert_equal(10, res.y)
   assert_equal(20, res.z)
   local res2 = m { "swap", 10, 20 }
   assert_equal(20, res2[1])
   assert_equal(10, res2[2])
end


function test_substitution_var_only()
   local m = tamale.matcher {
      { V"all", V"all" }
   }

   for i=1,10 do assert_equal(i, m(i)) end 
   for i in ("bananas"):gmatch(".") do assert_equal(i, m(i)) end 
end


function test_substitution_boxing()
   local m = tamale.matcher {
      { V"all", { V"all" } }
   }

   for i=1,10 do
      local res = m(i)
      assert_equal(i, res[1])
   end 
end


-- Any extra arguments to the matcher are collected in captures.args.
function test_extra_matcher_arg()
   local m = tamale.matcher {
      { "sum", function(cap)
                  local total = 0
                  for i,v in ipairs(cap.args) do total = total + v end
                  return total
               end },
      { "sumlen", function(cap)
                     local total = 0
                     for i,v in ipairs(cap.args) do total = total + #v end
                     return total
                  end }
   }
   assert_equal(10, m("sum", 1, 2, 3, 4))
   assert_equal(15, m("sum", 1, 2, 3, 4, 5))
   assert_equal(10, m("sumlen", "a", "ao", "aoe", "aoeu"))
end

function test_match_order()
   local is_number = function(t) return type(t.X) == "number" end

   local m = tamale.matcher {
      { V"X", 1, when=is_number },
      { "y", 2 },
      { V"X", 3 },
      { "z", 4 },
   }
   assert_equal(1, m(23))
   assert_equal(2, m"y")
   assert_equal(3, m"z", [[should be shadowed by V"X"]])
   assert_equal(3, m"w")
end

-- Strings, even those w/ pattern chars, should be compared
-- literally unless passed in via a comparison function.
function test_str_literal_cmp()
   local m = tamale.matcher {
      { "foo (%d+)", function(t) return tonumber(t[1]) end },
      { "foo 23", 1 },
   }
   assert_equal(1, m"foo 23")
end


function test_str_pattern()
   local m = tamale.matcher {
      { P"foo (%d+)", function(t) return tonumber(t[1]) end },
      { P"foo (%a+)$", function(t) return t[1] end },
      { P"foo (%a+) (%d+) (%a+)",
        function(t) return t[1] .. tostring(t[2]) .. t[3] end
      },
      { "foo", 3 },
      { "bar", 4 },
   }
   assert_equal(23, m"foo 23")
   assert_equal("bar", m"foo bar")
   assert_equal(3, m"foo")
   assert_equal(4, m"bar")
end

-- Should not match string patterns when passed as literal strings
function test_table_str_literal_cmp()
   local m = tamale.matcher {
      { {"foo (%d+)"}, function(t) return tonumber(t[1]) end }, --fails
      { {"foo 23"}, 1 },
   }
   assert_equal(1, m{"foo 23"})
end

-- If a function pattern returns false or nil, it fails, otherwise it
-- succeeds and its results are captured.
function test_function_matching_behavior()
   local m = tamale.matcher {
      { function() end, 1 },    --always fails
      { function() return false end, 2 }, --always fails
      { P"foo (%d+)", function(t) return tonumber(t[1]) - 20 end },
      { function() return 1, 2, 3 end, --always succeeds
        function(t) return t[1] + t[2] + t[3] end },
   }

   assert_equal(3, m("foo 23"))
   assert_equal(6, m(""))
end

function test_table_str_pattern()
   local m = tamale.matcher {
      { {P"foo (%d+)"}, function(t) return tonumber(t[1]) end },
      { {P"foo (%a+)$"}, function(t) return t[1] end },
      { {P"foo (%a+) (%d+) (%a+)"},
        function(t) return t[1] .. tostring(t[2]) .. t[3] end
      },
      { {"foo"}, 3 },
      { {"bar"}, 4 },
   }
   assert_equal(23, m{"foo 23"})
   assert_equal("bar", m{"foo bar"})
   assert_equal("bar23baz", m{"foo bar 23 baz"})
   assert_equal(3, m{"foo"})
   assert_equal(4, m{"bar"})
end

-- By default, the presence of extra keys should block matching.
-- (This can be disabled with the partial=true flag on a row.)
function test_extra_keys()
   local m = tamale.matcher {
      { { k=1, v=2}, 3 },
      { { k=1, v=2, e=3}, 4 },
      { { 1, k=1, v=2 }, 5 },
   }
   assert_equal(3, m{k=1, v=2})
   assert_equal(4, m{k=1, v=2, e=3},
                "should not silently ignore extra e=3")
   assert_equal(5, m{1, k=1, v=2})
end

-- Test that partial row matches work: match against anything
-- that has a tag of "foo", and return the sum of its numeric fields.
function test_partial()
   local function sum_fields(env)
      local tot = 0
      for k,v in pairs(env.input) do
         if type(v) == "number" then tot = tot + v end
      end
      return tot
   end
   local m = tamale.matcher {
      { { tag="foo" }, sum_fields, partial=true },
      { V"_", false },
   }
   assert_equal(12, m{tag="foo", x=3, y=4, z=5})
end

-- A variable named "..." captures all of the remaining array-portion fields.
function test_vararg()
   local function sum_fields(env)
      local tot = 0
      for _,v in ipairs(env['...']) do
         if type(v) == "number" then tot = tot + v end
      end
      return tot
   end

   local m = tamale.matcher {
      { { "foo", V"..." }, sum_fields },
      { V"_", "nope" },
   }
   assert_equal(15, m{ "foo", 1, 2, 3, 4, 5})
end

function test_approx()
   local function approx(a)
      return function(b) return math.abs(a-b) < 1 end
   end
   local m = tamale.matcher {
      { {approx(5), approx(10)}, true }
   }
   assert_true(m {5.1, 10.1})
   assert_false(m {5.1, 11.1})
end

function test_default_case()
   local m = tamale.matcher {
      { 1, 1 },
      -- this one should fail, 2 -> 4 instead.
      -- make sure the V"_" row is in the index.
      { 2, 2, when=function(t) return false end },
      { V"_", 4 },
   }
   assert_equal(1, m(1))
   assert_equal(4, m(2))
   assert_equal(4, m(5))
end

-- Translated pattern-matching example from "Learn You Some Erlang for Great Good!"
-- Also: Regression test. Final default case of V"_" wasn't indexing correctly
-- against tables, so guards made them fail.
function test_LYSEFGG_beach()

   local function between(key, x, y)
      return function(cs)
                local v = cs[key]
                return v >= x and v <= y
             end
   end
   
   local beach = tamale.matcher {
      { {"celsius", V"N"}, when=between("N", 20, 45),
        "favorable" },
      { {"kelvin", V"N"}, when=between("N", 293, 318),
        "scientifically favorable" },
      { {"fahrenheit", V"N"}, when=between("N", 68, 113),
        "favorable in the US" },
      { V"_", "avoid beach" },
   }
   
   assert_equal("favorable", beach{"celsius", 23})
   assert_equal("avoid beach", beach{"kelvin", 23})
   assert_equal("favorable in the US", beach{"fahrenheit", 97})
   assert_equal("avoid beach", beach{"fahrenheit", -5})
end

-- Test indexing by a different field than t[1].
function test_custom_index()
   local m = tamale.matcher {
      { {1, "a"}, 1},
      { {1, "b"}, 2},
      { {1, "c"}, 3},
      { {1, "d"}, 4},
      index=2,
   }

   assert_equal(1, m{1, "a"}, "a")
   assert_equal(2, m{1, "b"}, "b")
   assert_equal(3, m{1, "c"}, "c")
   assert_equal(4, m{1, "d"}, "d")
   assert_false(m{3, "b"})
end

-- Test indexing by a function.
function test_custom_index_function()
   local m = tamale.matcher {
      { {1, "a", 1}, 1},
      { {1, "b", 2}, 2},
      { {1, "c", 3}, 3},
      { {1, "d", 4}, 4},
      index=function(r) return r[1] + 3*r[3] end,
      -- debug=true
   }

   assert_equal(1, m{1, "a", 1}, "a")
   assert_equal(2, m{1, "b", 2}, "b")
   assert_equal(3, m{1, "c", 3}, "c")
   assert_equal(4, m{1, "d", 4}, "d")
   assert_false(m{1, "b", 1})
end


lunatest.run()
