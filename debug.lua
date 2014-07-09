-- Luawa
-- File: debug.lua
-- Desc: helps debug & profile Luawa apps

local pairs = pairs
local table = table
local type = type
local tostring = tostring
local tonumber = tonumber
local lua_debug = debug

local ffi = require('ffi')
local luawa = require('luawa.core')


--many thanks to John Graham-Cumming's lulip lua profiler:
--https://github.com/jgrahamc/lulip
ffi.cdef([[
  typedef long time_t;

  typedef struct timeval {
    time_t tv_sec;
    time_t tv_usec;
  } timeval;

  int gettimeofday(struct timeval* t, void* tzp);
]])
local gettimeofday_struct = ffi.new('timeval')
local function gettimeofday()
   ffi.C.gettimeofday(gettimeofday_struct, nil)
   return tonumber(gettimeofday_struct.tv_sec) * 1000000 + tonumber(gettimeofday_struct.tv_usec)
end

local debug = {
    config = {}
}

-- Request start
function debug:_start()
    --reset the logs
    ngx.ctx.logs = {
        messages = {},
        errors = {},
        accesses = {},
        queries = {}
    }

    if self.config.enabled then
        ngx.ctx.stack = {}
        ngx.ctx.time = gettimeofday()
        ngx.ctx.start_time = ngx.ctx.time

        lua_debug.sethook(function(event, line)
            local time = gettimeofday()
            local time_diff = (time - ngx.ctx.time) / 1000

            local info = lua_debug.getinfo(2)
            local a, b, path = info.source:find('^@' .. luawa.root .. '([^%s]+)$')
            if not path then
                local a, b, func_name = info.source:find('\n--luawa_file:([^\n]+)')
                path = func_name and func_name .. '.lhtml' or 'unknown'
            end

            if ngx.ctx.stack[path] then
                ngx.ctx.stack[path].lines = ngx.ctx.stack[path].lines + 1
                ngx.ctx.stack[path].time = ngx.ctx.stack[path].time + time_diff
                local func_name = info.name or 'unknown'
                if not ngx.ctx.stack[path].funcs[func_name] then
                    ngx.ctx.stack[path].funcs[func_name] = { lines = 1, time = time_diff }
                else
                    ngx.ctx.stack[path].funcs[func_name].lines = ngx.ctx.stack[path].funcs[func_name].lines + 1
                    ngx.ctx.stack[path].funcs[func_name].time = ngx.ctx.stack[path].funcs[func_name].time + time_diff
                end
                if not ngx.ctx.stack[path].line_counts[line] then
                    ngx.ctx.stack[path].line_counts[line] = { count = 1, time = time_diff }
                else
                    ngx.ctx.stack[path].line_counts[line].count = ngx.ctx.stack[path].line_counts[line].count + 1
                    ngx.ctx.stack[path].line_counts[line].time = ngx.ctx.stack[path].line_counts[line].time + time_diff
                end
            else
                ngx.ctx.stack[path] = {
                    lines = 1,
                    time = time_diff,
                    funcs = { [info.name or 'unknown'] = { lines = 1, time = time_diff }},
                    line_counts = {}
                }
            end

            ngx.ctx.time = gettimeofday()
        end, 'l')
    end
end

-- End
function debug:_end()
    if ngx.ctx.debug_ended then return end
    ngx.ctx.debug_ended = true

    --include debug?
    if self.config.enabled then
        --first work out total request time (including most debug stuff)
        local all_time = (gettimeofday() - ngx.ctx.start_time) / 1000

        --remove debug hook
        lua_debug.sethook()
        local template = luawa.template

        --work out stack
        local stack, app_time, luawa_time = {}, 0, 0
        for file, data in pairs(ngx.ctx.stack) do
            if file:find('^luawa/[^%/]+%.lua$') then
                for name, func in pairs(data.funcs) do
                    if name ~= 'unknown' then
                        luawa_time = luawa_time + func.time
                    end
                end
            end

            local funcs = {}
            for k, v in pairs(data.funcs) do
                table.insert(funcs, { name = k, lines = v.lines, time = v.time })
            end
            table.sort(funcs, function(a, b) return a.time > b.time end)
            data.funcs = funcs

            local line_counts = {}
            for k, v in pairs(data.line_counts) do
                table.insert(line_counts, { line = k - 1, count = v.count, time = v.time })
            end
            table.sort(line_counts, function(a, b) return a.time > b.time end)
            data.line_counts = line_counts

            table.insert(stack, { file = file, data = data })
            app_time = app_time + data.time
        end
        table.sort(stack, function(a, b) return a.data.time > b.data.time end)
        --work out how long debug took
        local debug_time = all_time - app_time - luawa_time

        --count caches
        local cached_templates, cached_files = 0, 0
        if luawa.cache then
            for _, _ in pairs(luawa.cache) do
                cached_files = cached_files + 1
            end
            for _, _ in pairs(luawa.template.cache) do
                cached_templates = cached_templates + 1
            end
        end

        --add logs, then template data, then stack
        template:set('debug_data', luawa.utils.table_copy(ngx.ctx.data))
        template:set('debug_logs', ngx.ctx.logs)
        template:set('debug_stack', stack)
        template:set('debug_app_time', app_time, true)
        template:set('debug_luawa_time', luawa_time, true)
        template:set('debug_debug_time', debug_time, true)
        template:set('debug_request_time', app_time + luawa_time, true)
        template:set('debug_cached_files', cached_files)
        template:set('debug_cached_templates', cached_templates)

        --versions
        local a, b, v1, v2, v3 = tostring(ngx.config.nginx_version):find('([1-9]*)[0]*([1-9]+)[0]+([1-9]+)')
        v1 = v1:len() > 0 and v1 or 0
        v2 = v2:len() > 0 and v2 or 0
        template:set('nginx_version', v1 .. '.' .. v2 .. '.' .. v3, true)
        local a, b, v1, v2, v3 = tostring(ngx.config.ngx_lua_version):find('([1-9]*)[0]*([1-9]+)[0]+([1-9]+)')
        v1 = v1:len() > 0 and v1 or 0
        v2 = v2:len() > 0 and v2 or 0
        template:set('nginx_lua_version', v1 .. '.' .. v2 .. '.' .. v3, true)

        --load debug template
        local old_dir, old_minimize = template.config.dir, template.config.minimize
        template.config.dir = 'luawa'
        template.config.minimize = false
        template:load('debug')
        template.config.dir, template.config.minimize = old_dir, old_minimize
    end
end

-- Basic debug message
function debug:message(message)
    if self.config.enabled then
        table.insert(ngx.ctx.logs.messages, { text = message })
    end
end

-- Basic error message
function debug:error(message)
    if self.config.enabled then
        table.insert(ngx.ctx.logs.errors, { text = message, stack = lua_debug.traceback() })
    end
end

-- Query message
function debug:query(message)
    if self.config.enabled then
        table.insert(ngx.ctx.logs.queries, { text = message })
    end
end

-- Access message
function debug:access(message, request)
    if type(request) == 'table' then
        message = message .. 'URL: ' .. request.hostname .. request.path .. ' / IP: ' .. request.user_ip .. ' / UserAgent: ' .. tostring(request.user_agent)
    end

    if self.config.enabled then
        table.insert(ngx.ctx.logs.messages, { text = message })
    end
end

return debug
