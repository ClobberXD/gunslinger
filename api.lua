gunslinger = {}
local guns = {}
local types = {}
local automatic = {}
local scope_overlay = {}

--
-- Helper functions

local function play_sound(sound, player)
	minetest.sound_play(sound, {
		object = player,
		loop = false
	})
end

--
-- Internal API functions

local function show_scope(player, def)
	if not player or not def.scope then
		return
	end

	-- Create HUD image
	scope_overlay[player:get_player_name()] = player:hud_add({
		hud_elem_type = "image",
		position = {x = 0.5, y = 0.5},
		alignment = {x = 0, y = 0},
		text = def.scope_overlay
	})
end

local function hide_scope(player)
	if not player then
		return
	end

	local name = player:get_player_name()
	player:hud_remove(scope_overlay[name])
	scope_overlay[name] = nil
end

local function fire(stack, player)
	-- Take aim
	local def = gunslinger.get_def(stack:get_name())
	local eye_offset = player:get_eye_offset().offset_first
	local p1 = vector.add(player:get_pos(), eye_offset)
	p1 = vector.add(p1, player:get_look_dir())
	local p2 = vector.add(p1, vector.multiply(player:get_look_dir(), max_dist))
	local ray = minetest.raycast(p1, p2)
	local pointed = ray:next()

	-- Fire!
	if pointed and pointed.type == "object" then
		local target = pointed.ref
		local point = pointed.intersection_point
		local dmg = base_dmg * def.dmg_mult

		-- Play sound of gunshot
		play_sound(def.fire_sound or "gunslinger_fire1")

		-- Add 50% damage if headshot
		if point.y > target:get_pos().y + 1.5 then
			dmg = dmg * 1.5
		end

		-- Add 20% more damage if player using scope
		if scope_overlay[player:get_player_name()] then
			dmg = dmg * 1.2
		end

		target:set_hp(target:get_hp() - dmg)
	end

	-- Update wear
	wear = wear + def.wear_step
	stack:set_wear(wear)

	return stack
end

local function reload(stack, player)
	-- Check for ammo
	local inv = player:get_inventory()
	if inv:contains_item("main", "gunslinger:ammo") then
		-- Ammo exists, reload and reset wear
		inv:remove_item("main", "gunslinger:ammo")
		stack:set_wear(0)
	else
		-- No ammo, play click sound
		play_sound("gunslinger_ooa", player)
	end

	return stack
end

local function on_lclick(stack, player)
	local wear = stack:get_wear()
	local def = gunslinger.get_def(stack:get_name())
	if wear >= 65535 then
		--Reload
		stack = reload(stack, player)
	else
		local name = player:get_player_name()
		if def.style_of_fire == "automatic" and not automatic[name] then
			automatic[name] = {
				stack  = stack,
				def    = def
			}
		else
			stack = fire(stack, player)
		end
	end

	return stack
end

local function on_rclick(stack, player)
	local def = get_def(stack:get_name())
	local hud = scope_overlay[player:get_player_name()]
	if hud then
		hide_scope(player)
	else
		show_scope(player, def)
	end

	return stack
end

local function on_step(dtime)
	for name, info in pairs(automatic) do
		local player = minetest.get_player_by_name(name)
		if player:get_player_control().LMB then
			-- If LMB pressed, fire
			info.stack = fire(info.stack, player)
		else
			-- If LMB not pressed, remove player from list
			automatic[name] = nil
		end
	end
end

minetest.register_globalstep(on_step)

--
-- External API functions

function gunslinger.get_def(name)
	return guns[name]
end

function gunslinger.register_type(name, def)
	assert(type(name) == "string" and type(def) == "table",
			   "gunslinger.register_type: Invalid params!")
	assert(not types[name], "gunslinger.register_type:"
			.. " Attempt to register a type with an existing name!")

	types[name] = def
end

function gunslinger.register_gun(name, def)
	assert(type(name) == "string" and type(def) == "table",
			   "gunslinger.register_type: Invalid params!")
	assert(not guns[name], "gunslinger.register_gun:"
			.. " Attempt to register a gun with an existing name!")
	assert(types[def.type], "gunslinger.register_gun: Attempt to"
			.. " register gun of non-existent type (" .. def.type .. ")!")

	def.itemdef.on_use = on_lclick
	def.itemdef.on_secondary_use = on_rclick
	def.itemdef.on_place = function(stack, player, pointed)
		if pointed.type == "node" then
			local node = minetest.get_node_or_nil(pointed.under)
			local nodedef = minetest.registered_items[node.name]
			return nodedef.on_rightclick or on_rclick(stack, player)
		elseif pointed.type == "object" then
			local entity = pointed.ref:get_luaentity()
			return entity:on_rightclick(player) or on_rclick(stack, player)
		end
	end

	def.style_of_fire = def.style_of_fire or def.type.style_of_fire
	def.wear = math.ceil(65534 / def.clip_size)

	guns[name] = def
	minetest.register_tool(name, def.itemdef)
end
