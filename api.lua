gunslinger = {
	__guns      = {},
	__ammo      = {},
	__types     = {},
	__stack     = {},
	__rounds    = {},
	__reloading = {},
	__automatic = {},
	__scopes    = {},
	__interval  = {}
}

local config = {
	debug    = minetest.settings:get_bool("gunslinger.debug", false),
	max_wear = 65534,
	base_dmg = 1,
	projectile_speed = 500,
	base_spread = 0.001,
	base_recoil = 0.001,
	lite = minetest.settings:get_bool("gunslinger.lite"),
	fov_transition_time = 0.1
}

local random = PcgRandom(os.time())
local vec = table.copy(vector)

--
-- Internal API functions
--

local function rangelim(low, val, high, default)
	if not val and default then
		return default
	elseif low and val and high then
		return math.max(low, math.min(val, high))
	else
		error("gunslinger: Invalid rangelim invocation!", 2)
	end
end

local function get_eye_pos(player)
	if not player then
		return
	end

	local pos = player:get_pos()
	pos.y = pos.y + player:get_properties().eye_height
	return pos
end

local function get_pointed_thing(pos, dir, range, avoid_self)
	if not pos or not dir or not range then
		error("gunslinger: Invalid get_pointed_thing invocation" ..
			" (missing params)", 2)
	end

	local pos2 = vector.add(pos, vector.multiply(dir, range))
	local ray = minetest.raycast(pos, pos2)
	local pthing = ray:next()

	-- pointer.intersection_normal is a zero vector
	-- if ray originates from inside pointed_thing
	if avoid_self and pthing and
			vector.equals(pthing.intersection_normal, vector.new(0, 0, 0)) then
		pthing = ray:next()
	end
	return pthing
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

local function sanitize_def(def)
	if type(def) ~= "table" then
		error("gunslinger: Gun definition has to be a table!", 2)
	end

	if (def.mode == "automatic" or def.mode == "hybrid") and config.lite then
		error("gunslinger: Attempting to register gun of type '" ..
			def.mode .. "' when lite mode is enabled", 2)
	end

	-- Check for ammo
	if def.ammo then
		assert(gunslinger.__ammo[def.ammo], "gunslinger.register_gun: Invalid ammo!")
	else
		def.ammo = "gunslinger:default_ammo"
	end

	if def.mode == "burst" then
		def.burst = rangelim(2, def.burst, 5, 3)
	end

	def.dmg_mult    = rangelim(1, def.dmg_mult, 100, 1)
	def.reload_time = rangelim(1, def.reload_time, 10, 2.5)
	def.spread_mult = rangelim(0, def.spread_mult, 500, 0)
	def.recoil_mult = rangelim(0, def.recoil_mult, 500, 0)
	def.pellets     = rangelim(1, def.pellets, 20, 1)

	def.sounds        = def.sounds or {}
	def.sounds.fire   = def.sounds.fire or "gunslinger_fire"
	def.sounds.reload = def.sounds.reload or "gunslinger_reload"
	def.sounds.ooa    = def.sounds.ooa or "gunslinger_ooa"

	def.textures = def.textures or {}
	def.textures.projectile = def.textures.projectile or "gunslinger_projectile.png"

	-- Limit zoom to 8x; default to no zoom
	def.zoom = def.zoom and rangelim(1, def.zoom, 8)

	local scale = def.scope_scale
	if def.scope and (not scale or type(scale) ~= "table" or not scale.x or not scale.y or
			type(scale.x) ~= "number" or type(scale.y) ~= "number") then
		error("gunslinger: Invalid `scope_scale` definition!", 2)
	end

	return def
end

--------------------------------

local function show_scope(player, zoom, scope, scale)
	if not player then
		return
	end

	local scope_spec = { fov = zoom }

	-- Set FOV multiplier to 1 / def.zoom
	-- e.g. if def.zoom == 4, FOV multiplier would be 1/4
	player:set_fov(1 / zoom, true, config.fov_transition_time)

	-- Scope HUD element; disable wielditem and crosshair HUD elements if scope exists
	if scope then
		scope_spec.hud = player:hud_add({
			hud_elem_type = "image",
			position = {x = 0.5, y = 0.5},
			alignment = {x = 0, y = 0},
			scale = scale,
			text = scope
		})
		player:hud_set_flags({
			wielditem = false,
			crosshair = false
		})
	end

	gunslinger.__scopes[player:get_player_name()] = scope_spec
end

local function hide_scope(player)
	if not player then
		return
	end

	local name = player:get_player_name()
	local scope_spec = gunslinger.__scopes[name]

	player:set_fov(0, false, config.fov_transition_time)

	-- Remove scope HUD element; revert visibility changes to default HUD elements
	if scope_spec.hud then
		player:hud_remove(scope_spec.hud)
		player:hud_set_flags({
			wielditem = true,
			crosshair = true
		})
	end

	gunslinger.__scopes[name] = nil
end

--------------------------------

local function reload(stack, player)
	-- Check for ammo
	local inv = player:get_inventory()
	local def = gunslinger.__guns[stack:get_name()]
	local meta = stack:get_meta()

	if meta:contains("reloading") then
		return
	end

	local taken = inv:remove_item("main", def.ammo .. " " .. def.clip_size)
	if taken:is_empty() then
		play_sound(def.sounds.ooa, player)
	else
		local name = player:get_player_name()
		gunslinger.__interval[name] = gunslinger.__interval[name] - def.reload_time
		play_sound(def.sounds.reload, player)
		meta:set_string("reloading")
		local wear = math.floor(config.max_wear -
				(taken:get_count() / def.clip_size) * config.max_wear)
		minetest.after(def.reload_time, function()
			stack:set_wear(wear)
			meta:set_string("reloading", "")
			player:set_wielded_item(stack)
		end)
	end

	return stack
end

local function fire(stack, player)
	if not stack then
		return
	end

	local name = player:get_player_name()
	local def = gunslinger.__guns[stack:get_name()]
	if not def then
		return stack
	end

	local wear = stack:get_wear()
	if wear == config.max_wear then
		gunslinger.__automatic[name] = nil
		return reload(stack, player)
	end

	-- Play gunshot sound
	play_sound(def.sounds.fire, player)

	local pos = get_eye_pos(player)
	local dir = player:get_look_dir()

	-- Apply projectile engine to each pellet
	for i = 1, def.pellets do
		-- Mimic inaccuracy by applying randomized miniscule deviations
		-- Reduce inaccuracy by half if player is using scope
		if def.spread_mult ~= 0 then
			-- TODO: Unhardcode scoping factor by taking scope FOVs into consideration
			local scoping_factor = gunslinger.__scopes[name] and 0.5 or 1
			dir = vector.apply(dir, function(n)
				return n +
					random:next(-def.spread_mult, def.spread_mult) *
					config.base_spread * scoping_factor
			end)
		end

		--
		-- Progressive Raycasting
		--
		-- Tracks and simulates individual projectiles until they hit a target
		--

		-- Insert round_spec
		gunslinger.__rounds[#gunslinger.__rounds + 1] = {
			shooter = name,
			stack   = player:get_wielded_item(),

			initial_pos = pos,
			pos   = pos,
			dir   = dir,
			range = def.range,
			speed = config.projectile_speed
		}

		-- Projectile particle
		minetest.add_particle({
			pos = pos,
			velocity = vector.multiply(dir, config.projectile_speed),
			expirationtime = def.range / config.projectile_speed,
			size = 3,
			texture = def.textures.projectile,
			collisiondetection = true,
			collision_removal = true,
			object_collision = true,
			glow = 10
		})
	end

	-- Simulate recoil
	local offset = config.base_recoil * def.recoil_mult
	local look_vertical = player:get_look_vertical() - offset
	look_vertical = rangelim(-math.pi / 2, look_vertical, math.pi / 2)
	player:set_look_vertical(look_vertical)

	-- Update wear
	wear = stack:get_wear() + def.unit_wear
	if wear > config.max_wear then
		wear = config.max_wear
	end
	stack:set_wear(wear)

	return stack
end

local function burst_fire(stack, player)
	local def = gunslinger.__guns[stack:get_name()]
	for i = 1, def.burst do
		minetest.after(i / def.fire_rate, function(...)
			-- Use global var to store stack, because the stack
			-- can't be directly accessed outside minetest.after
			gunslinger.__stack[arg[2]:get_player_name()] = fire(arg[1], arg[2])
		end, stack, player)
	end

	return gunslinger.__stack[player:get_player_name()]
end

--------------------------------

local function handle_hit_target(shooter, pthing, stack)
	-- TODO: Run on_hit callbacks here

	if config.debug then
		local pthing_str
		if pthing.type == "object" then
			local obj = pthing.ref
			if obj:is_player() then
				pthing_str = "[Player] " .. obj:get_player_name()
			else
				pthing_str = "[Entity] " .. obj:get_luaentity()
			end
		else
			pthing_str = minetest.get_node(pthing.under).name
		end

		minetest.chat_send_all("handle_hit_target\n-----------------" ..
			"\n\tstack=" .. stack:to_string() .. "\n\tpthing=" .. pthing_str)
	end

	if pthing.type == "object" then
		pthing.ref:punch(shooter, nil, {damage_groups = {
			fleshy = config.base_dmg * gunslinger.__guns[stack:get_name()].dmg_mult
		}})
	end
end

--------------------------------

-- Progressive Raycasting
local function process_progressive_raycast(dtime)
	for i, round_spec in pairs(gunslinger.__rounds) do
		-- Calculate distance projectile can travel until next iteration
		local delta_range = round_spec.speed * dtime
		local pointed = get_pointed_thing(round_spec.pos,
			round_spec.dir, delta_range, true)

		-- We've hit something!
		if pointed then
			gunslinger.__rounds[i] = nil

			-- Invoke handle_hit_target, pass the required data
			handle_hit_target(minetest.get_player_by_name(round_spec.shooter),
				pointed, round_spec.stack)
		end

		-- We've hit nothing; continue tracking projectile
		local prev_pos = round_spec.pos
		round_spec.pos = vec.add(round_spec.pos,
			vec.multiply(round_spec.dir, delta_range))
		round_spec.dir = vec.direction(prev_pos, round_spec.pos)

		-- Spawn particles
		if config.debug then
			minetest.add_particle({
				pos = prev_pos,
				expirationtime = 10,
				size = 10,
				glow = 10
			})
		end
	end
end

minetest.register_globalstep(process_progressive_raycast)

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
		if def.zoom then
			show_scope(player, def.zoom, def.scope, def.scope_scale)
		end
	end
end

--------------------------------

-- Process automatic fire
local function auto_fire(dtime)
	for name in pairs(gunslinger.__interval) do
		gunslinger.__interval[name] = gunslinger.__interval[name] + dtime
	end
	if not config.lite then
		for name, info in pairs(gunslinger.__automatic) do
			local player = minetest.get_player_by_name(name)
			if not player or player:get_hp() <= 0 then
				gunslinger.__automatic[name] = nil
			elseif gunslinger.__interval[name] > info.def.unit_time then
				if player:get_player_control().LMB and
						player:get_wielded_item():get_name() ==
						info.stack:get_name() then
					-- If LMB pressed, fire
					info.stack = fire(info.stack, player)
					player:set_wielded_item(info.stack)
					if gunslinger.__automatic[name] then
						gunslinger.__automatic[name].stack = info.stack
					end
					gunslinger.__interval[name] = 0
				else
					gunslinger.__automatic[name] = nil
				end
			end
		end
	end
end

minetest.register_globalstep(auto_fire)

--
-- Public API functions
--

function gunslinger.get_config()
	return table.copy(config)
end

function gunslinger.get_def(name)
	return gunslinger.__guns[name]
end

function gunslinger.register_ammo(name, def)
	assert(type(name) == "string" and type(def) == "table",
		"gunslinger.register_ammo: Invalid params!")
	assert(not gunslinger.__ammo[name], "gunslinger.register_ammo:" ..
		" Attempt to register new ammo with an existing name!")

	-- TODO: Generalize sanitize_def to work with all definition tables
	assert(def.itemdef and type(def.itemdef) == "table",
		"gunslinger.register_ammo: Invalid Ammo Definition Table!")

	gunslinger.__ammo[name] = def
	minetest.register_craftitem(name, def.itemdef)
end

function gunslinger.register_type(name, def)
	assert(type(name) == "string" and type(def) == "table",
		"gunslinger.register_type: Invalid params!")
	assert(not gunslinger.__types[name], "gunslinger.register_type:" ..
		" Attempt to register new type with an existing name!")

	gunslinger.__types[name] = def
end

function gunslinger.register_gun(name, def)
	assert(type(name) == "string" and type(def) == "table",
		"gunslinger.register_gun: Invalid params!")
	assert(not gunslinger.__guns[name], "gunslinger.register_gun: " ..
		"Attempt to register new gun with an existing name!")

	-- Import type defaults if def.type specified
	-- This should be the first field to be parsed for the types system to work properly
	if def.type then
		assert(gunslinger.__types[def.type], "gunslinger.register_gun: Invalid type!")

		for attr, val in pairs(gunslinger.__types[def.type]) do
			def[attr] = val
		end
	end

	def = sanitize_def(def)

	-- Add additional helper fields for internal use
	def.unit_wear = math.ceil(config.max_wear / def.clip_size)
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
