# Lua-wa

Lua-wa (Loo-ah-wa) is a web-application 'framework' for Lua. This includes a multi-threaded (lualanes) webserver, which works with HTTP GET & POST requests and otherwise be as minimal as possible; designed to be placed behind Apache/nginx/etc, but can run standalone and be configured to serve static content. All very experimental and built more for education than production.

## Requirements
The following Lua modules are required (I recommend using Luarocks to install):
+ Lua (5.1.5 tested) / LuaJIT 2
+ Lua Lanes
+ Lua cjson
+ LuaSocket-patch (https://github.com/Fizzadar/luasocket-patch)
+ Luasql-mysql (and/or luasql-postgres coming soon)

## Architecture/Request Flow
+ n lanes created upon startup
+ Server listens for connectons, which are passed to a linda message queue
+ Each lane waits for connections in the queue, when one is received the request is processed by the lane

## Caching
+ App files (gets/posts), template files and static content can be cached
+ Caching is done per-lane, so there's no guarantee of cached content until the number of requests > number of lanes
+ Caching is thus useless for persistent data between individual requests; memcache recommended
+ So, with all caching enabled the maximum RAM usage by the cache is = ( total static content + template functions + app functions ) * number of lanes

## Limitations
+ Only one 'app' per 'server', so to host multiple apps on one IP w/ port 80 nginx/apache will need to run in front with each app on its own port
+ Performance is not heavily tested yet (initial tests seem reasonable w/ caching enabled)

## License

               DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
                       Version 2, December 2004 
    
    Copyright (C) 2013 Nick Barrett <nick@oxygem.com>
    
    Everyone is permitted to copy and distribute verbatim or modified 
    copies of this license document, and changing it is allowed as long 
    as the name is changed. 
    
               DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
      TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION 
    
     0. You just DO WHAT THE FUCK YOU WANT TO.