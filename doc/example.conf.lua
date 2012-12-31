--example config file
-- normally stored out of lua-wa directory
local config = {

    ------- Core
    ---

    --re-include luawa modules & config every request
    dev_mode = true,

    --cache compiled app files (reload needed for app changes) -- does NOT affect template caching
    cache_app = false,

    --deal with static content?
    serve_static = true,
    cache_static = true,

    --get requests (map path => file [which can change if logged in])
    gets = {
        { path = '/', file = 'app/get/home', func = 'some string' }, --home
    },

    --post requests (as above)
    posts = {
        { path = '/post/settings', file = 'app/post/settings', func = 'settings' }, --set my settings
    },



    ------- Modules
    ---

    --server
    server = {
        port = 8080,
        ip = '*',
        name = 'looahwa',
        lanes = 10
    },

    --debug
    debug = {
        --messages
        silent = false,
        silent_access = true,
        silent_message = false,
        silent_error = false,
        --logging
        log_dir = 'logs/',
        log_message = false,
        log_error = false,
        log_access = false
    },

    --template
    template = {
        dir = 'app/template/',
        --cache template files (as functions)
        cache = false,
        --api mode (requests with api host output template content as json, and skips the actual templates)
        api = true,
        api_host = 'api.website.com'
    },

    --database
    database = {
        --mysql or nothing, will have postgres
        driver = 'mysql',
        --basic info
        host = '127.0.0.1',
        port = 3306,
        name = 'website',
        user = 'root',
        pass = 'root'
    },

    --admin
    admin = {
        enabled = true
    }
}
--return the config array
return config