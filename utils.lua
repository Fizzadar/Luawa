luawa.utils = {}


function luawa.utils.explode( string, split_char )
    local strings, i = {}, 0

    --loop until we run out of spaces
    repeat
        i = string.find( string, split_char )
        if i then
            --work out substring, only add if not space
            local sub = string.sub( string, 0, i - 1 )
            if sub ~= '' then
                table.insert( strings, sub )
            end
            string = string.sub( string, i + 1 )
        end
    until i == nil
    --add the final bit
    table.insert( strings, string )

    return strings
end