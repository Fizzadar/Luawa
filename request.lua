-- Luawa
-- File: request.lua
-- Desc: holds/maps to request data (request.get & request.post)

local ngx = ngx

local request = {}

-- Start
function request:_start()
    --bind .get to ngx.req function
    local mt = {
        __index = function( table, key )
            local args = ngx.req.get_uri_args()
            return args[key]
        end
    }
    self.get = {}
    setmetatable( self.get, mt )

    --prepare post args
    ngx.req.read_body()
    --bind .post to ngx.req function
    local mt = {
        __index = function( table, key )
            local args = ngx.req.get_post_args( luawa.limit_post )
            return args[key]
        end
    }
    self.post = {}
    setmetatable( self.post, mt )

    --bind .basics
    local mt = {
        __index = function( table, key )
            if key == 'method' then
                return ngx.req.get_method()
            end
        end
    }
    setmetatable( self, mt )
end

-- Get all GETs
function request:gets()
    return ngx.req.get_uri_args()
end

-- Get all POSTs
function request:posts()
    return ngx.req.get_post_args()
end

return request