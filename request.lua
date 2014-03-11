-- Luawa
-- File: request.lua
-- Desc: holds/prepares request data (gets & posts)

local setmetatable = setmetatable
local ngx = ngx

local request = {}

-- Init
function request:_init()
    self.utils = luawa.utils
end

-- Start
function request:_start()
    --bind .get => ngx uri args
    local mt = {
        __index = function( table, key )
            local args = ngx.req.get_uri_args()
            return args[key]
        end
    }
    self.get = {}
    setmetatable( self.get, mt )

    --read post data/args
    ngx.req.read_body()
    --bind .post => ngx post args
    local mt = {
        __index = function( table, key )
            local args = ngx.req.get_post_args( luawa.limit_post )
            return args[key]
        end
    }
    self.post = {}
    setmetatable( self.post, mt )

    --bind .other_bits
    local mt = {
        __index = function( table, key )
            if key == 'method' then
                return ngx.req.get_method()
            end
            if key == 'hostname' or key == 'hostport' then
                local header = ngx.req.get_headers().host
                local a, b, host, port = header:find( '^([^:]+):([0-9]+)$' )
                return key == 'hostname' and host or port
            end
            if key == 'remote_addr' then
                return ngx.var.remote_addr
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