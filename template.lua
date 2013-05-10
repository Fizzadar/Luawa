--[[
    file: template.lua
    desc: basic template system for html + api
]]
--json & hashing
local json = require( 'cjson.safe' )
local ngx, tostring, pcall, loadstring, io, table, type = ngx, tostring, pcall, loadstring, io, table, type

local template = {
    config = {
        dir = 'app/template/'
    },
    data = {}
}

--start function
function template:_start()
    --api?
    if self.config.api and luawa.request.get._api then
        self.api = true
    end
end

--special start
function template:__start()
    --token check (if regenerated session adds it for us)
    if not self:get( 'token' ) then self:set( 'token', luawa.session:getToken(), true ) end
end

--end function
function template:_end()
    --if api request output template data as json
    if self.api then
        local function clean( data )
            if type( data ) == 'table' then
                for k, v in pairs( data ) do
                    data[k] = clean( v )
                end
            else
                if type( data ) == 'function' then
                    data = false
                end
            end
            return data
        end
        clean( self.data )

        luawa.header:setHeader( 'Content-Type', 'text/json' )
        local out, err = json.encode( self.data )
        if out then
            luawa.response = out
        else
            luawa.response = json.encode( { error = err } )
        end
        self.api = false
    end

    self:clear()
end

--set data
function template:set( key, value, api )
    --not api or api enabled
    if not self.api or api then
        self.data[key] = value
    end
end

--add data (makes table value must be table)
function template:add( key, value, api )
    if not self.api or api then
        if not self.data[key] then
            self.data[key] = {}
        elseif type( self.data[key] ) ~= 'table' then
            self.data[key] = { self.data[key] }
        end

        for k, v in pairs( value ) do
            table.insert( self.data[key], v )
        end
    end
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

--add raw code to current output
function template:put( content )
    if self.api then return end

    luawa.response = luawa.response .. tostring( content )
end

--load a lhtml file, convert code to lua, run and add string to end of response.content
function template:load( file, inline )
    if self.api then return true end

    --attempt to get cache_id
    local cache_id = ngx.shared[luawa.shm_prefix .. 'cache_template']:get( file )
    local func

    --not cached?
    if not cache_id then
        --read app file
        local f, err = io.open( luawa.root_dir .. self.config.dir .. file .. '.lhtml', 'r' )
        if not f then return luawa:error( 500, 'Template: ' .. file .. ' :: Cant open/access file: ' .. err ) end
        --read the file
        local string, err = f:read( '*a' )
        if not string then return luawa:error( 500, 'Template: ' .. file .. ' :: File read error: ' .. err ) end
        --close file
        f:close()

        --process string lhtml => lua
        string = self:process( string )
        --prepend some stuff
        string = 'local function _luawa_template()\n\n' .. string
        --append
        string = string .. '\n\nend return _luawa_template'

        --generate cache_id
        cache_id = self.config.dir:gsub( '/', '_' ) .. file:gsub( '/', '_' )

        --cache?
        if luawa.cache then
            --now let's save this as a file
            local f, err = io.open( luawa.root_dir .. 'luawa/cache/' .. cache_id .. '.lua', 'w+' )
            if not f then return luawa:error( 500, 'Template: ' .. file .. ' :: File error: ' .. err ) end
            --write to file
            local status = f:write( string )
            if not status then return luawa:error( 500, 'Template: ' .. file .. ' :: File write error: ' .. err ) end
            --close file
            f:close()

            ngx.shared[luawa.shm_prefix .. 'cache_template']:set( file, cache_id )
        else
            --compile our string
            local status, err = loadstring( string )
            if not status then return luawa:error( 500, 'Template: ' .. file .. ' :: ' .. err ) end
            --compile isn't a function, make it one by calling the compiled string
            func = status()
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
            return true
        end
    else
        return luawa:error( 500, 'Template: ' .. file .. ' :: ' .. err )
    end
end

--function to work before tostring
function template:toString( string )
    --nil returns blank
    if string == nil then return '' end
    --string as string
    if type( string ) == 'string' then return string end
    --otherwise as best
    return tostring( string )
end

--turn file => lua
function template:process( code )
    --minimize html? will probably break javascript!
    if self.config.minimize then code = code:gsub( '[\t\n]', ' ' ) end

    --prepend bits
    code = 'local self, _output = luawa.template, "" _output = _output .. [[' .. code
    --replace <?=vars?>
    code = code:gsub( '<%?=([{},/_\'%[%]%:%.%a%s%d%(%)]+)%s%?>', ']] .. self:toString( %1 ) .. [[' )
    --replace <? to close output, start raw lua
    code = code:gsub( '<%?', ']] ' )
    --replace ?> to stop lua and start output (in table)
    code = code:gsub( '%?>', ' _output = _output .. [[' )
    --close final output and return concat of the table
    code = code .. ' ]] return _output'

    return code
end


--return
return template