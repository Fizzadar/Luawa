-- Luawa
-- File: template.lua
-- Desc: lhtml templating

local tostring = tostring
local pcall = pcall
local loadstring = loadstring
local type = type
local table = table
local io = io
local ngx = ngx

local template = {
    config = {
        dir = ''
    },
    cache = {}
}

-- Init
function template:_init()
    self.utils = luawa.utils
    self.session = luawa.session
end

-- Start function
function template:_start()
    ngx.ctx.data = {}

    --now token is generated, add to template (not API)
    self:set( 'token', self.session:getToken() )
end

-- End function
function template:_end()
    --if api request output template data as json
    if ngx.ctx.api then
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
        self:set( 'messages', luawa.session:getMessages(), true )
        local out, err = self.utils.jsonEncode( ngx.ctx.data )
        if out then
            ngx.ctx.response = out
        else
            ngx.ctx.response = self.utils.jsonEncode({ error = err })
        end
    end
end

-- Set data
function template:set( key, value, api )
    --not api or api enabled
    if not self.api or api then
        ngx.ctx.data[key] = value
    end
end

-- Add data (makes table value must be table)
function template:add( key, value, api )
    if not self.api or api then
        if not ngx.ctx.data[key] then
            ngx.ctx.data[key] = {}
        elseif type( ngx.ctx.data[key] ) ~= 'table' then
            ngx.ctx.data[key] = { ngx.ctx.data[key] }
        end

        for k, v in pairs( value ) do
            table.insert( ngx.ctx.data[key], v )
        end
    end
end

-- Get data (dump all when no key)
function template:get( key )
    if not key then return ngx.ctx.data end
    return ngx.ctx.data[key]
end

-- Clear data
function template:clear()
    ngx.ctx.data = {}
end

-- Set api on/off
function template:setApi( bool )
    ngx.ctx.api = bool
end

-- Add raw code to current output
function template:put( content )
    if self.api then return end

    ngx.ctx.response = ngx.ctx.response .. tostring( content )
end

-- Load a lhtml file, convert code to lua, run and add string to end of response.content
function template:load( file, inline )
    if self.api then return true end
    local cache = luawa.cache

    --try cache
    if cache and self.cache[file] then
        return self:processFunction( self.cache[file], file )
    end

    --process string lhtml => lua
    string = self:processFile( file )

    --compile our string
    local func, err = loadstring( string )
    if not func then return luawa:error( 500, 'Template: ' .. file .. ' :: ' .. err ) end

    --save if cache
    if cache then
        self.cache[file] = func
    end

    --run it
    return self:processFunction( func, file )
end

-- Run a function
function template:processFunction( func, file )
    --call the function safely
    local status, err = pcall( func )

    --if ok, add to output
    if status then
        if inline then
            return err
        else
            ngx.ctx.response = ngx.ctx.response .. err
            return true
        end
    else
        return luawa:error( 500, 'Template: ' .. ( file or 'unkown' ) .. ' :: ' .. err )
    end
end


--function to work before tostring
function template:toString( string )
    --nil returns blank
    if string == nil then return '' end
    --string as string
    if type( string ) == 'string' then return self.utils.htmlEnts( string ) end
    --otherwise as best
    return tostring( string )
end
--turn file => lua
function template:processFile( file )
    --read template file
    local f, err = io.open( self.config.dir .. file .. '.lhtml', 'r' )
    if not f then return luawa:error( 500, 'Template: ' .. file .. ' :: Cant open/access file: ' .. err ) end
    --read the file
    local code, err = f:read( '*a' )
    if not code then return luawa:error( 500, 'Template: ' .. file .. ' :: File read error: ' .. err ) end
    --close file
    f:close()

    --minimize html? will probably break javascript!
    if self.config.minimize then code = code:gsub( '%s+', ' ' ) end

    --prepend bits
    local name = '--luawa_file:' .. file .. '\n'
    code = name .. 'local self, _output = luawa.template, "" _output = _output .. [[' .. code
    --replace <?=vars?>
    code = code:gsub( '<%?=([#{},/_%+\'%[%]%:%.%a%s%d%(%)%*]+)%s%?>', ']] .. self:toString( %1 ) .. [[' )
    --replace <??=vars?>
    code = code:gsub( '<%?%?=([#{},/_%+\'%[%]%:%.%a%s%d%(%)%*]+)%s%?>', ']] .. %1 .. [[' )
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