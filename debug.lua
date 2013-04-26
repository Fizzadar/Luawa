--[[
    file: debug.lua
    desc: debug
]]
local lua_debug = debug

local debug = {
    config = {},
    logs = {
        messages = {},
        errors = {},
        accesses = {},
        queries = {}
    }
}

function debug:_start()
    --reset the logs
    self.logs = {
        messages = {},
        errors = {},
        accesses = {},
        queries = {}
    }
end

--end special end not _end
function debug:__end()
    --include debug?
    if self.config.enabled then
        local template = luawa.template

        --add logs + template data
        local data = template:get()
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