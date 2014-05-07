-- Luawa
-- File: header.lua
-- Desc: deals with HTTP headers & cookies

local os = os
local table = table

local ngx = ngx


local header = {}

-- Init
function header:_init()
    self.session = luawa.session
    self.utils = luawa.utils
end

-- Start
function header:_start()
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
function header:_end()
    self:setHeader('Set-Cookie', ngx.ctx.new_cookies)
    ngx.header['Set-Cookie'] = ngx.ctx.new_cookies
end


-- Redirect
function header:redirect(url, message_type, message_text)
    if message_type and message_text then
        self.session:addMessage(message_type, message_text)
    end

    --redirect
    return luawa:redirect(url)
end


-- Get headers
function header:getHeaders()
    return ngx.req.get_headers()
end

-- Set a response header
function header:setHeader(key, value)
    ngx.header[key] = self.new_cookies
    ngx.req.set_header(key, value)
end

-- Get a request header
function header:getHeader(key)
    return ngx.req.get_headers()[key] or false
end


-- Get cookies
function header:getCookies()
    return ngx.ctx.cookies
end

-- Set a response cookie
function header:setCookie(key, value, expire, path, domain, secure, httponly)
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

-- Get a request cookie
function header:getCookie(key)
    return ngx.ctx.cookies[key] or false
end

-- Delete a cookie (set it to expire 60m ago)
function header:deleteCookie(key)
    self:setCookie(key, '', -3600, '/')
end


return header