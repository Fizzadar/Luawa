--[[
    file: server.lua
    desc: luawa server
]]--

--get lanes & socket
require( 'socket' )
local lanes = require( 'lanes' ).configure()
local linda = lanes.linda()

--luajit hack for lanes, otherwise not found in transfer db when lane-ing
package.preload.ffi = function() end

--server
luawa_server = {
    server,
    stdin,
    lanes = {},
    config = {
        port = 1337,
        ip = '*',
        name = 'lua-wa',
        lanes = 30
    }
}

--process request lane function
local lane = function( id, luawa )
    print( 'Lane #' .. id .. ' started' )

    --setup our socket & url modules
    require( 'socket' )
    local url = require( 'socket.url' )

    --loop
    while true do
        local k, fd = linda:receive( 60, 'client' )

        if fd then
            local client = socket.tcp( fd )
            --5s to send each line or too slow
            client:settimeout( 5 )

            --variables we want to fill from the incoming request
            local request = {
                version,
                method,
                path = '',
                get = {},
                post = {},
                hostname = '',
                cookie = {},
                user_agent,
                user_ip = client:getpeername(),
                referrer = ''
            }

            --receive input until we get a blank line (or 50 lines - prevent 'overloading')
            local count = 0
            local line
            repeat
                --get one line & increase counter
                line = client:receive( '*l' )
                count = count + 1

                --5 seconds time up!
                if not line then
                    break
                end

                --first line should be our request
                if count == 1 then
                    local a, b, uri
                    a, b, request.method, uri, request.version = line:find( '(%a+) ([^%s]+) HTTP/(%d%.%d)' )

                    --no match / not POST or GET? break here, unsupported; a for bad request
                    if a == nil or ( request.method ~= 'GET' and request.method ~= 'POST' ) then
                        break
                    end

                    --path & query
                    local url_bits = url.parse( uri ) or {}
                    request.path = url_bits.path or '/'
                    --query bits
                    if url_bits.query then
                        for k, v in url_bits.query:gmatch( '([^&=]+)=([^&=]+)' ) do
                            request.get[k] = v
                        end
                    end
                --rest of the lines split two (header name => value)
                else
                    local a, b, key, value = line:find( '([^%s]+): (.+)' )

                    --user agent?
                    if key == 'User-Agent' then
                        request.user_agent = value
                    end

                    --hostname
                    if key == 'Host' then
                        --catch/remove any port numbers
                        local a, b, host = value:find( '([%w%.]+):[%d]+' )
                        if not a then host = value end

                        request.hostname = host
                    end

                    --referrer (spelt CORRECTLY - original HTTP spec spelt it wrong - wtf?)
                    if key == 'Referer' then
                        request.referrer = value
                    end

                    --cookies
                    if key == 'Cookie' then
                        for k, v in value:gmatch( '([^;]+)' ) do
                            local a, b, c, d = k:find( '([^=]+)=([^=]+)')
                            request.cookie[luawa.utils:trim( c )] = d
                        end
                    end
                end
            until line == nil or line == '' or count >= 50

            --pass our request on to luawa
            luawa:processRequest( request )

            --get response from luawa
            local response = luawa.response
            response.version, response.status, response.headers, response.content = request.version or 0.9, response.status or 500, response.headers or {}, response.content or 'Internal Server Error'

            --set timeout to 10 for response
            client:settimeout( 10 )

            --send headers to client + sub-tables
            client:send( 'HTTP/' .. response.version .. ' ' .. response.status .. ' ' .. luawa.status_codes[response.status] .. "\n" )
            for k, v in pairs( response.headers ) do
                if type( v ) == 'table' then
                    for c, d in pairs( v ) do
                        client:send( c .. ': ' .. d .. "\n" )
                    end
                else
                    client:send( k .. ': ' .. v .. "\n" )
                end
            end
            client:send( "\n" )

            --send the content
            client:send( response.content )

            --close the connection (no support for keep-alive yet/ever?)
            client:close()

            --cache wanted? (0s timeout)
            if response.cache then
                for k, v in pairs( response.cache ) do
                    --cache directly in-lane
                    luawa.cache[v.cache][v.key] = v.value
                end
            end

            --finally run any server_control commands (high timeout)
            if response.server_control then
                linda:send( 10, 'server_control', response.server_control )
            end
        end --end if client
    end --end while loop
end

--start
function luawa_server:start()
    --spawn socket
    self.server = socket.tcp()
    --bind it & listen
    if not self.server:bind( self.config.ip, self.config.port ) or not self.server:listen() then
        luawa.debug:error( 'Could not bind to port #' .. tostring( self.config.port ) )
        return false
    end

    --setup lanes (so no overhead of loading per-request)
    for i = 1, self.config.lanes, 1 do
        table.insert( self.lanes, lanes.gen( '*', lane )( i, luawa ) )
    end

    --5s timeout
    self.server:settimeout( 5, 't' )

    return true
end

--server loop
function luawa_server:loop()
    --loop
    while true do
        --get/check for client connection incoming
        local client = self.server:acceptfd()

        --do we have a client
        if client then
            --send the client fd to linda
            if not linda:send( 0, 'client', client ) then
                luawa.debug:error( 'Problem sending client linda' )
            end
        end

        --get linda server_control command, non-blocking/0 timeout
        local k, command = linda:receive( 0, 'server_control' )
        if command then
            --shut down?
            if command == 'shutdown' then
                break
            --reload cache/config?
            elseif command == 'reload' then
                luawa.debug:message( 'Reloading...' )

                for k, v in pairs( luawa.cache ) do
                    luawa.cache[k] = {}
                end
                luawa.debug:message( 'Cache cleared' )

                luawa:setConfig()
                luawa.debug:message( 'Config reloaded' )
            --dump luawa debug
            elseif command == 'debug' then
                luawa.debug:message( 'Dump of luawa + luawa_server structure below:' .. luawa.utils:tableString( luawa ) .. luawa.utils:tableString( luawa_server ) )
            end
        end

        --loop our lanes, remove borked
        for k, v in pairs( self.lanes ) do
            if v.status == 'error' then
                luawa.debug:message( 'Lane error: ' .. tostring( self.lanes[k][1] ) )
                self.lanes[k] = nil
            end
        end

        --not enough lanes?
        if #self.lanes < self.config.lanes then
            for i = #self.lanes, self.config.lanes, 1 do
                table.insert( self.lanes, lanes.gen( '*', lane )( i, luawa ) )
            end
        end
    end --end server loop

    --stop server socket (socket doesn't seem to unbind properly still)
    self.server:close()
    self.server = nil
    luawa.debug:message( 'Server stopped' )
end