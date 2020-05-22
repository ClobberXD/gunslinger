local modpath = minetest.get_modpath("gunslinger") .. "/"

-- Import API
dofile(modpath .. "api.lua")

-- Register default ammo
gunslinger.register_ammo("gunslinger:default_ammo", {
	itemdef = {
		description = "Generic ammo",
		inventory_image = "gunslinger_ammo.png",
		stack_max = 300
	}
})

minetest.register_alias("ammo", "gunslinger:default_ammo")

-- If builtin guns not disabled, import builtin guns from guns.lua
if not minetest.settings:get_bool("gunslinger.disable_builtin", false) then
	dofile(modpath .. "guns.lua")
end
