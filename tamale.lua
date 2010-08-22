--[[
Copyright (c) 2010 Scott Vokes <vokes.s@gmail.com>
 
Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:
 
The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
--]]


-- Depenedencies
local assert, getmetatable, ipairs, pairs, pcall, setmetatable, type =
   assert, getmetatable, ipairs, pairs, pcall, setmetatable, type


---TAble-MAtching Lua Extension.
module("tamale")


local VAR = {}
local function is_var(t) return getmetatable(t) == VAR end
local function is_func(f) return type(f) == "function" end
local function ignore(key) return key:sub(1, 1) == "_" end


---Mark a string in a match pattern as a variable key.
-- (You probably want to alias this locally to something short.)
-- Any variables beginning with _ are ignored.
-- @usage { "extract", {var"_", var"_", var"third", var"_" } }
function var(name)
   assert(type(name) == "string", "Variable must be string")
   return setmetatable( { name=name, ignore=ignore(name) }, VAR)
end


---Default hook for match failure.
-- @param val The unmatched value.
function match_fail(val)
   return false, "Match failed", val
end


-- Structurally match val against a pattern, setting variables in the
-- pattern to the corresponding values in val, and recursively
-- unifying table fields
local function unify(pat, val, env, ids)
   local pt = type(pat)
   if pt == "table" then
      if is_var(pat) then
         local cur = env[pat.name]
         if cur and cur ~= val and not pat.ignore then return false end
         env[pat.name] = val
         return env
      end
      if type(val) ~= "table" or #pat ~= #val then return false end
      if ids[pat] and pat ~= val then --compare by pointer equality
         return false
      else
         for k,v in pairs(pat) do
            if not unify(v, val[k], env, ids) then return false end
         end
      end
      return env
   else                         --just compare as literals
      return pat == val and env or false
   end
end


local function do_res(res, u)
   if is_func(res) then return res(u) else return res, u end
end


---Return a matcher function for a given specification.
--@param spec A list of rows, where each row is of the form
--  { pattern, result, [where=capture_test_fun(cs)] }.<br>
--@usage spec.fail: The spec can have an optional function to
--  call when nothing matches. By default, match_fail is used.
--@usage spec.ids: An optional list of table values that should be
--  compared by identity, not structure. If any empty tables are
--  being used as a sentinel value (e.g. "MAGIC_ID = {}"), list
--  them here.
function matcher(spec)
   local ids = {}
   if spec.ids then
      for _,id in ipairs(spec.ids) do ids[id] = true end
   end
   return
   function (t)
      -- This just searches linearly. It may be worth indexing,
      -- etc. to speed up the search later.
      for i,row in ipairs(spec) do
         local pat, res, where = row[1], row[2], row.where
         local u = unify(pat, t, {}, ids)
         if u then
            u[1] = t         --whole matched value
            if where then
               local ok, val = pcall(where, u)
               if ok and val then return do_res(res, u) end
            else
               return do_res(res, u)
            end
         end
      end
      local fail = spec.fail or match_fail
      return fail(t)
   end         
end
