--[[
    file: debug.lua
    desc: debug
]]
local tonumber = tonumber
local lua_debug, os, ffi = debug, os, require( 'ffi' )

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
    config = {}
}

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
                funcs[info.name or 'unknown'] = { lines = 1, time = time_diff, name = info }
                self.stack[path] = {
                    lines = 1,
                    time = time_diff,
                    funcs = funcs
                }
            end
        end, 'l' )
    end
end

--end special end not _end
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
        template:set( 'debug_logs', self.logs )
        template:set( 'debug_stack', stack )
        template:set( 'debug_total_time', total_time )
        template:set( 'debug_luawa_time', luawa_time )

        --load debug template
        template.config.dir = 'luawa/'
        template.config.minimize = false
        template:load( 'debug' )
    end
end

--basic debug message
function debug:message( message )
    if self.config.enabled then
        table.insert( self.logs.messages, { text = message } )
    end
end

--basic error message
function debug:error( message )
    if self.config.enabled then
        table.insert( self.logs.errors, { text = message, stack = lua_debug.traceback() } )
    end
end

--query message
function debug:query( message )
    if self.config.enabled then
        table.insert( self.logs.queries, { text = message } )
    end
end

--access message
function debug:access( message, request )
    if type( request ) == 'table' then
        message = message .. 'URL: ' .. request.hostname .. request.path .. ' / IP: ' .. request.user_ip .. ' / UserAgent: ' .. tostring( request.user_agent )
    end

    if self.config.enabled then
        table.insert( self.logs.messages, { text = message } )
    end
end



return debug