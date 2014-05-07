-- Luawa
-- File: request.lua
-- Desc: holds/prepares request data (gets & posts)

local setmetatable = setmetatable

local ngx = ngx


local request = {
    get = {},
    post = {},
    header = {},
    cookie = {}
}

-- Init
function request:_init()
    self.session = luawa.session
    self.utils = luawa.utils
end

-- Start
function request:_start()
    --read post data/args
    ngx.req.read_body()

    --prepare new cookies table
    ngx.ctx.new_cookies = {}

    --get/parse cookies
    ngx.ctx.cookies = {}
    local cookie_header = ngx.req.get_headers()['cookie']
    if cookie_header then
        for k, v in cookie_header:gmatch('([^;]+)') do
            local a, b, key, value = k:find('([^=]+)=([^=]+)')
            if key and value then
                ngx.ctx.cookies[self.utils.trim(key)] = value
            end
        end
    end
end

-- Request end, send cookie headers, forget them
function request:_end()
    self:setHeader('Set-Cookie', ngx.ctx.new_cookies)
    ngx.header['Set-Cookie'] = ngx.ctx.new_cookies
end


-- Get all GETs
function request:gets()
    return ngx.req.get_uri_args()
end

-- Get all POSTs
function request:posts()
    return ngx.req.get_post_args(luawa.limit_post)
end

-- Get all cookies
function request:cookies()
    return ngx.ctx.cookies
end

-- Get all headers
function request:headers()
    return ngx.req.get_headers()
end


-- Set a response header
function request:setHeader(key, value)
    ngx.header[key] = self.new_cookies
    ngx.req.set_header(key, value)
end

-- Set a response cookie
function request:setCookie(key, value, expire, path, domain, secure, httponly)
    if not path then path = '/' end
    if not expire then expire = 3600 end
    if not domain then domain = luawa.request.hostname end

    --basic cookie string
    local string = key .. '=' .. value .. '; Path=' .. path .. '; Expires=' .. ngx.cookie_time(os.time() + expire)

    --extras
    if domain then string = string .. '; Domain=' .. domain end
    if secure then string = string .. '; Secure' end
    if httponly then string = string .. '; HttpOnly' end

    --insert into cookies, to be dumped at end
    table.insert(ngx.ctx.new_cookies, string)
    --and set internal cookie for any further requests
    ngx.ctx.cookies[key] = value
end

-- Delete a cookie (set it to expire 60m ago)
function request:deleteCookie(key)
    self:setCookie(key, '', -3600, '/')
end


-- Redirect
function request:redirect(url, message_type, message_text)
    if message_type and message_text then
        self.session:addMessage(message_type, message_text)
    end

    --redirect
    return luawa:redirect(url)
end


--bind .get => ngx uri args
local mt = {
    __index = function(table, key)
        return ngx.req.get_uri_args()[key] or nil
    end
}
setmetatable(request.get, mt)

--bind .post => ngx post args
local mt = {
    __index = function(table, key)
        return ngx.req.get_post_args(luawa.limit_post)[key] or nil
    end
}
setmetatable(request.post, mt)

--bind .header => ngx header args
local mt = {
    __index = function(table, key)
        return ngx.req.get_headers()[key] or nil
    end
}
setmetatable(request.header, mt)

--bind .cookie => ngx cookie args
local mt = {
    __index = function(table, key)
        return ngx.ctx.cookies[key] or nil
    end
}
setmetatable(request.cookie, mt)

--bind .other_bits
local mt = {
    __index = function(table, key)
        if key == 'method' then
            return ngx.req.get_method()
        end
        if key == 'hostname' or key == 'hostport' then
            local header = ngx.req.get_headers().host
            local a, b, host, port = header:find('^([^:]+):?([0-9]*)$')
            return key == 'hostname' and host or port
        end
        if key == 'remote_addr' then
            return ngx.var.remote_addr
        end
    end
}
setmetatable(request, mt)


return request