package = "tamale"
version = "1.2.2-1"
source = {
   url = "git://github.com/silentbicycle/tamale.git",
   tag = "v1.2.2"
}
description = {
   summary = "Erlang-style pattern matching for Lua",
   detailed = [[
Tamale adds structural pattern matching (as in Erlang, Prolog, etc.) to
Lua. Pattern matching unpacks and matches on data structures like
regular expressions do on strings.

Rather than writing a series of nested ifs to test and extract from
a structure, you can build a test function from a series of rules, and
it will generate a dispatch function (with variable captures, etc.).
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
