-- Luawa
-- File: debug.lua
-- Desc: helps debug & profile Luawa apps

local tonumber = tonumber
local lua_debug = debug
local ffi = require( 'ffi' )

--many thanks to John Graham-Cumming's lulip lua profiler:
--https://github.com/jgrahamc/lulip
ffi.cdef([[
  typedef long time_t;

  typedef struct timeval {
    time_t tv_sec;
    time_t tv_usec;
  } timeval;

  int gettimeofday(struct timeval* t, void* tzp);
]])
local gettimeofday_struct = ffi.new( 'timeval' )
local function gettimeofday()
   ffi.C.gettimeofday( gettimeofday_struct, nil )
   return tonumber( gettimeofday_struct.tv_sec ) * 1000000 + tonumber( gettimeofday_struct.tv_usec )
end

local debug = {
    config = {},
    logs = {
        messages = {},
        errors = {},
        accesses = {},
        queries = {}
    }
}

-- Request start
function debug:_start()
    self.stack = {}
    self.time = gettimeofday()

    --reset the logs
    self.logs = {
        messages = {},
        errors = {},
        accesses = {},
        queries = {}
    }

    if self.config.enabled then
        lua_debug.sethook( function( event, line )
            local info = lua_debug.getinfo( 2 )

            local a, b, path = info.source:find( '^@%/([^%s]+)$' )
            if path then
                path = path:gsub( luawa.root_dir, '' )
            else
                local a, b, func_name = info.source:find( '^local function _([%w_]+)' )
                path = func_name and func_name:gsub( '_', '/' ) .. '.lua' or 'unknown'
            end

            local time = gettimeofday()
            local time_diff = ( time - self.time ) / 1000
            self.time = time

            if self.stack[path] then
                self.stack[path].lines = self.stack[path].lines + 1
                self.stack[path].time = self.stack[path].time + time_diff
                local func_name = info.name or 'unknown'
                if not self.stack[path].funcs[func_name] then
                    self.stack[path].funcs[func_name] = { lines = 1, time = time_diff }
                else
                    self.stack[path].funcs[func_name].lines = self.stack[path].funcs[func_name].lines + 1
                    self.stack[path].funcs[func_name].time = self.stack[path].funcs[func_name].time + time_diff
                end
            else
                local funcs = {}
                funcs[info.name or 'unknown'] = { lines = 1, time = time_diff }
                self.stack[path] = {
                    lines = 1,
                    time = time_diff,
                    funcs = funcs
                }
            end
        end, 'l' )
    end
end

-- Special request end after normal _end's
function debug:__end()
    --include debug?
    if self.config.enabled then
        lua_debug.sethook()
        local template = luawa.template

        --work out stack
        local stack, total_time, luawa_time = {}, 0, 0
        for file, data in pairs( self.stack ) do
            if file:find( '^luawa/[^%/]+%.lua$' ) then
                for name, func in pairs( data.funcs ) do
                    if name ~= 'unknown' then
                        luawa_time = luawa_time + func.time
                    end
                end
            end
            table.insert( stack, { file = file, data = data } )
            total_time = total_time + data.time
        end
        table.sort( stack, function( a, b ) return a.data.time > b.data.time end )

        --add logs, then template data, then stack
        template:set( 'debug_data', luawa.utils.tableCopy( template.data ) )
        template:set( 'debug_logs', self.logs, true )
        template:set( 'debug_stack', stack, true )
        template:set( 'debug_total_time', total_time, true )
        template:set( 'debug_luawa_time', luawa_time, true )

        --versions
        local a, b, v1, v2, v3 = tostring( ngx.config.nginx_version ):find( '([1-9]*)[0]*([1-9]+)[0]+([1-9]+)' )
        v1 = v1:len() > 0 and v1 or 0
        v2 = v2:len() > 0 and v2 or 0
        template:set( 'nginx_version', v1 .. '.' .. v2 .. '.' .. v3, true )
        local a, b, v1, v2, v3 = tostring( ngx.config.ngx_lua_version ):find( '([1-9]*)[0]*([1-9]+)[0]+([1-9]+)' )
        v1 = v1:len() > 0 and v1 or 0
        v2 = v2:len() > 0 and v2 or 0
        template:set( 'nginx_lua_version', v1 .. '.' .. v2 .. '.' .. v3, true )

        --load debug template
        local old_dir, old_minimize = template.config.dir, template.config.minimize
        template.config.dir = 'luawa/'
        template.config.minimize = false
        template:load( 'debug' )
        template.config.dir, template.config.minimize = old_dir, old_minimize
    end
end

-- Basic debug message
function debug:message( message )
    if self.config.enabled then
        table.insert( self.logs.messages, { text = message } )
    end
end

-- Basic error message
function debug:error( message )
    if self.config.enabled then
        table.insert( self.logs.errors, { text = message, stack = lua_debug.traceback() } )
    end
end

-- Query message
function debug:query( message )
    if self.config.enabled then
        table.insert( self.logs.queries, { text = message } )
    end
end

-- Access message
function debug:access( message, request )
    if type( request ) == 'table' then
        message = message .. 'URL: ' .. request.hostname .. request.path .. ' / IP: ' .. request.user_ip .. ' / UserAgent: ' .. tostring( request.user_agent )
    end

    if self.config.enabled then
        table.insert( self.logs.messages, { text = message } )
    end
end


return debug