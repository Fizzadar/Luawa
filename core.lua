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
    version = '0.9.5-unreleased',
    --base status
    requests = ngx.shared.requests,
    init = false,
    --all our modules
    modules = {
        'request',
        'database',
        'debug',
        'header',
        'session',
        'template',
        'user',
        'utils'
    },
    --modules with _start functions
    module_starts = {
        'debug',
        'request',
        'header',
        'session',
        'template'
    },
    --modules with _end functions
    module_ends = {
        'debug',
        'database',
        'header',
        'template'
    }
}

-- Set the config
function luawa:setConfig(root, file)
    if self.init then return end

    self.root = root or ''
    self.config_file = file or 'config'

    --load the config file (must return)
    local config = require(self.root .. self.config_file)

    --include modules
    for k, v in pairs(self.modules) do
        self[v] = require(self.root .. 'luawa/' .. v)
    end

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

    --cache?
    self.cache = config.cache and {} or false

    --limit post args?
    self.limit_post = config.limit_post or 100

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
    local status, err = ngx.on_abort(self.endRequest)

    self.init = true
    return true
end


-- Run luawa
function luawa:run()
    --setup fail?
    local file, err = self:prepareRequest()
    if not file then
        return self:error(500, 'Invalid Request')
    end

    --go!
    self:processRequest(file)

    --end
    self:endRequest()
end


-- Prepare a request
function luawa:prepareRequest()
    local method = ngx.req.get_method()
    local request = ngx.req.get_uri_args().request or false
    if type(request) == 'table' then
        request = request[1]
    end

    --find our response
    local file
    if method == 'GET' then
        file = self.gets[request] or self.gets.default
    elseif method == 'POST' then
        file = self.posts[request] or self.posts.default
    end

    --invalid request
    if not file then
        return false
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
    if self.cache and self.cache[file] then
        return self:processFunction(self.cache[file], file)
    end

    --load file as function
    local func, err = loadfile(self.root .. file .. '.lua')
    if not func then return self:error(500, err) end

    --save in cache
    if self.cache then
        self.cache[file] = func
    end

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
    self.template.config.dir = 'luawa/'
    self.template.config.minimize = false
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