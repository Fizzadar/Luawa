--[[
    file: database.lua
    desc: database abstraction/management
]]
local pairs = pairs
local type = type
local tostring = tostring
local ngx = ngx
local mysql = require( luawa.root_dir .. 'luawa/lib/mysql' )

local database = {
    config = {
        prefix = ''
    }
}

--initialization
function database:_start()
    --utils
    self.utils = luawa.utils

    --memcaching?
    if self.config.memcache then
        --sync
    end
end

--end
function database:_end()
    if self.db then
        self.db:close()
        self.db = nil
    end
end

--clean table data (wheres or values) <= only things with user input
function database:escape( data )
    if not self:connect() or type( data ) ~= 'table' then return {} end

    local clean_data = {}
    for k, v in pairs( data ) do
        if type( v ) == 'table' then
            clean_data[k] = self:escape( v )
        else
            clean_data[k] = ngx.quote_sql_str( v )
        end
    end

    return clean_data
end

--connect to the database
function database:connect()
    --already connected?
    if self.db then return true end

    --environment
    local db, err = mysql:new()
    if not db then return false, 'failed to start driver: ' .. err end

    --connection
    local ok, err = db:connect( {
        host = self.config.host,
        port = self.config.port,
        user = self.config.user,
        password = self.config.pass,
        database = self.config.name
    } )
    if not ok then return false, 'failed to connect to database: ' .. err end

    --assign to self
    self.db = db

    return true
end

--run a manual/raw query
function database:query( sql )
    --check we're connected already
    if not self.db then
        local status, err = self:connect()
        if not status then return false, err end
    end

    --run query
    local data, err = self.db:query( sql )

    --borked sql?
    if not data then
        luawa.debug:error( 'Mysql error: ' .. err .. '\n' .. sql )
        return {}, err
    end

    --message
    luawa.debug:query( sql )

    --table returned?
    if type( data ) == 'table' then
        self.numrows = #data
    end

    --return results
    return data
end

--get number of rows from last query
function database:numRows()
    if not self.numrows then return false end
    return self.numrows
end

--run a select request (build query + run)
function database:select( table, fields, wheres, order, limit, offset )
    local sql

    --escape wheres
    wheres = self:escape( wheres )

    --table & fields
    sql = 'SELECT ' .. fields .. ' FROM ' .. self.config.prefix .. table .. '\n'
    --wheres
    sql = sql .. 'WHERE true' .. '\n'
    for k, v in pairs( wheres ) do
        if type( v ) == 'table' then
            sql = sql .. 'AND ('
            for c, d in ipairs( v ) do
                sql = sql .. '`' .. k .. '` = ' .. d .. ' OR\n'
                v[c] = nil
            end
            for c, d in pairs( v ) do
                sql = sql .. '`' .. c .. '` = ' .. d .. ' OR\n'
            end
            sql = self.utils.rtrim( sql, 'OR\n' )
            sql = sql .. ') '
        else
            sql = sql .. 'AND `' .. k .. '` = ' .. v .. '\n'
        end
    end
    --order
    if order then sql = sql .. 'ORDER BY ' .. order .. ' ' end
    --limit
    if limit then sql = sql .. 'LIMIT ' .. limit end
    --offset
    if offset then sql = sql .. ' OFFSET ' .. offset end

    return self:query( sql )
end

--run a delete request
function database:delete( table, wheres )
    local sql

    --escape input wheres
    wheres = self:escape( wheres )

    --table
    sql = 'DELETE FROM ' .. self.config.prefix .. table .. ' '
    --wheres
    sql = sql .. 'WHERE true' .. ' '
    for k, v in pairs( wheres ) do
        sql = sql .. 'AND `' .. k .. '` = ' .. v .. ' '
    end

    return self:query( sql )
end

--run a update request
function database:update( table, values, wheres )
    local sql

    --escape input wheres & values
    wheres = self:escape( wheres )
    values = self:escape( values )

    --table
    sql = 'UPDATE ' .. self.config.prefix .. table .. ' '
    --sets
    sql = sql .. 'SET '
    for k, v in pairs( values ) do
        sql = sql .. '`' .. k .. '` = ' .. v .. ', '
    end
    sql = self.utils.rtrim( sql, ', ' ) --clear last ,
    --wheres
    sql = sql .. ' WHERE true' .. ' '
    for k, v in pairs( wheres ) do
        sql = sql .. 'AND `' .. k .. '` = ' .. v .. ' '
    end

    return self:query( sql )
end

--run a insert request
function database:insert( table, fields, values )
    local sql, value

    --escape input values
    values = self:escape( values )

    --table
    sql = 'INSERT INTO ' .. self.config.prefix .. table .. ' '
    --fields
    sql = sql .. '( '
    for k, v in pairs( fields ) do
        sql = sql .. '`' .. v .. '`, '
    end
    sql = self.utils.rtrim( sql, ', ' ) --clear last ,
    sql = sql .. ' ) VALUES '
    --values
    for k, v in pairs( values ) do
        value = '( '
        for c, d in pairs( v ) do
            value = value .. d .. ', '
        end
        value = self.utils.rtrim( value, ', ' ) --clear last ,
        sql = sql .. value .. ' ), '
    end
    sql = self.utils.rtrim( sql, ', ' ) --clear last ,

    return self:query( sql )
end

--run a search request
function database:search( table, fields )
    local sql

    return self:query( sql )
end



return database


--[[
    possible feature later:
    implement memcache on top of db
    sync upon luawa start, gets all db records into memcache servers
    from then on all updates/deletes/inserts will edit both db and database
    select & search will only ever use memcache
]]