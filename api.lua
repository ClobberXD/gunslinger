gunslinger = {}

local max_wear = 65534
local lite = minetest.settings:get_bool("gunslinger.lite")

local guns = {}
local types = {}
local automatic = {}
local scope_overlay = {}

--
-- Internal API functions
--

local function play_sound(sound, player)
	minetest.sound_play(sound, {
		object = player,
		loop = false
	})
end

local function add_auto(name, def)
	automatic[name] = {
		def  = def,
		time = os.time() + (1 / def.fire_rate)
	}
end

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

local function fire(stack, player)
	local def = gunslinger.get_def(stack:get_name())

	if not def or not stack then
		return
	end

	-- Play gunshot sound
	play_sound(def.fire_sound or "gunslinger_fire1")

	-- Take aim
	local eye_offset = {x = 0, y = 1.625, z = 0} --player:get_eye_offset().offset_first
	local p1 = vector.add(player:get_pos(), eye_offset)
	p1 = vector.add(p1, player:get_look_dir())
	local p2 = vector.add(p1, vector.multiply(player:get_look_dir(), def.range))
	local ray = minetest.raycast(p1, p2)
	local pointed = ray:next()

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

		target:set_hp(target:get_hp() - dmg)
	end

	-- Projectile particle
	-- TODO

	-- Update wear
	local wear = stack:get_wear()
	wear = wear + def.unit_wear
	if wear > max_wear then
		wear = max_wear
	end
	stack:set_wear(wear)

	return stack
end

local function burst_fire(stack, player)
	local def = gunslinger.get_def(stack:get_name())
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

local function on_lclick(stack, player)
	if not stack or not player then
		return
	end

	local wear = stack:get_wear()
	local def = gunslinger.get_def(stack:get_name())
	if wear == max_wear then
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
	else
		local name = player:get_player_name()

		if def.style_of_fire == "automatic" and not automatic[name] then
			add_auto(name, def)
		elseif def.style_of_fire == "semi-automatic"
				and not automatic[name] then
			if scope_overlay[name] then
				stack = burst_fire(stack, player)
			else
				add_auto(name, def)
			end
		elseif def.style_of_fire == "burst" then
			stack = burst_fire(stack, player)
		elseif def.style_of_fire == "manual" then
			stack = fire(stack, player)
		elseif def.style_of_fire == "splash" then
			stack = splash_fire(stack, player)
		end
	end

	return stack
end

local function on_rclick(stack, player)
	local def = gunslinger.get_def(stack:get_name())
	if scope_overlay[player:get_player_name()] then
		hide_scope(player)
	else
		if def.scope then
			show_scope(player, def.scope, def.scope_overlay)
		end
	end

	return stack
end

local function on_step(dtime)
	for name, info in pairs(automatic) do
		local player = minetest.get_player_by_name(name)
		if player:get_player_control().LMB then
			if os.time() > info.time then
				-- If LMB pressed, fire
				local stack = player:get_wielded_item()
				player:set_wielded_item(fire(stack, player))
			end
		else
			-- If LMB not pressed, remove player from list
			automatic[name] = nil
		end
	end
end

if lite then
	minetest.register_globalstep(on_step)
end

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
			   "gunslinger.register_type: Invalid params!")
	assert(not guns[name], "gunslinger.register_gun:"
			.. " Attempt to register a gun with an existing name!")

	-- Import type defaults if def.type specified
	if def.type then
		assert(types[def.type], "gunslinger.register_gun: Invalid type!")

		for name, val in pairs(types[def.type]) do
			def[name] = val
		end
	end

	-- Abort when making use of unimplemented features
	if def.style_of_fire == "splash" or def.zoom then
		error("register_gun: Unimplemented feature!")
	end

	if def.style_of_fire:find("automatic") and not lite then
		error("gunslinger.register_gun: Attempt to register gun of"
				.. " disabled type '" .. def.style_of_fire .. "'")
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

	if def.zoom and not def.scope then
		error("gunslinger.register_gun: zoom requires scope to be defined!")
	end

	def.unit_wear = math.ceil(max_wear / def.clip_size)

	guns[name] = def
	minetest.register_tool(name, def.itemdef)
end
