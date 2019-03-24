gunslinger.register_gun("gunslinger:cheetah", {
	itemdef = {
		description = "Cheetah (Assault Rifle)",
		inventory_image = "gunslinger_cheetah.png",
		wield_image = "gunslinger_cheetah.png^[transformFXR300",
		wield_scale = {x = 3, y = 3, z = 1}
	},

	mode = "automatic",
	dmg_mult = 2,
	fire_rate = 8,
	clip_size = 30,
	range = 80
})

minetest.register_alias("cheetah", "gunslinger:cheetah")
