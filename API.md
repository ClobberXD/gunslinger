# `gunslinger` API documentation

This file aims to thoroughly document the `gunslinger` code-base and API.

## Data structures

### Gun Definition Table (GDT)

- `itemdef` [table]: Item definition table passed to `minetest.register_item`.
  - Note that `on_use`, `on_place`, and `on_secondary_use` will be overridden.
- `clip_size` [number]: Number of rounds per-clip.
- `fire_rate` [number]: Number of rounds per-second.
- `range` [number]: Range of fire in number of nodes.
- `mode` [string]: Firing mode.
  - `"manual"`: One round per-click, but requires manual loading for every round; aka bolt-action rifles.
  - `"semi-automatic"`: One round per-click. e.g. a typical 9mm pistol.
  - `"burst"`: Multiple rounds per-click. Can be set by defining `burst` field. Defaults to 3. e.g. M16A4
  - `"automatic"`: Fully automatic; shoots as long as primary button is held down. e.g. AKM, M416.
  - `"hybrid"`: Same as `"automatic"`, but switches to `"burst"` mode when scope view is toggled.

- `ammo` [string]: Name of valid registered item to be used as ammo for the gun. Defaults to `gunslinger:ammo`.
- `dmg_mult` [number]: Damage multiplier. Multiplied with `base_dmg` to obtain initial/rated damage value. Defaults to 1.
- `spread_mult` [number]: Spread multiplier. Multiplied with `base_spread` to obtain spread threshold for projectile. Defaults to 0.
- `recoil_mult` [number]: Recoil multiplier. Multiplied with `base_recoil` to obtain final recoil per-round. Defaults to 0.
- `reload_time` [number]: Reload time in seconds. Defaults to 3 to match default reload sound.
- `pellets` [number]: Number of pellets per-round. Used for firing multiple pellets shotgun-style. Defaults to 1, meaning only one "pellet" is fired each round.
- `sounds` [table]: Sounds for various events.
  - `fire` [string]: Sound played on fire. Defaults to `gunslinger_fire.ogg`.
  - `reload` [string]: Sound played on reload. Defaults to `gunslinger_reload.ogg`.
  - `ooa` [string]: Sound played when the gun is out of ammo and ammo isn't available in the player's inventory. Defaults to `gunslinger_ooa.ogg`.
  - `load` [string]: Sound played when the gun is manually loaded. Only used if `mode` is set to `manual`.

- `zoom` [number]: Zoom multiplier to be applied on player's default FOV.
- `scope` [string]: Name of scope overlay texture.
  - Overlay texture would be stretched across the screen, and center of texture will be positioned on top of crosshair.
  - Only required if `zoom` is defined.
- `scope_scale` [table]: Passed to `ObjectRef:hud_add` for the field `scale`.
  - Needs to have two numerical values, indexed by `x` and `y`.
  - Either of the values can be negative, and would be taken as the percentage of that direction to scale to.
  - Only required if `scope` is defined.

## `gunslinger` namespace

The `gunslinger` namespace has the following members:

### "Private" members

(**Note**: _It's not recommended to directly access the private members of the `gunslinger` namespace_)

- `__guns` [table]: Table of registered guns.
- `__types` [table]: Table of registered types.
- `__automatic` [table]: Table of players wielding automatic guns.
- `__scopes` [table]: Table of HUD IDs of scope overlays.
- `__interval` [table]: Table storing time from last fire; used to regulate fire-rate.

### `gunslinger.register_type(name, def)`

- Registers a type for `name`.
- `def` [GDT]: Type defaults.

### `gunslinger.register_gun(name, def)`

- Registers a gun with the name `name`.
- `def` [GDT]: Gun properties.

### `gunslinger.get_def(name)`

- Retrieves the [GDT] of the given itemname. Returns `nil` if no registered gun matches `name`.

## Misc. helpers

### `rangelim(min, val, max, default)`

- Convenience function used for validating gun definition fields. Returns a range-limited value if `val` exists, or returns `default`.
- `min`, `max` [number]: Allowed minimum and maximum bounds for the value.
- `val` [number]: Value to be validated and returned.
- `default` [number]: Value to be returned if `val` is `nil`.

### `get_eye_pos(player)`

- Returns position of player eye in `v3f` format.
- Equivalent to

  ```lua
  local pos = player:get_pos()
  pos.y = pos.y + player:get_properties().eye_height
  ```

- `player` [ObjectRef]: Player whose eye position is to be calculated.

### `get_pointed_thing(pos, dir, range)`

- Helper function that performs a raycast from player in the direction of player's look dir, and up to the distance defined by `range`.
- `pos` [table]: Initial position of raycast.
- `dir` [table]: Direction of raycast.
- `range` [number]: Range of raycast from `pos` in nodes/meters.

### `play_sound(sound, obj)`

- Helper function to play object-centric sound.
- `sound` [SimpleSoundSpec]: Sound to be played.
- `obj` [ObjectRef]: ObjectRef which is the origin of the played sound.

## Internal API methods

### `add_auto(name, def, stack)`

- Helper function to add player entry to `automatic` table.
- `def` and `stack` are cached locally for improved performance.
- `name` [string]: Player name.
- `def` [GDT]: Wielded gun's GDT.
- `stack` [itemstack]: Itemstack of wielded item.

### `sanitize_def(def)`

- Helper function to check for and correct erroneous fields and to add default values for missing fields in a GDT.
- Returns the sanitized version of `def`.
- `def` [GDT]: GDT to be sanitized.

### `show_scope(player, scope, zoom)`

- Activates gun scope, handles placement of HUD scope element.
- `player` [ObjectRef]: Player used for HUD element creation.
- `scope` [string]: Name of scope overlay texture.
- `zoom` [number]: FOV that will override player's default FOV.

### `hide_scope(player)`

- De-activates gun scope, removes HUD element.
- `player` [ObjectRef]: Player to remove HUD element from.

### `on_lclick(stack, player)`

- `on_use` callback for all registered guns. This is where most of the firing logic happens.
- Handles gun firing depending on their `mode`.
- [`reload`] is called when the gun's magazine is empty.
- If `mode` is `"automatic"`, an entry is added to the `automatic` table which is parsed by `on_step`.
- `stack` [ItemStack]: ItemStack of wielditem.
- `player` [ObjectRef]: ObjectRef of user.

### `on_rclick(stack, player)`

- `on_place`/`on_secondary_use` callback for all registered guns. Toggles scope view.
- `stack` [ItemStack]: ItemStack of wielditem.
- `player` [ObjectRef]: Right-clicker.

### `reload(stack, player)`

- Reloads stack if ammo exists and plays `def.sounds.reload`. Otherwise, just plays `def.sounds.ooa`.
- Takes the same arguments as `on_lclick`.

### `fire(stack, player)`

- Responsible for firing one single round and dealing damage if target was hit. Updates wear by `def.unit_wear`.
- If gun is worn out, `reload` is called.
- Takes the same arguments as `on_lclick`.

### `burst_fire(stack, player)`

- Helper method to fire in burst mode.
- Takes the same arguments as `on_lclick`.

### `auto_fire(dtime)`

- Updates player's time from last shot (`gunslinger.__interval`).
- Calls `fire` for all guns in the `automatic` table if player's LMB is pressed.
- If LMB is released, the respective entry is removed from the table.
