luawa.utils = {}

function luawa.utils.explode( str, split_char, num_loops )
    local strings, i, count = {}, 0, 0
    str = str or ''
    num_loops = num_loops or 0

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