--[[
    file: header.lua
    desc: read/write headers/cookies
]]
local os, table, ngx = os, table, ngx

local header = {
    cookies = {}
}

--end, send cookie headers, forget them
function header:_end()
    ngx.header['Set-Cookie'] = self.cookies
    self.cookies = {}
end

--redirect
function header:redirect( url )
    --end modules, we're ending here! (close db connections, etc)
    for k, v in pairs( luawa.modules ) do
        if luawa[v]._end then luawa[v]:_end() end
    end

    --redirect
    return ngx.redirect( url )
end

--set a response header
function header:setHeader( key, value )
    ngx.header[key] = value
end

--get a request header
function header:getHeader( key )
    return luawa.request.headers[key] or false
end

--set a response cookie
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
    table.insert( self.cookies, string )
    --and set internal cookie for any further requests
    luawa.request.cookie[key] = value
end

--get a request cookie
function header:getCookie( key )
    return luawa.request.cookie[key] or false
end

--delete a cookie (set it to expire 60m ago)
function header:deleteCookie( key )
    self:setCookie( key, '', -3600, '/' )
end


--return header
return header