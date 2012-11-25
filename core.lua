--define lua-wa
luawa = {
    modules = { 'user', 'debug', 'admin', 'template', 'database', 'utils', 'cookie' }, --all our modules
    gets = {},
    posts = {},
    database = {},
    headers_in = {},
    headers_out = {},
    content_out = '',
    status_codes = {
        --2xx
        _200 = 'OK',
        --3xx
        _301 = 'Moved',
        --4xx
        _404 = 'Not Found',
        --5xx
        _501 = 'Server Error'
    }
}

--include server
require( 'lua-wa/server' )

--include files
for k, v in pairs( luawa.modules ) do
    require( 'lua-wa/' .. v )
end

--start luawa app
function luawa:start()
    --start the server
    luawa.debug:message( 'Starting Server...' )
    if luawa_server:start() then
        --start server loop
        luawa_server:loop()
    else
        luawa.debug:error( 'Failed to start server' )
    end
end

--set the config
function luawa:setConfig( config )
    if not config.gets or not config.posts or not config.server then
        luawa.debug:error( 'No gets or posts, no point running server' )
        return false
    end

    --loop through gets & posts, convert to correct format luawa.gets|posts[path]=info
    for k, v in pairs( config.gets ) do
        self.gets[v.path] = { v.file, {} }
        for a, b in ipairs( v ) do
            self.gets[v.path][2][a] = b
        end
    end
    for k, v in pairs( config.posts ) do
        self.posts[v.path] = { v.file, {} }
        for a, b in ipairs( v ) do
            self.posts[v.path][2][a] = b
        end
    end

    --server config
    luawa_server.config = config.server

    --module config
    for k, v in pairs( self.modules ) do
        if config[v] then
            luawa[v].config = config[v]
        end
    end

    return true
end

--process a request from the server
function luawa:processRequest( request )
    local response = {
        status = 200,
        headers = {},
        content = '<strong>hi there baw</strong>'
    }
    response.headers['Content-Type'] = 'text/html'

    return response
end

--run a get request
function luawa:get( request, input )
end

--run a post request
function luawa:post( request, input )
end

--display an error page
function luawa:error( type, message )
end