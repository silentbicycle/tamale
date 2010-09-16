require "tamale"
require "socket"                --for socket.gettime

DEF_CT = 10000

local fmt = string.format
local now = socket.gettime
local V = tamale.var

function init(mode)
   return tamale.matcher {
      { 27, "twenty-seven" },
      { "str", "string" },
      { { 1, 2, 3},
        function(t) return "one two three" end },
      { { 1, {2, "three"}, 4}, function(t) return "success" end },
      { { "gt3", V"X"}, function(t) return 10 * t.X end,
        where=function (t) return t.X > 3 end },
      { { V"a", V"b", V"c", V"b" }, function(t) return "ABCB" end },
      { { "a", {"b", V"X" }, "c", V"X"},
        function(t) return "X is " .. t.X end },
      { { "a", {"b", V"X" }, "c", V"Y"},
        function(t)
           local b = { "X is " }
           b[2] = t.X
           b[3] = " and Y is "
           b[4] = t.Y
           return table.concat(b)
        end },
      { { "extract", { V"_", V"_", V"third", V"_" } },
        function(t) return t.third end },
   }
end

function timed(name, f, ct)
   ct = ct or DEF_CT
   local cpre = os.clock()
   for i=1,ct do f() end
   local cpost = os.clock()
   local cdelta = cpost - cpre
   print(fmt("%25s: %d x: clock %d ms (%.3f ms per)",
             name, ct, cdelta * 1000, (cdelta * 1000) / ct))
end

M = init("search")

timed("init", function() local M = init("search") end)

timed("match-first-literal",
      function()
         local res = M(27)
         -- assert(res == "twenty-seven")
      end)

timed("match-structured-vars",
      function()
         local res = M { "a", {"b", "bananas"}, "c", "bananas" }
         -- assert(res == "X is bananas")
      end)

timed("match-structured",
      function()
         local res = M { "a", {"b", "bananas"}, "c", "garlic" }
         -- assert(res == "X is bananas and Y is garlic")
      end)

timed("match-abcb",
      function()
         local res = M { "a", "b", "c", "b" }
         -- assert(res == "ABCB")
      end)

timed("match-abcb-fail",
      function()
         local res = M { "a", "b", "c", "x" }
         -- should fail
         -- assert(res == false)
      end)
