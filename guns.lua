gunslinger.register_gun("gunslinger:cheetah", {
	itemdef = {
		description = "Cheetah (Assault Rifle)",
		inventory_image = "gunslinger_cheetah.png",
		wield_image = "gunslinger_cheetah.png^[transformFXR300",
		wield_scale = {x = 4, y = 4, z = 1}
	},

	style_of_fire = "semi-automatic",
	base_dmg = 1,
	fire_rate = 6,
	clip_size = 50,
	range = 80

	--scope = "sight",
})
