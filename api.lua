gunslinger = {
	__guns = {},
	__types = {},
	__automatic = {},
	__scopes = {},
	__interval = {}
}

local max_wear = 65534
local projectile_speed = 500
local lite = minetest.settings:get_bool("gunslinger.lite")

-- Base damage value.
local base_dmg = 1

-- Base spread value
local base_spread = 0.001

--
-- Internal API functions
--

local function get_eye_pos(player)
	if not player then
		return
	end

	local pos = player:get_pos()
	pos.y = pos.y + player:get_properties().eye_height
	return pos
end

local function get_pointed_thing(pos, dir, def)
	if not pos or not dir or not def then
		error("gunslinger: Invalid get_pointed_thing invocation" ..
		        " (missing params)", 2)
	end

	local pos2 = vector.add(pos, vector.multiply(dir, def.range))
	local ray = minetest.raycast(pos, pos2)
	return ray:next()
end

local function play_sound(sound, player)
	minetest.sound_play(sound, {
		object = player,
		loop = false
	})
end

local function add_auto(name, def, stack)
	gunslinger.__automatic[name] = {
		def   = def,
		stack = stack
	}
end

--------------------------------

local function show_scope(player, scope, zoom)
	if not player then
		return
	end

	-- Create HUD overlay element
	gunslinger.__scopes[player:get_player_name()] = player:hud_add({
		hud_elem_type = "image",
		position = {x = 0.5, y = 0.5},
		alignment = {x = 0, y = 0},
		text = scope
	})
end

local function hide_scope(player)
	if not player then
		return
	end

	local name = player:get_player_name()
	player:hud_remove(gunslinger.__scopes[name])
	gunslinger.__scopes[name] = nil
end

--------------------------------

local function reload(stack, player)
	-- Check for ammo
	local inv = player:get_inventory()
	local def = gunslinger.__guns[stack:get_name()]

	local taken = inv:remove_item("main", def.ammo .. " " .. def.clip_size)
	if taken:is_empty() then
		play_sound(def.sounds.ooa, player)
	else
		local name = player:get_player_name()
		gunslinger.__interval[name] = gunslinger.__interval[name] - def.reload_time
		stack:set_wear(math.floor(max_wear - (taken:get_count() / def.clip_size) * max_wear))
		play_sound(def.sounds.reload, player)
	end

	return stack
end

local function fire(stack, player)
	if not stack then
		return
	end

	local def = gunslinger.__guns[stack:get_name()]
	if not def then
		return stack
	end

	local wear = stack:get_wear()
	if wear == max_wear then
		return reload(stack, player)
	end

	-- Play gunshot sound
	play_sound(def.sounds.fire, player)

	--[[
		Perform "deferred raycasting" to mimic projectile entities, without
		actually using entities:
			- Perform initial raycast to get position of target if it exists
			- Calculate time taken for projectile to travel from gun to target
			- Perform actual raycast after the calculated time

		This process throws in a couple more calculations and an extra raycast,
		but the vastly improved realism at the cost of a negligible performance
		hit is always great to have.
	]]
	local time = 0.1 -- Default to 0.1s

	local dir = player:get_look_dir()

	local pos1 = get_eye_pos(player)
	pos1 = vector.add(pos1, dir)
	local initial_pthing = get_pointed_thing(pos1, dir, def)
	if initial_pthing then
		local pos2 = minetest.get_pointed_thing_position(initial_pthing)
		time = vector.distance(pos1, pos2) / projectile_speed
	end

	for i = 1, def.pellets do
		-- Mimic inaccuracy by applying randomised miniscule deviations
		local spread = base_spread * def.spread_mult
		if spread ~= 0 then
			dir = vector.apply(dir, function(n)
				return n + math.random(-spread, spread)
			end)
		end

		minetest.after(time, function(obj, pos, look_dir, gun_def)
			local pointed = get_pointed_thing(pos, look_dir, gun_def)
			if pointed and pointed.type == "object" then
				local target = pointed.ref
				local point = pointed.intersection_point
				local dmg = base_dmg * gun_def.dmg_mult

				-- Add 50% damage if headshot
				if point.y > target:get_pos().y + 1.2 then
					dmg = dmg * 1.5
				end

				-- Add 20% more damage if player using scope
				if gunslinger.__scopes[obj:get_player_name()] then
					dmg = dmg * 1.2
				end

				target:punch(obj, nil, {damage_groups = {fleshy = dmg}})
			end
		end, player, pos1, dir, def)

		-- Projectile particle
		minetest.add_particle({
			pos = pos1,
			velocity = vector.multiply(dir, projectile_speed),
			acceleration = {x = 0, y = 0, z = 0},
			expirationtime = 3,
			size = 3,
			collisiondetection = true,
			collision_removal = true,
			object_collision = true,
			glow = 10
		})
	end

	-- Update wear
	wear = wear + def.unit_wear
	if wear > max_wear then
		wear = max_wear
	end
	stack:set_wear(wear)

	return stack
end

local function burst_fire(stack, player)
	local def = gunslinger.__guns[stack:get_name()]
	local burst = def.burst or 3
	for i = 1, burst do
		minetest.after(i / def.fire_rate, function(st)
			fire(st, player)
		end, stack)
	end
	-- Manually add wear to stack, as functions can't return
	-- values from within minetest.after
	stack:add_wear(def.unit_wear * burst)

	return stack
end

--------------------------------

local function on_lclick(stack, player)
	if not stack or not player then
		return
	end

	local def = gunslinger.__guns[stack:get_name()]
	if not def then
		return
	end

	local name = player:get_player_name()
	if gunslinger.__interval[name] and gunslinger.__interval[name] < def.unit_time then
		return
	end
	gunslinger.__interval[name] = 0

	if def.mode == "automatic" and not gunslinger.__automatic[name] then
		stack = fire(stack, player)
		add_auto(name, def, stack)
	elseif def.mode == "hybrid"
			and not gunslinger.__automatic[name] then
		if gunslinger.__scopes[name] then
			stack = burst_fire(stack, player)
		else
			add_auto(name, def)
		end
	elseif def.mode == "burst" then
		stack = burst_fire(stack, player)
	elseif def.mode == "semi-automatic" then
		stack = fire(stack, player)
	elseif def.mode == "manual" then
		local meta = stack:get_meta()
		local loaded = meta:get("loaded")
		if not loaded then
			if def.sounds.load then
				play_sound(def.sounds.load, player)
			end

			meta:set_string("loaded", "true")
			stack = reload(stack, player)
		else
			meta:set_string("loaded", "")
			stack = fire(stack, player)
		end
	end

	return stack
end

local function on_rclick(stack, player)
	local def = gunslinger.__guns[stack:get_name()]
	if gunslinger.__scopes[player:get_player_name()] then
		hide_scope(player)
	else
		if def.scope then
			show_scope(player, def.scope, def.gunslinger.__scopes)
		end
	end
end

--------------------------------

minetest.register_globalstep(function(dtime)
	for name in pairs(gunslinger.__interval) do
		gunslinger.__interval[name] = gunslinger.__interval[name] + dtime
	end
	if not lite then
		for name, info in pairs(gunslinger.__automatic) do
			local player = minetest.get_player_by_name(name)
			if not player then
				gunslinger.__automatic[name] = nil
				return
			end
			if gunslinger.__interval[name] > info.def.unit_time then
				if player:get_player_control().LMB and
						player:get_wielded_item():get_name() == info.stack:get_name() then
					-- If LMB pressed, fire
					info.stack = fire(info.stack, player)
					player:set_wielded_item(info.stack)
					gunslinger.__automatic[name].stack = info.stack
					gunslinger.__interval[name] = 0
				else
					-- If LMB not pressed, remove player from list
					gunslinger.__automatic[name] = nil
				end
			end
		end
	end
end)

--
-- External API functions
--

function gunslinger.get_def(name)
	return gunslinger.__guns[name]
end

function gunslinger.register_type(name, def)
	assert(type(name) == "string" and type(def) == "table",
	      "gunslinger.register_type: Invalid params!")
	assert(not gunslinger.__types[name], "gunslinger.register_type:" ..
	      " Attempt to register a type with an existing name!")

	gunslinger.__types[name] = def
end

function gunslinger.register_gun(name, def)
	assert(type(name) == "string" and type(def) == "table",
	      "gunslinger.register_gun: Invalid params!")
	assert(not gunslinger.__guns[name], "gunslinger.register_gun: " ..
	      "Attempt to register a gun with an existing name!")

	-- Import type defaults if def.type specified
	if def.type then
		assert(gunslinger.__types[def.type], "gunslinger.register_gun: Invalid type!")

		for attr, val in pairs(gunslinger.__types[def.type]) do
			def[attr] = val
		end
	end

	-- Abort when making use of unimplemented features
	if def.zoom then
		error("gunslinger.register_gun: Unimplemented feature!", 2)
	end

	if (def.mode == "automatic" or def.mode == "hybrid")
			and lite then
		error("gunslinger.register_gun: Attempting to register gun of " ..
				"type '" .. def.mode .. "' when lite mode is enabled", 2)
	end

	if not def.dmg_mult then
		def.dmg_mult = 1
	end

	-- Initialize sounds
	do
		if not def.sounds then
			def.sounds = {}
		end

		if not def.sounds.fire then
			def.sounds.fire = "gunslinger_fire"
		end

		if not def.sounds.reload then
			def.sounds.reload = "gunslinger_reload"
		end

		if not def.sounds.ooa then
			def.sounds.ooa = "gunslinger_ooa"
		end
	end

	if not def.ammo then
		def.ammo = "gunslinger:ammo"
	end

	if not def.reload_time then
		def.reload_time = 3
	end

	if not def.spread_mult then
		def.spread_mult = 0
	end

	if not def.pellets then
		def.pellets = 1
	end

	if def.zoom and not def.scope then
		error("gunslinger.register_gun: zoom requires scope to be defined!", 2)
	end

	-- Add additional helper fields for internal use
	def.unit_wear = math.ceil(max_wear / def.clip_size)
	def.unit_time = 1 / def.fire_rate

	-- Register gun
	gunslinger.__guns[name] = def

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

	-- Register tool
	minetest.register_tool(name, def.itemdef)
end
