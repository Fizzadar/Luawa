luawa.template = {}

function luawa.template:load( content )
    local luahtml = require( 'luahtml' )

    luawa.response.content = luawa.response.content .. content .. luahtml.open( 'app/template/test.lua' )


end