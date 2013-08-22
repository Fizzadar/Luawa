--[[
    file: user.lua
    desc: user management, permissions
]]
local pairs, ngx, json = pairs, ngx, require( 'cjson.safe' )

local user = {
	config = {
		prefix = '',
		dbprefix = '',
		expire = 31536000, --1y
		reload_key = false,
		secret = '',
		keys = 1,
		stretching = 1
	}
}

--start
function user:_start()
	self.db, self.head, self.utils, self.email = luawa.database, luawa.header, luawa.utils, luawa.email
end

--end
function user:_end()
	self.user = nil
end

--generate a password from text + salt
function user:generatePassword( password, salt )
	if not password or password == '' then return false end

	--start with salt & secret
	local str = salt .. self.config.secret
	--loop stretching times (increase rainbow table calculation time)
	--each loop inputs the users password
	for i = 1, self.config.stretching do
		str = self.utils.digest( str .. password )
	end
	return str
end

--generate a key
function user:generateKey( entropy )
	return self.utils.digest( entropy .. self.utils.randomString( 32 ) )
end

--reset a password
function user:resetPassword( email )
	--get user in question
	local user = self.db:select(
		self.config.dbprefix .. 'user', '*',
		{ email = email }
	)
	if not ( user and user[1] ) then
		return false, 'No users linked to this email'
	end

	--generate temporary reset key password_reset_key
	local password_reset_key = self:generateKey( self.utils.randomString( 32 ) )

	--add key + time to database
	local status, err = self.db:update(
		self.config.dbprefix .. 'user',
		{
			password_reset_key = password_reset_key,
			password_reset_time = os.time() + 900 --15 mins
		},
		{ id = user[1].id }
	)
	if not status then return false, err end

	--app must send email with key link
	return password_reset_key
end

--process reset password
function user:resetPasswordLogin( email, key )
	--check key+email
	local user = self.db:select(
		self.config.dbprefix .. 'user', '*',
		{ email = email, password_reset_key = key }
	)
	if not ( user and user[1] ) or user[1].password_reset_time < os.time() then
		return false, 'No email/key combination found'
	end

	--remove key+time from database
	local status, err = self.db:update(
		self.config.dbprefix .. 'user',
		{
			password_reset_key = '',
			password_reset_time = 0 --15 mins
		},
		{ id = user[1].id }
	)
	if not status then return false, err end

	--login the user with their OLD/current password, app should redirect to settings/changepw page
	return self:login( email, user[1].password, true )
end

--register a user
function user:register( email, password, name )
	if not name then name = 'Unknown' end
	if password == '' then return false, 'Invalid password' end
	if not self.utils.isEmail( email ) then return false, 'Invalid email' end

	--salt & key
	local salt, key = self.utils.randomString( 32 ), self:generateKey( password )

	--hash password
	password = self:generatePassword( password, salt )

	--default fields & users
	local fields = { 'email', 'password', 'salt', 'name', 'register_time' }
	local user = { email, password, salt, name, os.time() }

	--generate n keys
	for i = 1, self.config.keys do
		table.insert( fields, 'key' .. i )
		table.insert( user, self:generateKey( password ) )
	end

	--insert user
	local result, err = self.db:insert(
		self.config.dbprefix .. 'user',
		fields,
		{ user }
	)

	--success?
	if not err then return true else return false, err end
end

--login a user
function user:login( email, password, hashed )
	--get user
	local user, err = self.db:select(
		self.config.dbprefix .. 'user', '*',
		{ email = email }
	)

	--if user hash the password w/ salt
	if user and user[1] then
		if not hashed then password = self:generatePassword( password, user[1].salt ) end
	else
		return false, err
	end

	--hashed pw == pw from db?
	if user[1].password == password then
		self.user = user[1]

		--data to update
		local update = { login_time = os.time() }

		--reload key?
		if self.config.reload_key then
			for i = 1, self.config.keys do
				local key = self:generateKey( self.utils.randomString( 32 ) )
				self.user['key' .. i] = key
				update['key' .. i] = key
			end
		end

		--update user
		self:setData( update )

		--set key cookies
		for i = 1, self.config.keys do
			self.head:setCookie( self.config.prefix .. 'key' .. i, self.user['key' .. i], self.config.expire )
		end

		return true
	else
		return false, err
	end
end

--logout
function user:logout()
	--reload key before logging out?
	if self.config.reload_key then
		self:setData( { key = self.utils.digest( self.utils.randomString( 32 ) ) } )
	end

	--delete user if there
	self.user = nil

	--delete key cookies
	for i = 1, self.config.keys do
		self.head:deleteCookie( self.config.prefix .. 'key' .. i )
	end

	--always succeeds
	return true
end

--check login
function user:checkLogin()
	if self.user then return true end --already been logged in

	--build db where table + shm key
	local wheres, key = {}, ''
	for i = 1, self.config.keys do
		local bit = self.head:getCookie( self.config.prefix .. 'key' .. i )
		if not bit then return false end
		wheres['key' .. i] = bit
		key = key .. bit
	end

	--try to get data from shm
	local user, err = json.decode( ngx.shared[luawa.shm_prefix .. 'user']:get( key ) )
	if not err then
		self.user = user

		--set key cookies again (to stop expiration)
		for i = 1, self.config.keys do
			self.head:setCookie( self.config.prefix .. 'key' .. i, self.user['key' .. i], self.config.expire )
		end
		
		return true
	end

	--get data from mysql (fallback)
	local user, err = self.db:select(
		self.config.dbprefix .. 'user', '*',
		wheres,
		'id ASC',
		1
	)

	--do we have a user?
	if user and user[1] then
		--set shared data
		ngx.shared[luawa.shm_prefix .. 'user']:set( key, json.encode( user[1] ) )
		self.user = user[1]

		--set key cookies again (to stop expiration)
		for i = 1, self.config.keys do
			self.head:setCookie( self.config.prefix .. 'key' .. i, self.user['key' .. i], self.config.expire )
		end

		return true
	else
		return false
	end
end

--check permission
function user:checkPermission( permission )
	if not self:checkLogin() then return false end
	if not self.user.permissions then self.user.permissions = {} end
	if self.user.permissions[permission] ~= nil then return self.user.permissions[permission] end

	--try to get shm permission
	local data, err = ngx.shared[luawa.shm_prefix .. 'user']:get( 'permission_' .. self.user.id .. '_' .. permission:lower() )
	if data ~= nil then
		return data
	end

	--sql query to check
	local check = self.db:query( [[
SELECT ]] .. self.config.dbprefix .. [[user_permissions.permission FROM ]] .. self.config.dbprefix .. [[user_permissions, ]] .. self.config.dbprefix .. [[user_groups
WHERE ]] .. self.config.dbprefix .. [[user_permissions.permission = "]] .. permission .. [["
AND ]] .. self.config.dbprefix .. [[user_permissions.group = ]] .. self.config.dbprefix .. [[user_groups.id
AND ]] .. self.config.dbprefix .. [[user_groups.id = ]] .. self.user.group
	)

	--permission?
	if check[1] then
		data = true
	else
		data = false
	end

	--set for remainder of request + return
	ngx.shared[luawa.shm_prefix .. 'user']:set( 'permission_' .. self.user.id .. '_' .. permission:lower(), data )
	self.user.permissions[permission] = data
	return data
end

--get data
function user:getData()
	if not self:checkLogin() then return false end
	return self.user
end

--set data
function user:setData( fields )
	if not self:checkLogin() then return false end
	--password?
	if fields.password then
		--no empty passwords allowed!
		if fields.password == '' then
			fields.password = nil
		else
			fields.password = self:generatePassword( fields.password, self:getData().salt )
		end
	end
	--get database result
	local result, err = self.db:update(
		self.config.dbprefix .. 'user', fields,
		{ id = self.user.id }
	)
	--if ok set data
	if result then
		for k, v in pairs( fields ) do
			self.user[k] = v
		end
		--build shared key
		local key = ''
		for i = 1, self.config.keys do
			key = key .. self.user['key' .. i]
		end
		--overwrite shared data
		ngx.shared[luawa.shm_prefix .. 'user']:set( key, json.encode( self.user ) )
	end
	return result, err
end

--return object
return user