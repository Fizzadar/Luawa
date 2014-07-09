-- Luawa
-- File: core.lua
-- Desc: Luawa definition

local pairs = pairs
local require = require
local loadfile = loadfile
local pcall = pcall
local type = type
local tostring = tostring
local io = io
local ngx = ngx


local luawa = {
    version = '1.0.0-dev',
    --base status
    requests = ngx.shared.requests,
    --function cache
    cache = {},
    --all our modules
    modules = {
        'request',
        'database',
        'debug',
        'session',
        'template',
        'user',
        'utils'
    },
    --modules with _start functions
    module_starts = {
        'debug',
        'request',
        'session',
        'template'
    },
    --modules with _end functions
    module_ends = {
        'debug',
        'database',
        'template',
        'request'
    }
}


-- Start luawa
function luawa:init()
    local config = require(ngx.var.config_root .. '.luawa')

    --include modules
    for k, v in pairs(self.modules) do
        self[v] = require('luawa.' .. v)
    end

    --app root
    self.root = ngx.var.app_root .. '/'

    --set get/post
    self.gets = config.gets or {}
    self.posts = config.posts or {}

    --hostname?
    self.hostname = config.hostname or ''

    --shared memory prefix
    self.shm_prefix = config.shm_prefix or ''
    self.requests = ngx.shared[self.shm_prefix .. 'requests']
    self.requests:set('success', 0)
    self.requests:set('error', 0)

    --limit post args?
    self.limit_post = config.limit_post or 100

    --caching?
    self.caching = config.cache or false

    --module config
    for k, v in pairs(self.modules) do
        if type(config[v]) == 'table' then
            if not self[v].config then self[v].config = {} end
            --set values
            for c, d in pairs(config[v]) do
                self[v].config[c] = d
            end
        end
    end

    --module inits
    for k, v in pairs(self.modules) do
        if self[v]._init then self[v]:_init() end
    end

    --set on_abort
    ngx.on_abort(self.endRequest)

    return self
end


-- Run luawa
function luawa:run()
    --prepare luawa
    local file, err = self:prepareRequest()
    if not file then
        return self:error(500, 'Invalid Request')
    end

    --pass to luawa to process request
    self:processFile(file)

    --end luawa request
    self:endRequest()
end


-- Prepare a request
function luawa:prepareRequest()
    local method = ngx.req.get_method():lower() .. 's'
    local request = ngx.req.get_uri_args().request or false
    if type(request) == 'table' then
        request = request[1]
    end

    --find our response
    local file
    if self[method] then
        file = self[method][request] or self[method].default
    end

    --start modules
    for k, v in pairs(self.module_starts) do
        self[v]:_start()
    end

    --get ready to respond
    ngx.ctx.response = ''

    return file
end


-- Load a file as a function & process
function luawa:processFile(file)
    --try cache
    if self.caching and self.cache[file] then
        return self:processFunction(self.cache[file], file)
    end

    --load file as function
    local func, err = loadfile(self.root .. file .. '.lua')
    if not func then return self:error(500, err) end

    --save to cache
    self.cache[file] = func

    --run it
    return self:processFunction(func, file)
end


-- Process a function
function luawa:processFunction(func, file)
    --call the function safely
    local status, err = pcall(func)
    if not status then self:error(500, 'File: ' .. (file or 'unknown') .. '.lua, error: ' .. err) end

    --done!
    return true
end


-- End the current request
function luawa:endRequest(error, url)
    if not self then self = luawa end

    --end modules
    for k, v in pairs(self.module_ends) do
        self[v]:_end()
    end

    --internal stat counters
    if error then
        self.requests:incr('error', 1)
    else
        self.requests:incr('success', 1)
    end

    --redirecting?
    if url then
        return ngx.redirect(url)
    end

    --finally send response content & remove it
    ngx.say(ngx.ctx.response)
    self.response = ''

    --and we're done!
    return ngx.exit(ngx.HTTP_OK)
end


-- Shortcut to redirect via endRequest
function luawa:redirect(url)
    self:endRequest(false, url)
end


-- Display an error page
function luawa:error(type, message)
    self.debug:error('Status: ' .. type .. ' / message: ' .. tostring(message))

    --hacky
    local old_dir, old_minimize = self.template.config.dir, self.template.config.minimize
    self.response = ''
    self.template.config.dir = 'luawa'
    self.template.config.minimize = false
    self.template:set('error_type', type)
    --show messages when debugging
    if self.debug.config.enabled then
        self.template:set('error_message', message)
    end
    self.template:load('error')

    --restore template config
    --horribly hacky
    self.template.config.dir, self.template.config.minimize = old_dir, old_minimize

    --end request & exit
    self:endRequest(true)
end

-- Exit (for debug)
function luawa:exit(object)
    ngx.say('Luawa ' .. self.version .. ' dev:')
    ngx.say('<pre>' .. self.utils.table_string(object) .. '</pre>')

    --end request & exit
    self:endRequest()
end


return luawa
