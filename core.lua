--define lua-wa
luawa = {
    modules = { 'user', 'debug', 'admin', 'template', 'database', 'utils', 'header' }, --all our modules
    gets = {},
    posts = {},
    status_codes = {
        --2xx
        _200 = 'OK',
        --3xx
        _301 = 'Moved Permanently',
        --4xx
        _400 = 'Bad Request',
        _404 = 'Not Found',
        --5xx
        _500 = 'Internal Server Error'
    },
    request = {}
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
        self.gets[v.path] = { file = v.file, data = {} }
        for a, b in ipairs( v ) do
            self.gets[v.path].data[a] = b
        end
    end
    for k, v in pairs( config.posts ) do
        self.posts[v.path] = { file = v.file, data = {} }
        for a, b in ipairs( v ) do
            self.posts[v.path].data[a] = b
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
    self.request = request;

    --default response
    self.response = {
        status = 200,
        headers ={},
        content = ''
    }

    local file
    if request.method == 'GET' and self.gets[request.path] then
        file = self.gets[request.path].file .. '.lua'
    elseif request.method == 'POST' and self.posts[request.path] then
        file = self.posts[request.path].file .. '.lua'
    else
        --invalid request
        return self:error( 500, 'Invalid Request: ' .. request.path )
    end

    --try to open the file
    local f, err = io.open( file, 'r' )
    if not f then return self:error( 500, 'Cant find/open file: ' .. err ) end
    --read the file
    local s, err = f:read( '*all' )
    if not s then return self:error( 500, 'File read error: ' .. err ) end

    --compile the string
    local func = assert( loadstring( s ) )

    --nil function/no file?
    if func then
        --add self to global env - luawa is nil inside itself?
        local env = {}
        _G['luawa'] = self
        --attach metatable to table & set env
        setmetatable( env, { __index = _G } )
        setfenv( func, env )

        --result
        local status, err = pcall( func, self )

        --problem?
        if not status then
            self:error( 'Request: ' .. request.path .. ' / Error: ' .. err )
        end
    else
        self:error( 500, 'Problem with the request: ' .. request.path )
    end
end

--display an error page
function luawa:error( type, message )
    self.response.status = type
    self.response.content = message

    self.debug:error( 'Status: ' .. type .. ' / message: ' .. tostring( message ) )
end