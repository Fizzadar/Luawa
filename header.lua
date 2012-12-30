--[[
    file: header.lua
    desc: read/write headers/cookies
]]--
luawa.header = {}

--set a response header
function luawa.header:setHeader( key, value )
    luawa.response.headers[key] = value
end

--set a response cookie
function luawa.header:setCookie( key, value, expire, path, domain, secure, httponly )
    local string = key .. '=' .. value .. '; Path=' .. path .. '; Expires=' .. os.date( '%a, %d-%b-%Y %H:%M:%S GMT', expire )
    if domain then string = string .. '; Domain=' .. domain end
    if secure then string = string .. '; Secure' end
    if httponly then string = string .. '; HttpOnly' end

    table.insert( luawa.response.headers['Set-Cookie'], string )
end

--get a request header
function luawa.header:getHeader( key )
    return luawa.request.headers[key] or false
end

--get a request cookie
function luawa.header:getCookie( key )
    return luawa.request.cookie[key] or false
end