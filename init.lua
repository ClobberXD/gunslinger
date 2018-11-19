local modpath = minetest.get_modpath("gunslinger") .. "/"

-- Import API
dofile(modpath .. "api.lua")

if not minetest.settings:get_bool("gunslinger.disable_builtin") then
	dofile(modpath .. "assault_rifle.lua")
	dofile(modpath .. "shotgun.lua")
	dofile(modpath .. "sniper_rifle.lua")
	dofile(modpath .. "handgun.lua")
end
