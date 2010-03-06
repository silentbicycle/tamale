This is a library to add basic structural pattern matching (as in ML,
Prolog, Erlang, Haskell, etc.) to Lua.

For example, rather than writing a series of nested ifs to test
for a structure such as { "point", {x=3, y=-0.8, z=1.4} }, you can just
include the row
    { "point", {x=V"X", y=V"Y", z=V"Z"}, function_that_takes_captures }
in a series of match declarations (where V is a local alias to
*tamale.var*). The function would be passed a table with X, Y, and Z
keys and the numbers. Also, the capture table always includes the entire
matched pattern as t[1].

Each row can have an optional keyword argument of *where*=*f(cs)*. This
passes the captures to a function which returns whether those captures
are acceptacle (true/false). For example,
    { "email", V"address", where=valid_address(t) }
and valid_address checks if t.address is a valid e-mail address.
(Any errors during this function are treated as implicit failure.)

Finally, each variable can occur multiple times in the pattern. If the
values assigned to the same variable do not match, it will fail. For
example, { V"A", V"B", V"C", V"B" } would match both {1, 2, 3, 2} and
{"x", "y", "z", "y"}. Variables whose names begin with _ are ignored.

For further usage examples, see the test suite. Also, as this is a
technique imported from other, more declarative, languages, its real
potential may be learned quicker by studying them direcly.

Particularly recommended:

* _The Art of Prolog_ by Sterling & Shapiro
* _Programming Erlang_ by Joe Armstrong
