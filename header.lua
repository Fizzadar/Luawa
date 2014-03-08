-- Luawa
-- File: header.lua
-- Desc: deals with HTTP headers & cookies

local os = os
local table = table
local ngx = ngx

local header = {
    headers = {},
    cookies = {},
    new_cookies = {}
}

-- Init
function header:_init()
    self.session = luawa.session
    self.utils = luawa.utils
end

function header:_start()
    self.headers = ngx.req.get_headers()

    if self.headers.cookie then
        for k, v in self.headers.cookie:gmatch( '([^;]+)' ) do
            local a, b, key, value = k:find( '([^=]+)=([^=]+)')
            if key and value then
                self.cookies[self.utils.trim( key )] = value
            end
        end
    end
end

-- Request end, send cookie headers, forget them
function header:_end()
    ngx.header['Set-Cookie'] = self.new_cookies
    self.new_cookies = {}
    self.cookies = {}
    self.headers = {}
end

-- Redirect
function header:redirect( url, message_type, message_text )
    if message_type and message_text then
        self.session:addMessage( message_type, message_text )
    end

    --redirect
    return luawa:redirect( url )
end

-- Set a response header
function header:setHeader( key, value )
    ngx.req.set_header( key, value )
end

-- Get a request header
function header:getHeader( key )
    return ngx.header[key] or false
end

-- Set a response cookie
function header:setCookie( key, value, expire, path, domain, secure, httponly )
    if not path then path = '/' end
    if not expire then expire = 3600 end
    if not domain then domain = luawa.request.hostname end

    --basic cookie string
    local string = key .. '=' .. value .. '; Path=' .. path .. '; Expires=' .. ngx.cookie_time( os.time() + expire )

    --extras
    if domain then string = string .. '; Domain=' .. domain end
    if secure then string = string .. '; Secure' end
    if httponly then string = string .. '; HttpOnly' end

    --insert into cookies, to be dumped at end
    table.insert( self.new_cookies, string )
    --and set internal cookie for any further requests
    self.cookies[key] = value
end

-- Get a request cookie
function header:getCookie( key )
    return self.cookies[key] or false
end

-- Delete a cookie (set it to expire 60m ago)
function header:deleteCookie( key )
    self:setCookie( key, '', -3600, '/' )
end


return header