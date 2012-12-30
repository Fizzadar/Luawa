--[[
    file: debug.lua
    desc: debug
]]--
luawa.debug = {
    config = {
        silent = false,
        log = false,
        log_dir = 'logs/'
    },
    log_files = {}
}

--end function (close open log files)
function luawa.debug:_end()
    for k, v in pairs( self.log_files ) do
        v:close()
    end
end

--basic debug message
function luawa.debug:message( message )
    if not self.config.silent and not self.config.silent_message then
        print( '[Lua-WA]: [' .. os.date( '%H:%M' ) ..  '] ' .. tostring( message ) )
    end

    --log?
    if self.config.log and self.config.log_message then
        self:log( 'message', message )
    end
end

--basic error message
function luawa.debug:error( message )
    if not self.config.silent and not self.config.silent_error then
        print( '[Lua-WA Error]: [' .. os.date( '%H:%M' ) ..  '] ' .. tostring( message ) )
    end

    --log?
    if self.config.log and self.config.log_error then
        self:log( 'error', message )
    end
end

--access message
function luawa.debug:access( message, request )
    if type( request ) == 'table' then
        message = message .. 'URL: ' .. request.hostname .. '/' .. request.path .. ' / IP: ' .. request.user_ip .. ' / UserAgent: ' .. tostring( request.user_agent )
    end

    if not self.config.silent and not self.config.silent_access then
        print( '[Lua-WA Access]: [' .. os.date( '%c' ) ..  '] ' .. tostring( message ) )
    end

    --log?
    if self.config.log and self.config.log_access then
        self:log( 'access', message )
    end
end

--log to file
function luawa.debug:log( key, message )
    --if we haven't already opened this file
    if self.log_files[key] == nil then
        self.log_files[key] = io.open( self.config.log_dir .. key .. '.log', 'a+' ) or false
    end
    --now we have the file, write
    if self.log_files[key] then
        self.log_files[key]:write( message .. "\n" )
    end
end