--[[
    file: user.lua
    desc: user management, permissions
]]
local pairs = pairs

local user = {
	config = {
		prefix = '',
		expire = 31536000, --1y
		reload_key = false,
		secret = '',
		strength = 1
	}
}

--start
function user:_start()
	self.db, self.head, self.utils, self.email = luawa.database, luawa.header, luawa.utils, luawa.email
end

--end
function user:_end()
	if self.user then self.user = nil end
end

--generate a password from text + salt
function user:generatePassword( password, salt )
	--start with salt & secret
	local str = salt .. self.config.secret
	--loop strength times (increase rainbow table calculation time)
	--each loop inputs the users password
	for i = 0, self.config.strength do
		str = self.utils:digest( str .. password )
	end
	return str
end

--generate a key
function user:generateKey( entropy )
	return self.utils:digest( entropy .. self.utils:randomString( 32 ) )
end

--reset a password
function user:resetPassword( email )
	--get user in question
	local user = self.db:select(
		'user', '*',
		{ email = email }
	)
	if not ( user and user[1] ) then
		return false, 'No users linked to this email'
	end

	--generate temporary reset key password_reset_key
	local password_reset_key = self:generateKey( user[1].key )

	--add key + time to database
	local status, err = self.db:update(
		'user',
		{
			password_reset_key = password_reset_key,
			password_reset_time = os.time() + 900 --15 mins
		},
		{ id = user[1].id }
	)
	if not status then return false, err end

	--send email with key link
	return password_reset_key
end

--process reset password
function user:resetPasswordLogin( email, key )
	--check key+email
	local user = self.db:select(
		'user', '*',
		{ email = email, password_reset_key = key }
	)
	if not ( user and user[1] ) or user[1].password_reset_time < os.time() then
		return false, 'No email/key combination found'
	end

	--remove key+time from database
	local status, err = self.db:update(
		'user',
		{
			password_reset_key = '',
			password_reset_time = 0 --15 mins
		},
		{ id = user[1].id }
	)
	if not status then return false, err end

	--login the user with their OLD/current password, app should redirect
	return self:login( email, user[1].password, true )
end

--register a user
function user:register( email, password, name )
	if not name then name = 'Unknown' end
	if password == '' then return false, 'Invalid password' end

	--salt & key
	local salt, key = self.utils:randomString( 32 ), self:generateKey( password )

	--hash password
	password = self:generatePassword( password, salt )

	--insert user
	local result, err = self.db:insert(
		'user',
		{ 'email', 'password', 'salt', 'name', 'key', 'register_time' },
		{ { email, password, salt, name, key, os.time() } }
	)

	--success?
	if result then return true else return false, err end
end

--login a user
function user:login( email, password, hashed )
	--get user
	local user, err = self.db:select(
		'user', '*',
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
			self.user.key = self.utils:digest( self.utils:randomString( 32 ) )
			update.key = self.user.key
		end

		--update user
		self:setData( update )


		--set cookies
		self.head:setCookie( self.config.prefix .. 'id', self.user.id, self.config.expire )
		self.head:setCookie( self.config.prefix .. 'key', self.user.key, self.config.expire )
		self.head:setCookie( self.config.prefix .. 'name', self.user.name, self.config.expire )

		--get permissions for cookie
		local permissions = self.db:select(
			'user_permissions', 'permission',
			{ group = self.user.group }
		)
		if permissions then
			local permission_string = ''
			for k, v in pairs( permissions ) do
				permission_string = permission_string .. v.permission .. ','
			end
			permission_string = self.utils:rtrim( permission_string, ',' )
			self.head:setCookie( self.config.prefix .. 'permissions', permission_string, self.config.expire )
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
		self:setData( { key = self.utils:digest( self.utils:randomString( 32 ) ) } )
	end

	--delete user if there
	self.user = nil

	--delete cookies
	self.head:deleteCookie( self.config.prefix .. 'id' )
	self.head:deleteCookie( self.config.prefix .. 'key' )
	self.head:deleteCookie( self.config.prefix .. 'name' )
	self.head:deleteCookie( self.config.prefix .. 'permissions' )

	--always succeeds
	return true
end


--DB BASED checks
--check login
function user:checkLogin()
	if self.user then return true end --already been logged in
	if not self:cookieLogin() then return false end

	--get data
	local user, err = self.db:select(
		'user', '*',
		{ id = self.head:getCookie( self.config.prefix .. 'id' ), key = self.head:getCookie( self.config.prefix .. 'key' ) }
	)

	--do we have a user?
	if user and user[1] then
		self.user = user[1]
		return true
	else
		return false
	end
end

--check permission
function user:checkPermission( permission )
	if not self:checkLogin() then return false end

	--sql query to check
	local permission = self.db:query( [[
		SELECT user_permissions.permission FROM user_permissions, user_groups
		WHERE user_permissions.permission = "]] .. permission .. [["
		AND user_permissions.group_id = user_groups.id
		AND user_groups.id = ]] .. self.user.group
	)

	--permission?
	if permission[1] then return true else return false end
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
		'user', fields,
		{ id = self.user.id }
	)
	--if ok set data
	if result then
		for k, v in pairs( fields ) do self.user[k] = v end
	end
	return result, err
end

--COOKIE BASED checks
--check cookie login
function user:cookieLogin()
	if self.head:getCookie( self.config.prefix .. 'id' ) and self.head:getCookie( self.config.prefix .. 'key' ) then
		return true
	else
		return false
	end
end

--check cookie permission
function user:cookiePermission( permission )
	if not self:cookieLogin() or not self.head:getCookie( self.config.prefix .. 'permissions' ) then return false end

	--permission in cookie string?
	if self.head:getCookie( self.config.prefix .. 'permissions' ):find( permission ) then
		return true
	else
		return false
	end
end

--get cookie name
function user:cookieName()
	if not self:cookieLogin() or not self.head:getCookie( self.config.prefix .. 'name' ) then return false end
	return self.head:getCookie( self.config.prefix .. 'name' )
end


--return object
return user