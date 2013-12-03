--[[
    file: utils.lua
    desc: useful functions (some php-like)
]]
local hasher = require( luawa.root_dir .. 'luawa/lib/sha512' )
local random = require( luawa.root_dir .. 'luawa/lib/random' )
local str = require( luawa.root_dir .. 'luawa/lib/string' )

local utils = {}

function utils.tableCopy( table )
    local function tableCopy( table )
        local copy = {}
        for k, v in pairs( table ) do
            if type( v ) == 'table' then
                copy[k] = tableCopy( v )
            else
                copy[k] = v
            end
        end

        return copy
    end

    return tableCopy( table )
end

--return tables and any number of sub-tables as a string
function utils.tableString( table, level )
    local function tableString( table, level )
        --not a table?
        if type( table ) ~= 'table' then return false end

        local str = ''
        local table, level = table or {}, level or 0

        --loop through the table
        for k, v in pairs( table ) do
            for i = 0, level do
                k = ' ' .. k
            end
            str = str .. "\n" .. k .. ' => ' .. tostring( v )
            if type( v ) == 'table' then
                str = str .. tableString( v, level + 4 )
            end
        end

        return str
    end

    return tableString( table, level )
end

--html => html entities
function utils.htmlEnts( str )
    local entities = {
        ['¡'] = '&iexcl;',
        ['¢'] = '&cent;',
        ['£'] = '&pound;',
        ['¤'] = '&curren;',
        ['¥'] = '&yen;',
        ['¦'] = '&brvbar;',
        ['§'] = '&sect;',
        ['¨'] = '&uml;',
        ['©'] = '&copy;',
        ['ª'] = '&ordf;',
        ['«'] = '&laquo;',
        ['¬'] = '&not;',
        ['­'] = '&shy;',
        ['®'] = '&reg;',
        ['¯'] = '&macr;',
        ['°'] = '&deg;',
        ['±'] = '&plusmn;',
        ['²'] = '&sup2;',
        ['³'] = '&sup3;',
        ['´'] = '&acute;',
        ['µ'] = '&micro;',
        ['¶'] = '&para;',
        ['·'] = '&middot;',
        ['¸'] = '&cedil;',
        ['¹'] = '&sup1;',
        ['º'] = '&ordm;',
        ['»'] = '&raquo;',
        ['¼'] = '&frac14;',
        ['½'] = '&frac12;',
        ['¾'] = '&frac34;',
        ['¿'] = '&iquest;',
        ['À'] = '&Agrave;',
        ['Á'] = '&Aacute;',
        ['Â'] = '&Acirc;',
        ['Ã'] = '&Atilde;',
        ['Ä'] = '&Auml;',
        ['Å'] = '&Aring;',
        ['Æ'] = '&AElig;',
        ['Ç'] = '&Ccedil;',
        ['È'] = '&Egrave;',
        ['É'] = '&Eacute;',
        ['Ê'] = '&Ecirc;',
        ['Ë'] = '&Euml;',
        ['Ì'] = '&Igrave;',
        ['Í'] = '&Iacute;',
        ['Î'] = '&Icirc;',
        ['Ï'] = '&Iuml;',
        ['Ð'] = '&ETH;',
        ['Ñ'] = '&Ntilde;',
        ['Ò'] = '&Ograve;',
        ['Ó'] = '&Oacute;',
        ['Ô'] = '&Ocirc;',
        ['Õ'] = '&Otilde;',
        ['Ö'] = '&Ouml;',
        ['×'] = '&times;',
        ['Ø'] = '&Oslash;',
        ['Ù'] = '&Ugrave;',
        ['Ú'] = '&Uacute;',
        ['Û'] = '&Ucirc;',
        ['Ü'] = '&Uuml;',
        ['Ý'] = '&Yacute;',
        ['Þ'] = '&THORN;',
        ['ß'] = '&szlig;',
        ['à'] = '&agrave;',
        ['á'] = '&aacute;',
        ['â'] = '&acirc;',
        ['ã'] = '&atilde;',
        ['ä'] = '&auml;',
        ['å'] = '&aring;',
        ['æ'] = '&aelig;',
        ['ç'] = '&ccedil;',
        ['è'] = '&egrave;',
        ['é'] = '&eacute;',
        ['ê'] = '&ecirc;',
        ['ë'] = '&euml;',
        ['ì'] = '&igrave;',
        ['í'] = '&iacute;',
        ['î'] = '&icirc;',
        ['ï'] = '&iuml;',
        ['ð'] = '&eth;',
        ['ñ'] = '&ntilde;',
        ['ò'] = '&ograve;',
        ['ó'] = '&oacute;',
        ['ô'] = '&ocirc;',
        ['õ'] = '&otilde;',
        ['ö'] = '&ouml;',
        ['÷'] = '&divide;',
        ['ø'] = '&oslash;',
        ['ù'] = '&ugrave;',
        ['ú'] = '&uacute;',
        ['û'] = '&ucirc;',
        ['ü'] = '&uuml;',
        ['ý'] = '&yacute;',
        ['þ'] = '&thorn;',
        ['ÿ'] = '&yuml;',
        ['"'] = '&quot;',
        ["'"] = '&#39;',
        ['<'] = '&lt;',
        ['>'] = '&gt;',
        ['&'] = '&amp;'
    }
    str = str:gsub( '.', function( v )
        if entities[v] then return entities[v] else return v end
    end )
    return str
end

--alphanumeric-ify string
function utils.alphaNumerify( str )
    return str:gsub( '%W', '' )
end

--capitalize first character
function utils.capitalizeFirst( str )
    return str:gsub( '^%l', string.upper )
end

--check an email is valid (@-check only http://davidcel.is/blog/2012/09/06/stop-validating-email-addresses-with-regex/)
function utils.isEmail( str )
    if str:match( '@' ) then
        return true
    end
end

--check an url
function utils.isUrl( str )
    if str:match( '^https?://' ) then
        return true
    end
end

--trim string
function utils.trim( str )
    return str:match( '^%s*(.-)%s*$' )
end

--rtrim string (remove chars from right end)
function utils.trimRight( str, chars )
    return str:match( '^(.-)[' .. chars .. ']*$' )
end

--ltrim string (remove chars from left end)
function utils.trimLeft( str, chars )
    return str:match( '^[' .. chars .. ']*(.-)$' )
end

--random string
function utils.randomString( length )
    return str.to_hex( random.bytes( length ) )
end

--digest
function utils.digest( string )
    local sha = hasher:new()
    sha:update( string )
    return str.to_hex( sha:final() )
end

--urldecode
function utils.urlDecode( str )
    return ngx.unescape_uri( str )
end

--urlencode
function utils.urlEncode( str )
    return ngx.escape_uri( str )
end

--explode, credit: http://richard.warburton.it
function utils.explode( str, divide )
  if divide == '' then return false end
  local pos, arr = 0, {}
  --for each divider found
  for st, sp in function() return string.find( str, divide, pos, true ) end do
    table.insert( arr, string.sub( str, pos, st - 1 ) ) --attach chars left of current divider
    pos = sp + 1 --jump past current divider
  end
  table.insert( arr, string.sub( str, pos ) ) -- Attach chars right of last divider
  return arr
end

--return obj
return utils