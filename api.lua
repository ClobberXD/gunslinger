gunslinger = {}

local max_wear = 65534
local lite = minetest.settings:get_bool("gunslinger.lite")

-- Base damage value of 1 HP. Guns can modify this by defining dmg_mult
local base_dmg = 1

local guns = {}
local types = {}
local automatic = {}
local scope_overlay = {}
local interval = {}

--
-- Internal API functions
--

-- Locally cache gunslinger.get_def for better performance
local get_def = gunslinger.get_def

local function play_sound(sound, player)
	minetest.sound_play(sound, {
		object = player,
		loop = false
	})
end

local function add_auto(name, def, stack)
	automatic[name] = {
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
	scope_overlay[player:get_player_name()] = player:hud_add({
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
	player:hud_remove(scope_overlay[name])
	scope_overlay[name] = nil
end

--------------------------------

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

local function fire(stack, player)
	-- Workaround to prevent function from running if stack is nil
	if not stack then
		return
	end

	local def = get_def(stack:get_name())
	if not def then
		return stack
	end

	local wear = stack:get_wear()
	if wear == max_wear then
		return reload(stack, player)
	end

	-- Play gunshot sound
	play_sound(def.fire_sound, player)

	-- Take aim
	local eye_offset = {x = 0, y = 1.625, z = 0} --player:get_eye_offset().offset_first
	local dir = player:get_look_dir()
	local p1 = vector.add(player:get_pos(), eye_offset)
	p1 = vector.add(p1, dir)
	local p2 = vector.add(p1, vector.multiply(dir, def.range))
	local ray = minetest.raycast(p1, p2)
	local pointed = ray:next()

	-- Projectile particle
	minetest.add_particle({
		pos = p1,
		velocity = vector.multiply(dir, 400),
		acceleration = {x = 0, y = 0, z = 0},
		expirationtime = 2,
		size = 1,
		collisiondetection = true,
		collision_removal = true,
		object_collision = true,
		glow = 5
	})

	-- Fire!
	if pointed and pointed.type == "object" then
		local target = pointed.ref
		local point = pointed.intersection_point
		local dmg = base_dmg * def.dmg_mult

		-- Add 50% damage if headshot
		if point.y > target:get_pos().y + 1.5 then
			dmg = dmg * 1.5
		end

		-- Add 20% more damage if player using scope
		if scope_overlay[player:get_player_name()] then
			dmg = dmg * 1.2
		end

		target:punch(player, nil, {damage_groups = {fleshy = dmg}})
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
	local def = get_def(stack:get_name())
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

local function splash_fire(stack, player)
	-- TODO
end

--------------------------------

local function on_lclick(stack, player)
	if not stack or not player then
		return
	end

	local def = get_def(stack:get_name())
	if not def then
		return
	end

	local name = player:get_player_name()
	if interval[name] and interval[name] < def.unit_time then
		return
	end
	interval[name] = 0

	if def.mode == "automatic" and not automatic[name] then
		add_auto(name, def, stack)
	elseif def.mode == "hybrid"
			and not automatic[name] then
		if scope_overlay[name] then
			stack = burst_fire(stack, player)
		else
			add_auto(name, def)
		end
	elseif def.mode == "burst" then
		stack = burst_fire(stack, player)
	elseif def.mode == "splash" then
		stack = splash_fire(stack, player)
	elseif def.mode == "semi-automatic" then
		stack = fire(stack, player)
	elseif def.mode == "manual" then
		local meta = stack:get_meta()
		if meta:contains("loaded") then
			stack = fire(stack, player)
			meta:set_string("loaded", "")
		else
			stack = reload(stack, player)
			meta:set_string("loaded", "true")
		end
	end

	return stack
end

local function on_rclick(stack, player)
	local def = get_def(stack:get_name())
	if scope_overlay[player:get_player_name()] then
		hide_scope(player)
	else
		if def.scope then
			show_scope(player, def.scope, def.scope_overlay)
		end
	end

	return stack
end

--------------------------------

local function on_step(dtime)
	for name in pairs(interval) do
		interval[name] = interval[name] + dtime
	end
	if not lite then
		for name, info in pairs(automatic) do
			local player = minetest.get_player_by_name(name)
			if not player then
				automatic[name] = nil
				return
			end
			if interval[name] < info.def.unit_time then
				return
			end
			if player:get_player_control().LMB then
				-- If LMB pressed, fire
				info.stack = fire(info.stack, player)
				player:set_wielded_item(info.stack)
				automatic[name].stack = info.stack
				interval[name] = 0
			else
				-- If LMB not pressed, remove player from list
				automatic[name] = nil
			end
		end
	end
end

minetest.register_globalstep(on_step)

--
-- External API functions
--

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
	       "gunslinger.register_gun: Invalid params!")
	assert(not guns[name], "gunslinger.register_gun: " ..
	       "Attempt to register a gun with an existing name!")

	-- Import type defaults if def.type specified
	if def.type then
		assert(types[def.type], "gunslinger.register_gun: Invalid type!")

		for attr, val in pairs(types[def.type]) do
			def[attr] = val
		end
	end

	-- Abort when making use of unimplemented features
	if def.mode == "splash" or def.zoom then
		error("register_gun: Unimplemented feature!", 2)
	end

	if (def.mode == "automatic" or def.mode == "hybrid")
			and lite then
		error("gunslinger.register_gun: Attempting to register gun of " ..
				"type '" .. def.mode .. "' when lite mode is enabled", 2)
	end

	if not def.dmg_mult then
		def.dmg_mult = 1
	end

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

	if not def.fire_sound then
		def.fire_sound = (def.mode ~= "splash")
			and "gunslinger_fire1" or "gunslinger_fire2"
	end

	if def.zoom and not def.scope then
		error("gunslinger.register_gun: zoom requires scope to be defined!", 2)
	end

	def.unit_wear = math.ceil(max_wear / def.clip_size)
	def.unit_time = 1 / def.fire_rate

	guns[name] = def
	minetest.register_tool(name, def.itemdef)
end
