--[[
    file: template.lua
    desc: basic template system for html + api
]]
local ngx, tostring, pcall, loadstring, io, table, type = ngx, tostring, pcall, loadstring, io, table, type

local template = {
    config = {
        dir = 'app/template/',
        api = false
    },
    data = {}
}

--start function
function template:_start()
    --api?
    if self.config.api and luawa.request.hostname == self.config.api_host then
        self.api = true
    end
end

--end function
function template:_end()
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

    --empty data
    self.data = {}
end

--set data
function template:set( key, value )
    self.data[key] = value
end

--get data (dump all when no key)
function template:get( key )
    if not key then return self.data end
    return self.data[key]
end

--clear data
function template:clear()
    self.data = {}
end

--load a lhtml file, convert code to lua, run and add string to end of response.content
function template:load( file, inline )
    --token check
    if not self:get( 'token' ) then self:set( 'token', luawa.session:getToken() ) end

    --attempt to get cache_id
    local cache_id = ngx.shared.cache_template:get( file )
    local func

    --not cached?
    if not cache_id then
        --read app file
        local f, err = io.open( luawa.root_dir .. self.config.dir .. file .. '.lhtml', 'r' )
        if not f then return luawa:error( 500, 'Cant open/access file: ' .. err ) end
        --read the file
        local string, err = f:read( '*a' )
        if not string then return luawa:error( 500, 'File read error: ' .. err ) end
        --close file
        f:close()

        --process string lhtml => lua
        string = self:process( string )
        --prepend some stuff
        string = 'local function luawa_template()\n\n' .. string
        --append
        string = string .. '\n\nend return luawa_template'

        --generate cache_id
        cache_id = self.config.dir:gsub( '/', '_' ) .. file:gsub( '/', '_' )

        --cache?
        if luawa.cache then
            --now let's save this as a file
            local f, err = io.open( luawa.root_dir .. 'luawa/cache/' .. cache_id .. '.lua', 'w+' )
            if not f then return luawa:error( 500, 'File error: ' .. err ) end
            --write to file
            local status = f:write( string )
            if not status then return luawa:error( 500, 'File write error: ' .. err ) end
            --close file
            f:close()

            ngx.shared.cache_template:set( file, cache_id )
        else
            func = loadstring( string )()
            if not func then return luawa:error( 500, err ) end
        end
    end

    --require file & call safely
    func = func or require( luawa.root_dir .. 'luawa/cache/' .. cache_id )
    local status, err = pcall( func )

    --if ok, add to output
    if status then
        if inline then
            return err
        else
            luawa.response = luawa.response .. err
        end
    else
        return false, 'Template error: ' .. err
    end
end

--function to work before tostring
function template:toString( string )
    --nil returns blank
    if string == nil then return 'nil' end
    --string as string
    if type( string ) == 'string' then return string end
    --otherwise as best
    return tostring( string )
end

--turn file => lua
function template:process( code )
    --trim html?
    if self.config.trim then code = code:gsub( '[\t\n]', '' ) end

    --prepend bits
    code = 'local self, output = luawa.template, "" output = output .. [[' .. code
    --replace <?=vars?>
    code = code:gsub( '<%?=([,/_\'%[%]%:%.%a%s%(%)]+)%s%?>', ']] .. self:toString( %1 ) .. [[' )
    --replace <? to close output, start raw lua
    code = code:gsub( '<%?', ']] ' )
    --replace ?> to stop lua and start output (in table)
    code = code:gsub( '%?>', ' output = output .. [[' )
    --close final output and return concat of the table
    code = code .. ' ]] return output'

    return code
end


--return
return template