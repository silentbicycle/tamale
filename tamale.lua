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
local concat, insert, sort = table.concat, table.insert, table.sort

local function trace(...) print(string.format(...)) end

---TAble-MAtching Lua Extension.
module("tamale")

VERSION = "1.2"

DEBUG = false                   --Set to true to enable traces.

local function sentinel(descr)
   return setmetatable({}, { __tostring=function() return descr end })
end

local VAR, NIL = sentinel("[var]"), sentinel("[nil]")
local function is_var(t) return getmetatable(t) == VAR end


---Mark a string in a match pattern as a variable key.
-- (You probably want to alias this locally to something short.)
-- Any variables beginning with _ are ignored.
-- @usage { "extract", {var"_", var"_", var"third", var"_" } }
function var(name)
   assert(type(name) == "string", "Variable must be string")
   local ignore = (name:sub(1, 1) == "_")
   return setmetatable( { name=name, ignore=ignore }, VAR)
end


---Default hook for match failure.
-- @param val The unmatched value.
function match_fail(val)
   return false, "Match failed", val
end


-- Key-weak cache for table counts, since #t only gives the
-- length of the array portion, and otherwise, values with extra
-- non-numeric keys can match rows that do not have them.
local counts = setmetatable({}, { __mode="k"})

local function get_count(t)
   local v = counts[t]
   if not v then
      v = 0
      for k in pairs(t) do v = v + 1 end
      counts[t] = v
   end
   return v
end


-- Structurally match val against a pattern, setting variables in the
-- pattern to the corresponding values in val, and recursively
-- unifying table fields. String patterns are matched against value
-- strings, adding any captures to the environment's array.
local function unify(pat, val, env, ids, has_pattern)
   local pt, vt = type(pat), type(val)
   if pt == "table" then
      if is_var(pat) then
         local cur = env[pat.name]
         if cur and cur ~= val and not pat.ignore then return false end
         env[pat.name] = val
         return env
      end
      local ct = get_count(pat)
      if type(val) ~= "table" or ct ~= get_count(val) then return false end
      if ids[pat] and pat ~= val then --compare by pointer equality
         return false
      else
         for k,v in pairs(pat) do
            if not unify(v, val[k], env, ids, has_pattern) then return false end
         end
      end
      return env
   elseif vt == "string" and has_pattern then
      local cs = { val:match(pat) }
      if #cs == 0 then return false end
      for _,c in ipairs(cs) do env[#env+1] = c end
      return env
   else                         --just compare as literals
      return pat == val and env or false
   end
end


-- Replace any variables in the result with their captures.
local function substituted(res, u)
   local r = {}
   if is_var(res) then return u[res.name] end
   for k,v in pairs(res) do
      if type(v) == "table" then
         if is_var(v) then r[k] = u[v.name] else r[k] = substituted(v, u) end
      else
         r[k] = v
      end
   end
   return r
end


-- Return (or execute) the result, substituting any vars present.
local function do_res(res, u, has_vars)
   local t = type(res)
   if t == "function" then
      return res(u)
   elseif t == "table" and has_vars then
      return substituted(res, u), u
   end
   return res, u
end


local function append(t, key, val)
   local arr = t[key] or {}
   arr[#arr+1] = val; t[key] = arr
end


local function has_vars(res)
   if type(res) ~= "table" then return false end
   if is_var(res) then return true end
   for k,v in pairs(res) do
      if type(v) == "table" then
         if is_var(v) or has_vars(v) then return true end
      end
   end
   return false
end


-- If the list of row IDs didn't exist when the var row was
-- indexed (and thus didn't get added), add it here.
local function prepend_vars(vars, lists)
   for i=#vars,1,-1 do
      for k,l in pairs(lists) do
         local vid = vars[i]
         if l[1] > vid then insert(l, 1, vid) end
      end
   end
end


-- Does a string contain any "magic" pattern chars?
local function is_pattern(s) return s:match("[][^$()%.*+-?]") end


-- Index each literal pattern and pattern table's first value (t[1]). 
-- Also, add insert patterns with vars or string patterns in the
-- appropriate place(s).
local function index_spec(spec)
   local ls, ts = {}, {}        --non-str literals and tables
   local ss, tss = {}, {}       --str literals and table strs
   local lvs, tvs = {}, {}      --single-value-vars, tables keyed by vars
   local sps, tsps = {}, {}     --str patterns, table key str patterns
   local vrs = {}               --rows with vars in the result
   -- rows w/ string patterns (where :match() should be used, not ==)
   local sprs = {}

   for id, row in ipairs(spec) do
      local pat, res = row[1], row[2]
      local pt = type(pat)
      if is_var(pat) then       --match anything
         lvs[#lvs+1] = id; tvs[#tvs+1] = id
         sps[#sps+1] = id; tsps[#tsps+1] = id
      elseif pt == "table" then
         local v = pat[1] or NIL
         if is_var(v) then    --vars go in every index
            for k in pairs(ts) do append(ts, k, id) end
            tvs[#tvs+1] = id; tsps[#tsps+1] = id
         elseif type(v) == "string" then
            append(tss, v, id)
            if is_pattern(v) then
               for k in pairs(tss) do
                  if k ~= v then append(tss, k, id) end
               end
               tsps[#tsps+1] = id; sprs[id] = true
            end
         else
            append(ts, v, id)
         end
      elseif pt == "string" then
         append(ss, pat, id)
         if is_pattern(pat) then
            for k in pairs(ss) do
               if k ~= pat then append(ss, k, id) end
            end
            sps[#sps+1] = id; sprs[id] = true
         end
      else
         append(ls, pat, id)
      end

      if has_vars(res) then vrs[id] = true end
   end

   prepend_vars(lvs, ls)
   prepend_vars(lvs, ss); prepend_vars(sps, ss)
   prepend_vars(tvs, ts)
   prepend_vars(tvs, tss); prepend_vars(tsps, tss)
   ls[VAR] = lvs; ss[VAR] = sps
   ts[VAR] = tvs; tss[VAR] = tsps
   return { ls=ls, ss=ss, ts=ts, tss=tss, vrs=vrs, sprs=sprs }
end


-- Get the appropriate list of rows to check (if any).
local function check_index(spec, t, idx)
   local tt = type(t)
   if tt == "table" then
      local key = t[1] or NIL
      if type(key) == "string" then
         local tss = idx.tss
         return tss[key] or tss[VAR]
      else
         local ts = idx.ts
         return ts[key] or ts[VAR]
      end
   elseif tt == "string" then
      local ss = idx.ss
      return ss[t] or ss[VAR]
   else
      local ls = idx.ls
      return ls[t] or ls[VAR]
   end
end


---Return a matcher function for a given specification. When the
-- function is called on one or more values, its first argument is
-- tested in order against every row that could possibly match it,
-- selecting the relevant result (if any) or returning the values
-- (false, "Match failed", val).
-- If the result is a function, it is called with an environment table
-- containing any variable or string pattern captures and any subsequent
-- arguments passed to the matcher function (in env.args).
--@param spec A list of rows, where each row is of the form
--  { pattern, result, [when=capture_test_fun(cs)] }. Each
--  table pattern is indexed by pattern[1].
--@usage spec.ids: An optional list of table values that should be
--  compared by identity, not structure. If any empty tables are
--  being used as a sentinel value (e.g. "MAGIC_ID = {}"), list
--  them here.
--@usage spec.debug: Turn on debugging traces for the matcher.
function matcher(spec)
   local debug = spec.debug or DEBUG
   local ids = {}
   if spec.ids then
      for _,id in ipairs(spec.ids) do ids[id] = true end
   end

   local idx = index_spec(spec)
   local vrs, sprs = idx.vrs, idx.sprs  --variable / str pattern rows

   return
   function (t, ...)
      local rows = check_index(spec, t, idx)
      if debug then
         trace(" -- Checking rows: %s", concat(rows, ", "))
      end

      for _,id in ipairs(rows) do
         local row = spec[id]
         local pat, res, when = row[1], row[2], row.when
         local args = { ... }

         local u = unify(pat, t, { args=args }, ids, sprs[id])
         if debug then
            trace("-- Trying row %d...%s", id, u and "matched" or "failed")
         end
         
         if u then
            u.input = t         --whole matched value
            if when then
               local ok, val = pcall(when, u)
               if debug then trace("-- Running when(captures) check...%s",
                                   ok and "matched" or "failed")
               end
               if ok and val then
                  return do_res(res, u, vrs[id])
               end
            else
               return do_res(res, u, vrs[id])
            end
         end
      end
      if debug then trace("-- Failed") end
      local fail = spec.fail or match_fail
      return fail(t)
   end         
end
