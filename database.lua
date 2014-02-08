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
    --sometimes when caching below nil assignment fails?
    self.db = nil
end

--end
function database:_end()
    --prevent 'Mysql error: failed to send query: closed' when caching
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
    local ok, err = db:connect({
        host = self.config.host,
        port = self.config.port,
        user = self.config.user,
        password = self.config.pass,
        database = self.config.name
    })
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
    local where_bits = {}

    if wheres then
        --where
        wheres = self:escape( wheres )
        --loop them
        for k, v in pairs( wheres ) do
            if v.sign and v[1] then
                v.sign = self.utils.trim( v.sign, '%\'' )
                table.insert( where_bits, '`' .. k .. '` ' .. v.sign .. ' ' .. v[1] .. '\n' )
            elseif type( v ) ~= 'table' then
                table.insert( where_bits, '`' .. k .. '` = ' .. v .. '\n' )
            else
                local bits, string = {}, '('
                for c, d in ipairs( v ) do
                    table.insert( bits, '`' .. k .. '` = ' .. d )
                    v[c] = nil
                end
                for c, d in pairs( v ) do
                    table.insert( bits, '`' .. c .. '` = ' .. d )
                end
                string = string .. table.concat( bits, ' OR ' ) .. ')\n'
                table.insert( where_bits, string )
            end
        end
    end

    if #where_bits > 0 then
        return 'WHERE ' .. table.concat( where_bits, ' AND ' )
    end

    return ''
end

--run a select request (build query + run)
function database:select( table_name, fields, wheres, options )
    options = options or {}
    local sql

    --table & fields
    local fields = type( fields ) == 'table' and '`' .. table.concat( fields, '`, `' ) .. '`' or '*'
    sql = 'SELECT ' .. fields .. ' FROM ' .. self.config.prefix .. table_name .. '\n'

    --wheres
    sql = sql .. self:wheresToSql( wheres )

    --group
    if options.group then sql = sql .. ' GROUP BY ' .. options.group end
    --order
    if options.order then sql = sql .. ' ORDER BY ' .. options.order end
    --limit
    if options.limit then sql = sql .. ' LIMIT ' .. options.limit end
    --offset
    if options.offset then sql = sql .. ' OFFSET ' .. options.offset end

    return self:query( sql )
end

--run a delete request
function database:delete( table_name, wheres, limit )
    local sql

    --table
    sql = 'DELETE FROM ' .. self.config.prefix .. table_name .. ' '

    --wheres
    sql = sql .. self:wheresToSql( wheres )

    --limit
    if limit then sql = sql .. ' LIMIT ' .. limit end

    return self:query( sql )
end

--run a update request
function database:update( table_name, values, wheres )
    local sql

    --escape input values
    values = self:escape( values )

    --table
    sql = 'UPDATE ' .. self.config.prefix .. table_name .. ' '
    --sets
    sql = sql .. 'SET '
    local bits = {}
    for k, v in pairs( values ) do
        table.insert( bits, '`' .. k .. '` = ' .. v )
    end
    sql = sql .. table.concat( bits, ', ' )

    --wheres
    sql = sql .. self:wheresToSql( wheres )
    return self:query( sql )
end

--run a insert request
function database:insert( table_name, fields, values, options )
    options = options or {}
    local sql, value
    local cmd = 'INSERT'
    if options.replace then cmd = 'REPLACE' end
    if options.delayed then cmd = 'INSERT DELAYED' end

    --escape input values
    values = self:escape( values )

    --table
    sql = cmd .. ' INTO ' .. self.config.prefix .. table_name .. ' '
    --fields
    sql = sql .. '( `' .. table.concat( fields, '`, `' ) .. '` ) VALUES '
    --values
    local bits = {}
    for k, v in pairs( values ) do
        table.insert( bits, '( ' .. table.concat( v, ', ' ) .. ' )' )
    end
    sql = sql .. table.concat( bits, ', ' )

    return self:query( sql )
end

--run a search request
function database:search( table_name, search_fields, fetch_fields, query )
    local sql

    sql = 'SELECT (MATCH(' .. search_fields .. ') AGAINST("' .. query .. '")) AS score, ' .. fetch_fields .. ' FROM ' .. self.config.prefix .. table_name .. '\n'
    sql = sql .. 'WHERE (MATCH(' .. search_fields .. ') AGAINST("' .. query .. '")) > 0'

    return self:query( sql )
end



return database