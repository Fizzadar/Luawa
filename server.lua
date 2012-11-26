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
local request = function( fd, luawa )
    --setup our client
    require( 'socket' )
    local client = socket.tcp( fd )
    client:settimeout( 5 )

    --url parsing
    local url = require( 'socket.url' )

    --variables we want to fill from the incoming request
    local request = {
        version,
        method,
        path,
        get = {},
        post = {},
        hostname,
        cookie = {},
        user_agent,
        user_ip = client:getpeername()
    }

    --receive input until we get a blank line (or 50 lines - prevent 'overloading')
    local count = 0
    local line
    repeat
        --get one line & increase counter
        line = client:receive( '*l' )
        count = count + 1

        --first line should be our request, split into 3
        if count == 1 then
            local req_bits = luawa.utils.explode( line, ' ' )
            req_bits[2], req_bits[3] = req_bits[2] or '', req_bits[3] or ''
            request.version, request.method = luawa.utils.explode( req_bits[3], '/' )[2] or '0.9', req_bits[1] or 'UKNOWN'

            --not POST or GET? break here
            if request.method ~= 'GET' and request.method ~= 'POST' then
                break
            end

            --path & query
            local url_bits = url.parse( req_bits[2] ) or {}
            request.path = url_bits.path or '/'
            --query bits
            if url_bits.query then
                for k, v in pairs( luawa.utils.explode( url_bits.query, '&' ) ) do
                    local query_bits = luawa.utils.explode( v, '=', 1 )
                    query_bits[2] = query_bits[2] or true
                    request.get[query_bits[1]] = query_bits[2]
                end
            end
        --rest of the lines split two (header name => value)
        else
            local head_bits = luawa.utils.explode( line, ' ', 1 )
            head_bits[1], head_bits[2] = head_bits[1] or '', head_bits[2] or ''

            --user agent?
            if head_bits[1] == 'User-Agent:' then
                request.user_agent = head_bits[2]
            end

            --hostname
            if head_bits[1] == 'Host:' then
                request.hostname = head_bits[2]
            end

            --cookies
            if head_bits[1] == 'Cookie:' then
                local cookies = luawa.utils.explode( head_bits[2], '; ' )
                for k, v in pairs( cookies ) do
                    local cookie_bits = luawa.utils.explode( v, '=' )
                    cookie_bits[1], cookie_bits[2] = cookie_bits[1] or '', cookie_bits[2] or ''
                    request.cookie[cookie_bits[1]] = cookie_bits[2]
                end
            end
        end
    until line == nil or line == '' or count >= 50

    --feed our request to luawa, get our response
    local response = luawa:processRequest( request )
    response.status, response.headers, response.content = response.status or 200, response.headers or {}, response.content or ''

    --send headers to client
    client:send( 'HTTP/' .. request.version .. ' ' .. tostring( response.status ) .. ' ' .. luawa.status_codes['_' .. response.status] .. "\n" )
    for k, v in pairs( response.headers ) do
        client:send( k .. ': ' .. v .. "\n" )
    end
    client:send( "\n" )

    --send the content
    client:send( response.content )

    --close the connection
    client:close()

    return true
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
            table.insert( self.lanes, lanes.gen( 'base,math,package,string,table', request )( client, luawa ) )
        else
            --hacky sleep for 5ms
            socket.select( nil, nil, 0.005 )
        end

        --manage/cleanup lanes
        for k, v in pairs( self.lanes ) do
            --remove completed lanes
            if v.status == 'done' then
                local result = self.lanes[k][1] --we don't need it, but without lua-lanes *seems* to leak memory (10k requests ~= 400mb)
                self.lanes[k] = nil
            --remove & log error lanes
            elseif v.status =='error' then
                luawa.debug:error( 'Error in lane: ' .. tostring( v[1] ) )
                local result = self.lanes[k][1] --not needed, see above
                self.lanes[k] = nil
            end
        end

        --minute timer to touch file/check for stopfile?
    end

    luawa.debug:message( 'Server stopped' )
end