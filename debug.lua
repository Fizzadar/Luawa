--[[
    file: debug.lua
    desc: debug
]]
local lua_debug, os = debug, os

local debug = {
    config = {},
    logs = {
        messages = {},
        errors = {},
        accesses = {},
        queries = {}
    },
    stack = {}
}

function debug:_start()
    self.time = os.clock()

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
                path = func_name:gsub( '_', '/' ) .. '.lua' or 'unknown'
            end

            local time = os.clock()
            local time_diff = ( os.clock() - self.time ) * 1000
            self.time = time

            if self.stack[path] then
                self.stack[path].line_count = self.stack[path].line_count + 1
                self.stack[path].cpu_time = self.stack[path].cpu_time + time_diff
                local func_name = info.name or 'unknown'
                if not self.stack[path].funcs[func_name] then
                    self.stack[path].funcs[func_name] = 1
                else
                    self.stack[path].funcs[func_name] = self.stack[path].funcs[func_name] + 1
                end
            else
                local funcs = {}
                funcs[info.name or 'unknown'] = 1
                self.stack[path] = {
                    line_count = 1,
                    cpu_time = time_diff,
                    funcs = funcs
                }
            end
        end, 'l' )
    end
end

--end special end not _end
function debug:__end()
    lua_debug.sethook()

    --include debug?
    if self.config.enabled then
        local template = luawa.template

        --work out stack
        local d = {}
        for k, v in pairs( self.stack ) do
            table.insert( d, { file = k, data = v } )
        end
        table.sort( d, function( a, b ) return a.data.cpu_time > b.data.cpu_time end )
        template:set( 'debug_stack', d )

        --add logs + template data
        template:set( 'debug_data', luawa.utils.tableString( template.data ) )
        template:set( 'debug_logs', self.logs )

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