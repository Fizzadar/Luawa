# Luawa Changelog

### 0.9.5

+ +changelog
+ format to use `(arg)` over `( arg )`
+ removed some unnecessary crap from `layout.sql`
+ removed `header.lua` and moved all functions to `request.lua`:
    - Access headers and cookies by `request.header.NAME` and `request.cookie.NAME`
    - `header:getHeaders` => `request:headers()`
    - `header:getCookies` => `request:cookies()`