# Luawa

Luawa (loo-ah-wa) is a web-application framework for [Lua+Nginx](https://github.com/openresty/lua-nginx-module).


## Requirements

+ Nginx w/Lua module
+ LuaJIT 2
+ Lua cjson


## Download

It is _highly_ recommended you use [a release](https://github.com/Fizzadar/Luawa/releases) rather than cloning this Git repo, which contains bleeding edge/untested code.


## Docs/etc

+ [Documentation](http://doc.luawa.com)
+ See [yummymarks](https://github.com/Fizzadar/yummymarks) for an example app
+ [Trello](https://trello.com/b/HghoF8U2/luawa) - backlog/pipeline/ideas


## Internals

Luawa consists of a number of (somewhat independent) 'modules'.

### Request processing

Luawa must be prepared with a configuration file using `luawa:setConfig(absolute_root, config_file_name)`. This can be called on every request (when caching is enabled it will only run the first time) or inside NginxLua's `init_by_lua`.

To process an incoming request `luawa:run()` is called, which takes a number of steps:

1. Prepare the request by reading the query string, POST data, cookies and headers
2. Work out which app file matches our request
3. Call the app file as a function within `pcall` to capture errors

### App files

When building Luawa I wanted to be able to create 'app files' as such:

    local template = luawa.template
    template:set('key', 'value')
    template:load('header')
    template:load('content')
    template:load('footer')

However to take advantage of NginxLua's code cache (essential for avoiding blocking io, race conditions and speed) these files have to be `required`. To achieve this Luawa wraps app & template files in a function, which is returned at the end of the file.

### Templates

Templates, like app files, are wrapped in a function after initial parsing. They allow you to inline Lua code alongside HTML.