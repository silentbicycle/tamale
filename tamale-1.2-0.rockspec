package = "tamale"
version = "1.2-0"
source = {
   url = "git://github.com/silentbicycle/tamale.git",
   tag = "v1.2"
}
description = {
   summary = "Erlang-style pattern matching for Lua",
   detailed = [[
Tamale adds structural pattern matching (as in Erlang, Prolog, etc.) to
Lua. Rather than writing a series of nested ifs to test and extract from
a structure, you can just pass it examples of the structure, possibly
with variables, and it will generate an dispatch function.
]],
   homepage = "http://github.com/silentbicycle/tamale",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1"   --earlier may work but is untested
}
build = {
   type = "builtin",
   modules = {
      tamale = "tamale.lua"
   }           
}
