--[[
    file: core.lua
    desc: main luawa file
        most importantly takes http requests as a table and returns a response as a table
]]--
luawa = {
    config_file = 'config',
    modules = { 'user', 'debug', 'admin', 'template', 'database', 'utils', 'header' }, --all our modules
    gets = {},
    posts = {},
    --http status codes
    status_codes = {
        --2xx
        [200] = 'OK',
        --3xx
        [301] = 'Moved Permanently',
        --4xx
        [400] = 'Bad Request',
        [404] = 'Not Found',
        --5xx
        [500] = 'Internal Server Error'
    },
    --file extension to mime type
    file_types = {
        png = 'image/png',
        jpg = 'image/jpg',
        txt = 'text/plain',
        css = 'text/css'
    },
    request = {},
    response = {},
    cache = {
        app = {},
        template = {},
        static = {}
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
function luawa:setConfig( file )
    --check if file set, overwrite self value
    file = file or self.config_file
    self.config_file = file

    --load the file (must return)
    local config = dofile( file .. '.lua' )

    --check we have all we need
    if not config.gets or not config.posts or not config.server then
        self.debug:error( 'No gets or posts, no point running server' )
        return false
    end

    --loop through gets & posts, convert to correct format luawa.gets|posts[path]=info
    for k, v in pairs( config.gets ) do
        self.gets[v.path] = { file = v.file }
        if v.func then self.gets[v.path].func = v.func end
    end
    for k, v in pairs( config.posts ) do
        self.posts[v.path] = { file = v.file }
        if v.func then self.posts[v.path].func = v.func end
    end

    --dev mode?
    self.dev_mode = config.dev_mode or false

    --function caching?
    self.cache_app = config.cache_app or false

    --static serving?
    self.serve_static = config.serve_static or false
    self.cache_static = config.cache_static or false

    --server config (check as we're not always called w/ luawa_server)
    if luawa_server then
        for k, v in pairs( config.server ) do
            luawa_server.config[k] = v
        end
    end

    --module config
    for k, v in pairs( self.modules ) do
        if config[v] then
            if not self[v].config then self[v].config = {} end
            --set values
            for c, d in pairs( config[v] ) do
                self[v].config[c] = d
            end
        end
    end

    return true
end

--process a request from the server
function luawa:processRequest( request )
    --luawa dev mode: re-include all luawa modules each request to reload 'em
    if self.dev_mode then
        luawa = self
        for k, v in pairs( self.modules ) do
            dofile( 'lua-wa/' .. v .. '.lua' )
            self:setConfig()
        end
    end

    --set request & log
    self.request = request;
    self.debug:access( '', self.request )

    --default response
    self.response = {
        status = 200,
        headers ={
            ['Content-Type'] = 'text/html',
            ['Set-Cookie'] = {}
        },
        content = '',
        cache = {}
    }

    --modules break if not done
    _G.luawa = self

    --loop modules & run any start functions
    for k, v in pairs( self.modules ) do
        if self[v]._start then
            self[v]:_start()
        end
    end

    --find our response
    local res
    if request.method == 'GET' and self.gets[request.path] then
        res = self.gets[request.path]
    elseif request.method == 'POST' and self.posts[request.path] then
        res = self.posts[request.path]
    else
        --static serving?
        if self.serve_static then
            --remove any ..'s from our path
            request.path:gsub( '%.%.', '' )
            --work out extension
            local a, b, ext = request.path:find( '[^%.]%.([%w]+)' )
            if self.file_types[ext] then
                --cached static content?
                if self.cache_static and self.cache.static[request.path] then
                    --content, header, done!
                    self.response.content = self.cache.static[request.path]
                    self.header:setHeader( 'Content-Type', self.file_types[ext] )
                    --debug
                    self.debug:message( 'Content loaded from cache: ' .. request.path )
                    return
                else
                    --try to open file
                    local f, e = io.open( '.' .. request.path, 'r' )
                    if f then
                        --set content + content type
                        self.response.content = f:read( '*a' )
                        self.header:setHeader( 'Content-Type', self.file_types[ext] )
                        f:close()

                        --caching?
                        if self.cache_static then
                            table.insert( self.response.cache, { cache = 'static', key = request.path, value = self.response.content } )
                        end
                        return
                    end
                end
            end
        end

        --invalid request
        return self:error( 500, 'Invalid Request: ' .. request.path )
    end

    --set data
    local file = res.file .. '.lua'
    self.request.func = res.func

    --caching?
    local func, err
    if self.cache_app and self.cache.app[request.path] then
        func = self.cache.app[request.path]
        if not func then
            self.debug:error( 'Cache load failed on: ' .. file .. ', cached: ' .. tostring( self.cache.app[request.path] ) )
        else
            self.debug:message( 'App function loaded from cache: ' .. request.path )
        end
    end

    --function not set
    if not func then
        --try to open the file
        local f, e = io.open( file, 'r' )
        if not f then return self:error( 500, 'Cant find/open file: ' .. e ) end
        --read the file
        local s, e = f:read( '*a' )
        if not s then return self:error( 500, 'File read error: ' .. e ) end

        --close file
        f:close()
        
        --compile the string
        func, err = loadstring( s )

        --cache it if functions is valid & caching enabled
        if func and self.cache_app then
            --add cache functo file, server handles (sends to master via linda)
            table.insert( self.response.cache, { cache = 'app', key = request.path, value = func } )
        end
    end

    --nil function/no file?
    if func then
        --make new environment based of current
        local env = {}
        --set request
        _G.request = self.request
        --attach metatable to table & set env
        setmetatable( env, { __index = _G } )
        setfenv( func, env )

        --result
        local status, err = pcall( func )

        --problem?
        if not status then
            self:error( 500, 'Request: ' .. request.path .. ' / Error: ' .. err )
        end
    else
        self:error( 500, 'Problem with the request: ' .. request.path .. ' :: ' .. err )
    end

    --loop modules & run any end functions
    for k, v in pairs( self.modules ) do
        if self[v]._end then
            self[v]:_end()
        end
    end
end

--display an error page
function luawa:error( type, message )
    self.response.status = type
    self.response.content = message

    self.debug:error( 'Status: ' .. type .. ' / message: ' .. tostring( message ) )
end

--run a server command
function luawa:serverControl( code )
    self.response.server_control = code
end