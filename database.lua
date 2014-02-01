-- File: database.lua
-- Desc: connects to the database!

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

    --return results (data.insert_id, data.affected_rows and #data)
    return data
end

function database:wheresToSql( wheres )
    local where = ''
    if wheres then
        --where
        wheres = self:escape( wheres )
        --loop them
        for k, v in pairs( wheres ) do
            if type( v ) == 'table' then
                where = where .. 'AND ('
                for c, d in ipairs( v ) do
                    where = where .. '`' .. k .. '` = ' .. d .. ' OR '
                    v[c] = nil
                end
                for c, d in pairs( v ) do
                    where = where .. '`' .. c .. '` = ' .. d .. ' OR '
                end
                where = self.utils.trimRight( where, 'OR ' )
                where = where .. ')\n'
            else
                where = where .. 'AND `' .. k .. '` = ' .. v .. '\n'
            end
        end
        if where ~= '' then
            where = 'WHERE\n' .. self.utils.trimLeft( where, 'AND' )
        end
    end

    return where
end

--run a select request (build query + run)
function database:select( table, fields, wheres, order, limit, offset, group )
    local sql

    --table & fields
    sql = 'SELECT ' .. fields .. ' FROM ' .. self.config.prefix .. table .. '\n'

    --wheres
    sql = sql .. self:wheresToSql( wheres )

    --group
    if group then sql = sql .. ' GROUP BY ' .. group end
    --order
    if order then sql = sql .. ' ORDER BY ' .. order end
    --limit
    if limit then sql = sql .. ' LIMIT ' .. limit end
    --offset
    if offset then sql = sql .. ' OFFSET ' .. offset end

    return self:query( sql )
end

--run a delete request
function database:delete( table, wheres, limit )
    local sql

    --table
    sql = 'DELETE FROM ' .. self.config.prefix .. table .. ' '

    --wheres
    sql = sql .. self:wheresToSql( wheres )

    --limit
    if limit then sql = sql .. ' LIMIT ' .. limit end

    return self:query( sql )
end

--run a update request
function database:update( table, values, wheres )
    local sql

    --escape input values
    values = self:escape( values )

    --table
    sql = 'UPDATE ' .. self.config.prefix .. table .. ' '
    --sets
    sql = sql .. 'SET '
    for k, v in pairs( values ) do
        sql = sql .. '`' .. k .. '` = ' .. v .. ', '
    end
    sql = self.utils.trimRight( sql, ', ' ) --clear last ,

    --wheres
    sql = sql .. self:wheresToSql( wheres )

    return self:query( sql )
end

--run a insert request
function database:insert( table, fields, values, replace )
    local sql, value
    local cmd = 'INSERT'
    if replace then cmd = 'REPLACE' end

    --escape input values
    values = self:escape( values )

    --table
    sql = cmd .. ' INTO ' .. self.config.prefix .. table .. ' '
    --fields
    sql = sql .. '( '
    for k, v in pairs( fields ) do
        sql = sql .. '`' .. v .. '`, '
    end
    sql = self.utils.trimRight( sql, ', ' ) --clear last ,
    sql = sql .. ' ) VALUES '
    --values
    for k, v in pairs( values ) do
        value = '( '
        for c, d in pairs( v ) do
            value = value .. d .. ', '
        end
        value = self.utils.trimRight( value, ', ' ) --clear last ,
        sql = sql .. value .. ' ), '
    end
    sql = self.utils.trimRight( sql, ', ' ) --clear last ,

    return self:query( sql )
end
--insert/replace request
function database:replace( table, fields, values )
    return self:insert( table, fields, values, true )
end

--run a search request
function database:search( table, search_fields, fetch_fields, query )
    local sql

    sql = 'SELECT (MATCH(' .. search_fields .. ') AGAINST("' .. query .. '")) AS score, ' .. fetch_fields .. ' FROM ' .. self.config.prefix .. table .. '\n'
    sql = sql .. 'WHERE (MATCH(' .. search_fields .. ') AGAINST("' .. query .. '")) > 0'

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