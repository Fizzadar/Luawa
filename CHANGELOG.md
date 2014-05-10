# Luawa Changelog

### v0.9.5

+ [Breaking Change] removed `header.lua` and moved all functions to `request.lua`
+ [Breaking Change] `request[header|cookie|get|post]` are all immutable
+ [Breaking Change] `luawa:setConfig(root, config)` now takes a table as the second argument
+ format to use `(arg)` over `( arg )`
+ removed some unnecessary crap from `layout.sql`
+ slight tweaking of internal caching/variable names
+ Show errors on `luawa:error` when debug enabled
+ Support for `puts` and `deletes` tables in config alongside `get`, `post`
+ New debug logo (filled in hole)
+ Fix bug with bottom html margin when hidden


### v0.9.4

+ Init changelog