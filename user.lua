--[[
    file: user.lua
    desc: user management, permissions
]]--
luawa.user = {}

--start
function luawa.user:_start()
	self.db = luawa.database
end

--register a user
function luawa.user:register( email, password, group )
end

--login a user
function luawa.user:login( email, password )
end

--logout
function luawa.user:logout()
end


--DB BASED checks
--check login
function luawa.user:checkLogin()
end

--check permission
function luawa.user:checkPermission( permission )
	if not self:checkLogin() then return false end
end


--COOKIE BASED checks
--check cookie login
function luawa.user:cookieLogin()
end

--check cookie permission
function luawa.user:cookiePermission( permission )
	if not self:cookieLogin() then return false end
end

--get cookie name
function luawa.user:cookieName()
	if not self:cookieLogin() then return false end
end