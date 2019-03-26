local modpath = minetest.get_modpath("gunslinger") .. "/"

-- Import API
dofile(modpath .. "api.lua")

-- If builtin guns not disabled, import builtin guns from guns.lua
if not minetest.settings:get_bool("gunslinger.disable_builtin") then
	dofile(modpath .. "guns.lua")
end

-- Register default ammo item
minetest.register_craftitem("gunslinger:ammo", {
	description = "Generic ammo",
	inventory_image = "gunslinger_ammo.png",
	stack_max = 300
})
