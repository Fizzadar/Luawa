-- File: core.lua
-- Desc: Luawa definition

local pairs = pairs
local require = require
local loadstring = loadstring
local pcall = pcall
local type = type
local tostring = tostring
local io = io
local ngx = ngx

local luawa = {
    version = '0.9.2',
    config_file = 'config',
    modules = { 'user', 'template', 'database', 'utils', 'header', 'email', 'session', 'debug' }, --all our modules
    response = '<!--the first request is always special-->',
    requests = 0
}

--set the config
function luawa:setConfig( dir, file )
    self.root_dir = dir or ''
    self.config_file = file or 'config'

    --load the config file (must return)
    local config = require( dir .. file )

    --include modules
    for k, v in pairs( luawa.modules ) do
        luawa[v] = require( dir .. 'luawa/' .. v )
    end

    --set get/post
    self.gets = config.gets or {}
    self.posts = config.posts or {}

    --hostname?
    self.hostname = config.hostname or ''

    --shared memory prefix
    self.shm_prefix = config.shm_prefix or ''

    --cache?
    self.cache = config.cache

    --limit post args?
    self.limit_post = config.limit_post or 100

    --module config
    for k, v in pairs( self.modules ) do
        if type( config[v] ) == 'table' then
            if not self[v].config then self[v].config = {} end
            --set values
            for c, d in pairs( config[v] ) do
                self[v].config[c] = d
            end
        end
    end

    return true
end

--run luawa
function luawa:run()
    --setup fail?
    if not luawa:prepareRequest() then
        return self:error( 500, 'Invalid Request' )
    end
    --go!
    return self:processRequest()
end

--prepare a request
function luawa:prepareRequest()
    --start request
    local request = {
        remote_addr = ngx.var.remote_addr,
        method = ngx.req.get_method(),
        headers = ngx.req.get_headers(),
        get = ngx.req.get_uri_args(),
        post = {},
        cookie = {},
        tmp = {}
    };
    --set hostname
    request.hostname = request.headers.host:gsub( ':[0-9]+', '' ) or self.hostname

    --always get first ?request
    if type( request.get.request ) == 'table' then
        request.get.request = request.get.request[1]
    end

    --find our response
    local res
    if request.method == 'GET' then
        res = self.gets[request.get.request] or self.gets.default
    elseif request.method == 'POST' then
        res = self.posts[request.get.request] or self.posts.default
        --setup post args
        ngx.req.read_body()
        request.post = ngx.req.get_post_args( self.limit_post )
    end

    --invalid request
    if not res then
        return false
    end

    --set file correctly
    request.args = res.args or {}
    request.file = res.file

    --split/set cookies
    if request.headers.cookie then
        for k, v in request.headers.cookie:gmatch( '([^;]+)' ) do
            local a, b, key, value = k:find( '([^=]+)=([^=]+)')
            if key and value then
                request.cookie[luawa.utils.trim( key )] = value
            end
        end
    end

    --set function & request
    request.func = request.get.request or 'default'

    --set request
    self.request = request

    return true
end

--process a request from the server
function luawa:processRequest()
    --start modules
    for k, v in pairs( self.modules ) do
        if self[v]._start then self[v]:_start() end
    end

    --template module first (special start) - gets token from session
    self.template:__start()

    --process the file
    local result = self:processFile( self.request.file )

    --debug module first (special end)
    self.debug:__end()

    --end modules
    for k, v in pairs( self.modules ) do
        if self[v]._end then self[v]:_end() end
    end

    --finally send response content & remove it
    ngx.say( self.response )
    self.response = ''
    self.requests = self.requests + 1
end

--process a file
function luawa:processFile( file )
    local func

    --cache should only be off in dev-mode
    if not self.cache then
        func = function()
            return loadfile( '/' .. self.root_dir .. file .. '.lua' )()
        end

    --cache/production
    else
        --try to fetch cache id
        local cache_id = ngx.shared[self.shm_prefix .. 'cache_app']:get( file )

        if cache_id then
            func = require( self.root_dir .. 'luawa/cache/' .. cache_id )
        else
            --read app file
            local f, err = io.open( self.root_dir .. file .. '.lua', 'r' )
            if not f then return self:error( 500, 'Cant open/access file: ' .. err ) end
            --read the file
            local string, err = f:read( '*a' )
            if not string then return self:error( 500, 'File read error: ' .. err ) end
            --close file
            f:close()

            --generate cache_id
            cache_id = file:gsub( '[^%w]', '_' )

            --prepend some stuff
            string = 'local function _' .. cache_id .. '()\n' .. string
            --append
            string = string .. '\nend return _' .. cache_id

            --now let's save this as a file
            local f, err = io.open( self.root_dir .. 'luawa/cache/' .. cache_id .. '.lua', 'w+' )
            if not f then return self:error( 500, 'File error: ' .. err ) end
            --write to file
            local status = f:write( string )
            if not status then return self:error( 500, 'File write error: ' .. err ) end
            --close file
            f:close()

            --save to cache
            ngx.shared[self.shm_prefix .. 'cache_app']:set( file, cache_id )

            --build function
            func, err = loadstring( string )
            if not func then return self:error( 500, err ) end
            func = func()
        end
    end

    --call the function safely
    local status, err = pcall( func )

    --error?
    if not status then
        self:error( 500, 'File: ' .. file .. '.lua, error: ' .. err )
    end


    --done!
    return true
end

--display an error page
function luawa:error( type, message )
    self.debug:error( 'Status: ' .. type .. ' / message: ' .. tostring( message ) )

    --hacky
    self.response = ''
    self.template.config.dir = 'luawa/'
    self.template.config.minimize = false
    self.template:load( 'error' )

    if self.debug.config.enabled then self.debug:__end() end

    --dump response
    ngx.say( self.response )

    --edit nginx (stop other output)
    ngx.exit( ngx.HTTP_OK )

    return false
end

--exit (for debug)
function luawa:exit( object )
    ngx.say( 'Luawa ' .. self.version .. ' dev:' )
    ngx.say( '<pre>' .. self.utils.tableString( object ) .. '</pre>' )

    if self.debug.config.enabled then
        self.debug:__end()
        ngx.say( luawa.response )
    end

    ngx.exit( 200 )
end

--return
return luawa