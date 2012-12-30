--[[
    file: database.lua
    desc: database abstraction/management
]]--

--get luasql driver
luasql = require( 'luasql.mysql' )

--start database
luawa.database = {
    env,
    conn,
    config = {}
}

--connect to the database
function luawa.database:connect()
    --environment
    self.env = luasql.mysql()
    if not self.env then return false, 'failed to start driver' end
    --connection
    self.conn = self.env:connect( self.config.name, self.config.user, self.config.pass, self.config.host, self.config.port )
    if not self.conn then return false, 'failed to connect to database' end

    return true
end

--run a manual/raw query
function luawa.database:query( sql )
    --check we're connected already
    if not self.conn then
        local status, err = self:connect()
        if not status then return false, err end
    end

    --run query
    local rows, err = self.conn:execute( sql )
    --borked?
    if not rows then return false, err end

    --built our results table
    local result = {}
    self.numrows = rows:numrows()
    for i = 1, self.numrows do
        result[i] = rows:fetch( {}, 'a' )
    end

    --return results
    return result
end

--get number of rows from last query
function luawa.database:numRows()
    if not self.numrows then return false end
    return self.numrows
end

--run a select request (build query + run)
function luawa.database:select( tables, fields, wheres )
    local sql

    return self:query( sql )
end

--run a delete request
function luawa.database:delete( tables, wheres )
    local sql

    return self:query( sql )
end

--run a update request
function luawa.database:update( tables, fields, wheres )
    local sql

    return self:query( sql )
end

--run a insert request
function luawa.database:insert( tables, fields )
    local sql

    return self:query( sql )
end

--run a search request
function luawa.database:search( tables, fields )
    local sql

    return self:query( sql )
end