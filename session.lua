--[[
    file: session.lua
    desc: read/write session data (stored in nginx shared memory)
]]
--json & hashing
local json = require( 'cjson.safe' )

local session = {
    config = {
        expire = 24 * 3600
    }
}

--start
function session:_start()
    self.header, self.utils = luawa.header, luawa.utils

    --get session id, or set
    self.id = self.header:getCookie( 'luawa_sessionid' ) or self:generateId()

    --is there a session in the memory? set to empty json string
    if not ngx.shared[luawa.shm_prefix .. 'session']:get( self.id ) then
        ngx.shared[luawa.shm_prefix .. 'session']:set( self.id, '{}' )
    end
end

--generate & set an ID
function session:generateId()
    --generate random id
    local id = self.utils.digest( self.utils.randomString( 32 ) )

    --send to user via cookie (expires in 24h)
    self.header:setCookie( 'luawa_sessionid', id, self.config.expire )

    return id
end

--set session data
function session:set( key, value )
    --get table assign value
    local data = self:get()
    data[key] = value
    --encode + set to session
    ngx.shared[luawa.shm_prefix .. 'session']:set( self.id, json.encode( data ) )
end

--get session data
function session:get( key )
    --get + decode
    local data, err = json.decode( ngx.shared[luawa.shm_prefix .. 'session']:get( self.id ) )
    --return data.key or data
    if not key then return data else return data[key] end
end

--delete session data
function session:delete( key )
    --get + remove
    local data = self:get()
    data[key] = nil
    --encode + set to session
    ngx.shared[luawa.shm_prefix .. 'session']:set( self.id, json.encode( data ) )
end


--get/generate token
function session:getToken()
    local token = self:get( 'token' )
    --generate token
    if not token then
        token = self.utils.randomString( 16 )
        self:set( 'token', token )
    end

    return token
end

--validate token
function session:checkToken( token )
    --check token
    local result = self:get( 'token' ) == token
    --delete token, get a new one
    self:delete( 'token' )
    self:getToken()

    return result
end

--add message
function session:addMessage( type, text )
    local messages = self:get( '_messages' ) or {}
    table.insert( messages, { type = type, text = text } )
    self:set( '_messages', messages )
end

--get messages
function session:getMessages()
    local messages = self:get( '_messages' ) or {}
    self:set( '_messages', {} )
    return messages
end

--return
return session