--get lanes & socket
require( 'socket' )
local lanes = require( 'lanes' ).configure()

--server
luawa_server = {
    server,
    lanes = {},
    config = {
        port = 1337,
        ip = '*',
        name = 'lua-wa'
    }
}

--process request lane function
local request = lanes.gen( 'base,math,package,string,table', function( fd, luawa )
    --setup our client
    require( 'socket' )
    local client = socket.tcp( fd )
    client:settimeout( 5 )

    --url parsing
    local url = require( 'socket.url' )

    --variables we want to fill from the incoming request
    local request = {
        method,
        path,
        hostname,
        cookies,
        user_agent,
        user_ip = client:getpeername()
    }

    --receive input until we get a blank line (or 50 lines - prevent 'overloading')
    local count = 0
    repeat
        --get one line & increase counter
        line = client:receive( '*l' )
        count = count + 1

        for k, v in pairs( luawa.utils.explode( line, ' ' ) ) do
            print( k .. ' ' .. v )
        end

    until line == nil or line == '' or count >= 50

    --send back response
    client:send( 'HTTP/1.1 200 OK' .. "\n" )
    client:send( "\n" )
    client:send( 'hi' )

    --close the connection
    client:close()

    for k, v in pairs( request ) do
        print( k .. ' ' .. v )
    end

    return true
end )

--start
function luawa_server:start()
    --spawn socket
    self.server = socket.tcp()
    --bind it & listen
    if not self.server:bind( self.config.ip, self.config.port ) or not self.server:listen() then
        luawa.debug:error( 'Could not bind to port #' .. tostring( self.config.port ) )
        return false
    end
    --set timeout
    self.server:settimeout( 0, 't' )

    return true
end

--loop
function luawa_server:loop()
    while true do
        --get/check for client connection incoming
        local client = self.server:acceptfd()
        if client then
            --create & add lane to our lanes table
            table.insert( self.lanes, request( client, luawa ) )
        else
            --hacky sleep for .001 second
            socket.select( nil, nil, 0.001 )
        end

        --manage/cleanup lanes
        for k, v in ipairs( self.lanes ) do
            --remove completed lanes
            if v.status == 'done' then
                self.lanes[k] = nil
            --remove & log error lanes
            elseif v.status =='error' then
                luawa.debug:error( 'Error in lane: ' .. tostring( v[1] ) )
                self.lanes[k] = nil
            end
        end

        --minute timer to touch file/check for stopfile?
    end

    luawa.debug:message( 'Server stopped' )
end