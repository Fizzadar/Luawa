luawa.utils = {}

--similar to php explode (heavy use in server.lua)
function luawa.utils:explode( str, split_char, num_loops )
    local strings, i, count, str, num_loops = {}, 0, 0, str or '', num_loops or 0

    --loop until we run out of spaces
    repeat
        i = string.find( str, split_char )
        if i then
            --work out substring, only add if not space
            local sub = string.sub( str, 0, i - 1 )
            if sub ~= '' then
                table.insert( strings, sub )
            end
            str = string.sub( str, i + #split_char )
        end
        count = count + 1
    until i == nil or ( count >= num_loops and num_loops > 0 )
    --add the final bit
    table.insert( strings, str )

    return strings
end

--return tables and any number of sub-tables as a string
function luawa.utils:tableString( table, level )
    local string, table, level = '', table or {}, level or 0

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