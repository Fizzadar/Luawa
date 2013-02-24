--[[
    file: utils.lua
    desc: useful functions
]]
local hasher = require( 'luawa/lib/sha512' )
local random = require( 'luawa/lib/random' )
local str = require( 'luawa/lib/string' )

local utils = {}

--return tables and any number of sub-tables as a string
function utils:tableString( table, level )
    --not a table?
    if type( table ) ~= 'table' then return false end

    local string = ''
    local table, level = table or {}, level or 0

    --loop through the table
    for k, v in pairs( table ) do
        for i = 0, level do
            k = ' ' .. k
        end
        string = string .. "\n" .. k .. ' => ' .. tostring( v )
        if type( v ) == 'table' then
            string = string .. self:tableString( v, level + 4 )
        end
    end

    return string
end

--trim string
function utils:trim( string )
    if not string then return false end
    return string:gsub( '^%s*(.-)%s*$', '%1' )
end

--rtrim string (remove chars from right end)
function utils:rtrim( string, chars )
    if not string or not chars then return false end
    return string:gsub( '^(.-)[' .. chars .. ']*$', '%1' )
end

--random string
function utils:randomString( length )
    return str.to_hex( random.bytes( length ) )
end

--digest
function utils:digest( string )
    local sha = hasher:new()
    sha:update( string )
    return str.to_hex( sha:final() )
end

--urldecode <= http://lua-users.org/wiki/StringRecipes
function utils:urlDecode( string )
    string = string:gsub( '+', ' ' )
    string = string:gsub( '%%(%x%x)', function( h ) return string.char( tonumber( h, 16 ) ) end )
    string = string:gsub( '\r\n', '\n' )
    return string
end

--urlencode (see above link)
function utils:urlEncode( string )
    string = string:gsub( '\n', '\r\n' )
    string = string:gsub( '([^%w ])', function( h ) return string.format( '%%%02X', string.byte( h ) ) end )
    string = string:gsub( ' ', '+' )
    return string
end


--return obj
return utils