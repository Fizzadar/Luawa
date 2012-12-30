--[[
    file: template.lua
    desc: basic template system for html + api
]]--

--json driver for api
json = require( 'cjson.safe' )

--define template
luawa.template = {
    config = {
        dir = 'app/template/',
        cache = false,
        api = false
    },
    data = {}
}

--start function
function luawa.template:_start()
    if self.config.api and luawa.request.hostname == self.config.api_host then
        self.api = true
    end
end

--end function
function luawa.template:_end()
    --if api request output template data as json
    if self.api then
        local out, err = json.encode( self.data )
        if out then
            luawa.header:setHeader( 'Content-Type', 'text/json' )
            luawa.response.content = out
        else
            luawa.debug:error( err )
        end
    end
end

--add data
function luawa.template:add( key, value )
    self.data[key] = value
end

--get data (dump all when no key)
function luawa.template:get( key )
    if not key then return self.data end
    return self.data[key]
end

--clear data
function luawa.template:clear()
    self.data = {}
end

--load a lhtml file, convert code to lua, run and add string to end of response.content
function luawa.template:load( file )
    --cancel if api mode
    if self.api then return true end

    --vars
    local string, code, mode = '', 'local self, code_str = luawa.template, {}', 'html'

    --cache?
    local func, err
    if self.config.cache and luawa.cache.template[file] then
        func, err = luawa.cache.template[file], 'Failed to load template: ' .. file .. ' from cache'
        if func then luawa.debug:message( 'Template function loaded from cache: ' .. file ) end
    else
        --open file
        local f, e = io.open( self.config.dir .. file .. '.lhtml', 'r' )
        if not f then return false, 'Failed to load file: ' .. self.config.dir .. file .. '.lhtml: ' .. e end

        --loop file line by line
        repeat
            string = f:read( '*l' )
            --time to rewrite the string + append to code
            if string then
                local s, f, m = 0, -1, mode
                string = luawa.utils:trim( string )
                --opening tag?
                if string:sub( 0, 2 ) == '<?' and string:sub( 0, 3 ) ~= '<?=' then
                    m, mode = 'lua', 'lua'
                    --closing on this line? add as code
                    if string:sub( -2 ) == '?>' then
                        s, f = 3, string:len() - 2
                        mode = 'html' --set mode for next loop
                    else
                        s = 3 --no closing lua tag
                    end
                --does this line end an lua block?
                elseif m == 'lua' and string:sub( -2 ) == '?>' then
                    f = string:len() - 2
                    mode = 'html' --set mode
                end

                --add the code (lua mode)
                if m == 'lua' then
                    code = code .. "\n" .. string:sub( s, f )
                --html mode
                elseif m == 'html' and string:len( string:sub( s, f ) ) > 0 then
                    --find & replace any <?=CHARS ?> with " .. CHARS .. "
                    string = string:gsub( '(%<%?=([\'%[%]%:%.%a%s%(%)]+)%s%?%>)', '" .. tostring( %2 ) .. "' )
                    code = code .. "\n" .. 'table.insert( code_str, "' .. string .. '" )'
                end
            end
        until string == nil

        --close file
        f:close()
        
        --end bit of code
        code = code .. "\nlocal output = ''"
        code = code .. "\nfor k, v in pairs( code_str ) do"
        code = code .. "\noutput = output .. v end"
        code = code .. "\nreturn output"

        --compile function
        func, err = loadstring( code )

        --cache
        if self.config.cache then
            table.insert( luawa.response.cache, { cache = 'template', key = file, value = func } )
        end
    end

    local out
    if func then
        local status, string = pcall( func )

        if status then
            out = string
        else
            luawa.debug:error( 'Template error: ' .. string )
            return false, string
        end
    else
        luawa.debug:error( 'Template error: could not compile: ' .. tostring( err ) )
        return false, 'Could not compile: ' .. tostring( err )
    end

    --add the content to response
    if out then
    	luawa.response.content = luawa.response.content .. out
        return true
    end
end