local modpath = minetest.get_modpath("gunslinger") .. "/"

-- Import API
dofile(modpath .. "api.lua")

if not minetest.settings:get_bool("gunslinger.disable_builtin") then
	dofile(modpath .. "guns.lua")
end

minetest.register_craftitem("gunslinger:ammo", {
	description = "Ammo",
	inventory_image = "gunslinger_ammo.png",
})