--luawa modules
local database = luawa.database

--clean a table of strings (values converted to string)
database:clean( { '"; DELETE * FROM table', 'another var' } )

--normal raw query (NOT escaped, see above)
database:query( 'SELECT * FROM user' )

--test select
database:select(
	'bookmark', '*', --table & fields
	{ user_id = 1 }, --wheres
	'time DESC', 30 --order, limit & offset
)

--test delete
database:delete(
	'bookmark', --table
	{ user_id = 1, id = 2 } --wheres
)

--test update
database:update(
	'bookmark', --table
	{ url = 'fuckyou', tags = 'testtags' }, --fields
	{ id = 1, title = 'Googl' } --wheres
)

--test insert
database:insert(
	'bookmark', --table
	{ 'user_id', 'favorite', 'star', 'url', 'base_url', 'tags', 'time' }, --fields
	{
		{ 1, 1, 1, 'http://favorite', 'favorite and star', 'tags', 1294828 },
		{ 2, 0, 0, 'http://nonfav', 'http://something', 'thi is ', 288 },
		{ 2, 0, 0, 'http://nonfav', 'http://something', 'thi is ', 288 }
	} -- ^ values ^
)