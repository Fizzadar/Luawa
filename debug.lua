luawa.debug = {
    config = {
        log_message = false,
        log_error = false
    }
}

--basic debug message
function luawa.debug:message( message )
    print( '[Lua-WA]: ' .. tostring( message ) )
    --log?
    if self.config.log_message then
        self:log( 'message', message )
    end
end

--basic error message
function luawa.debug:error( message )
    print( '[Lua-WA Error]: ' .. tostring( message ) )
    --log?
    if self.config.log_error then
        self:log( 'error', message )
    end
end

--log to file
function luawa.debug:log( type, message )
end