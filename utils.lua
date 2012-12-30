--[[
    file: utils.lua
    desc: useful functions (mostly those I miss from PHP)
]]--
luawa.utils = {}

--return tables and any number of sub-tables as a string
function luawa.utils:tableString( table, level )
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
function luawa.utils:trim( string )
    return string:gsub( '^%s*(.-)%s*$', '%1' )
end