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
    --cache static content in memory (browsers told to cache for 24h)
    cache_static = true,
    --expires http header (only used where cache_static is false)
    expire_static = 3600,

    --get requests (map path => file [which can change if logged in])
    gets = {
        { path = '/', file = 'app/get/home', func = 'some string' }, --home
        --%d+, etc will match to args when set
        { path = '/(%d+)', file = 'app/test', args = { 'test' } }
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
        port_ssl = 8081,
        port_admin = 9000,
        ip = '*',
        name = 'looahwa', --just server name header
        lanes = 10, --lanes process requests, beware of # physical cores available! But also remember mysql/etc will BLOCK on lanes
        debug = false, --dumps raw socket input and also the request/reponse tables
        --ssl parameters
        ssl_params = {
            key = 'app/ssl/yummy.key',
            certificate = 'app/ssl/yummy.cer'
        },
    },

    --debug
    debug = {
        --messages
        silent = true, --overrides
        silent_access = false,
        silent_message = false,
        silent_error = false,
        --logging
        log_dir = 'logs/',
        log = false, --overrides
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
        api_host = 'api.website.com',
        --writes generated template code to console
        debug = false
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
        pass = 'root',
        --table prefix
        prefix = 'db_'
    },

    --user
    user = {
        --cookie prefix
        prefix = 'luawa_',
        --login time
        expire = 3600,
        --new auth key each login/logout? (multiple devices will log each other out - can be secure but annoying)
        reload_key = false
    },

    --admin
    admin = {
        enabled = true
    }
}
--return the config array
return config