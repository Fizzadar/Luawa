--[[
    file: email.lua
    desc: email sending
]]
local smtp = require( 'luawa/lib/smtp' )

local email = {
    config = {
        server = '127.0.0.1',
        port = 25,
        user = 'root',
        pass = 'root',
        from = 'luawa@127.0.0.1'
    }
}


--send an email (message can be a table { html='', plain='' } )
function email:send( to, subject, message, from )
    --create smtp object if needed
    if not self.smtp then self.smtp = smtp:new() end
    --from?
    if not from then from = self.config.from end

    --build the message!
    local message = {
        server = self.config.server,
        username = self.config.user,
        password = self.config.pass,
        ident = luawa.hostname,
        headers = {
            to = to,
            from = from,
            subject = subject
        },
        body = message
    }

    --send the message
    return self.smtp:send( message )
end

return email