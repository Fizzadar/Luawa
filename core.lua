--[[
    file: core.lua
    desc: main luawa file
        most importantly takes http requests as a table and returns a response as a table
]]
--local optimization
local pairs = pairs
local require = require
local loadstring = loadstring
local pcall = pcall
local type = type
local tostring = tostring
local io = io
local ngx = ngx

local luawa = {
    config_file = 'config',
    modules = { 'user', 'template', 'database', 'utils', 'header', 'email', 'session', 'debug' }, --all our modules
    response = '<!--the first request is always special-->'
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
        cookie = {}
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
        request.post = ngx.req.get_post_args()
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
            request.cookie[luawa.utils.trim( key )] = value
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
end

--process a file
function luawa:processFile( file )
    --try to fetch cache id
    local cache_id = ngx.shared[self.shm_prefix .. 'cache_app']:get( file )
    local func

    --not cached?
    if not cache_id then
        --read app file
        local f, err = io.open( self.root_dir .. file .. '.lua', 'r' )
        if not f then return self:error( 500, 'Cant open/access file: ' .. err ) end
        --read the file
        local string, err = f:read( '*a' )
        if not string then return self:error( 500, 'File read error: ' .. err ) end
        --close file
        f:close()

        --prepend some stuff
        string = 'local function _luawa_app()\n\n' .. string
        --append
        string = string .. '\n\nend return _luawa_app'

        --generate cache_id
        cache_id = file:gsub( '/', '_' )

        --cache?
        if self.cache then
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
        else
            func, err = loadstring( string )
            if not func then return self:error( 500, err ) end
            func = func()
        end
    end

    --require file, call it safely
    func = func or require( self.root_dir .. 'luawa/cache/' .. cache_id )
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

    --dump response
    ngx.say( self.response )

    --edit nginx (stop other output)
    ngx.exit( ngx.HTTP_OK )

    return false
end


--return
return luawa