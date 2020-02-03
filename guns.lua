gunslinger.register_gun("gunslinger:cheetah", {
	itemdef = {
		description = "Cheetah (Assault Rifle)",
		inventory_image = "gunslinger_cheetah.png",
		wield_image = "gunslinger_cheetah.png^[transformFXR300",
		wield_scale = {x = 3, y = 3, z = 1}
	},

	mode = "automatic",
	dmg_mult = 2,
	recoil_mult = 5,
	fire_rate = 8,
	clip_size = 30,
	range = 80
})

gunslinger.register_gun("gunslinger:hitscan", {
	itemdef = {
		description = "hitscan",
		inventory_image = "gunslinger_cheetah.png",
		wield_image = "gunslinger_cheetah.png^[transformFXR300",
		wield_scale = {x = 3, y = 3, z = 1}
	},

	mode = "manual",
	hit_type = "hitscan",
	dmg_mult = 5,
	recoil_mult = 5,
	fire_rate = 3,
	clip_size = 1,
	range = 200
})

minetest.register_alias("cheetah", "gunslinger:cheetah")
minetest.register_alias("hitscan", "gunslinger:hitscan")