# `gunslinger` API documentation

This file aims to thoroughly document the `gunslinger` API.

## `gunslinger` namespace

(**Note**: _It's not recommended to directly access the private members in the `gunslinger` namespace_)

The `gunslinger` namespace has the following members:

### "Private" members

- `__guns` [table]: Table of registered guns.
- `__types` [table]: Table of registered types.
- `__automatic` [table]: Table of players weilding automatic guns.
- `__scopes` [table]: Table of HUD IDs of scope overlays.
- `__interval` [table]: Table storing time from last fire; used to regulate fire-rate.

### `gunslinger.register_type(name, def)`

- Registers a type for `name`.
- `def` [table]: [Gun definition table](###Gun-definition-table).

### `gunslinger.register_gun(name, def)`

- Registers a gun with the name `name`.
- `def` [table]: [Gun definition table](###Gun-definition-table).

### `gunslinger.get_def(name)`

- Retrieves the [Gun definition table](###Gun-definition-table).

## Internal methods

### `eye(player)`

- Returns player eye-height in `v3f` format. i.e. `{x = 0, y = player:get_properties().eye_height, z = 0}`
- `player` [ObjectRef]: Player whose eye-height is returned.

### `get_pointed_thing(player, def)`

- Helper function that performs a raycast from player in the direction of player's look dir, and upto the range defined by `def.range`.
- `player` [ObjectRef]: Player from which the raycast originates.
- `def` [table]: [Gun definition table](###Gun-definition-table).

### `play_sound(sound, obj)`

- Helper function to play object-centric sound.
- `sound` [SimpleSoundSpec]: Sound to be played.
- `obj` [ObjectRef]: ObjectRef which is the origin of the played sound.

### `add_auto(name, def, stack)`

- Helper function to add player entry to `automatic` table.
- `def` and `stack` are cached locally for improved performance.
- `name` [string]: Player name.
- `def` [table]: [Gun definition table](###Gun-definition-table) of wielded item.
- `stack` [itemstack]: Itemstack of wielded item.

### `show_scope(player, scope, zoom)`

- Activates gun scope, handles placement of HUD scope element.
- `player` [ObjectRef]: Player obj. used for HUD element creation.
- `scope` and `zoom`: Gun definition fields.

### `hide_scope(player)`

- De-activates gun scope, removes HUD element.
- `player` [ObjectRef]: Player obj. to remove HUD element from.

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
- `player` [ObjectRef]: ObjectRef of user.

### `reload(stack, player)`

- Reloads stack if ammo exists and plays `def.sounds.reload`. Otherwise, just plays `def.sounds.ooa`.
- `stack` [ItemStack]: ItemStack of wielded item; passed by `on_lclick`.
- `player` [ObjectRef]: Player whose gun requires reloading; passed by `on_lclick`.

### `fire(stack, player)`

- Responsible for firing one single round and dealing damage if target was hit. Updates wear by `def.unit_wear`.
- If gun is worn out, `reload` is called.
- `stack` [ItemStack]: ItemStack passed by `on_lclick`.
- `player` [ObjectRef]: Shooter player passed by `on_lclick`.

### `burst_fire(stack, player)`

- Helper method to fire in burst mode. Takes the same arguments as `fire`.

### `splash_fire(stack, player)`

- Helper method to fire shotgun-style. Takes the same arguments as `fire`.

### `on_step(dtime)`

- Updates player's time from last shot (`gunslinger.__interval`).
- Calls `fire` for all guns in the `automatic` table if player's LMB is pressed.
- If LMB is released, the respective entry is removed from the table.

## Gun Definition table

- `itemdef` [table]: Item definition table passed to `minetest.register_item`.
  - Note that `on_use`, `on_place`, and `on_secondary_use` will be overridden.
- `clip_size` [number]: Number of rounds per-clip.
- `fire_rate` [number]: Number of rounds per-second.
- `range` [number]: Range of fire in number of nodes.
- `dmg_mult` [number]: Damage multiplier. Multiplied by `base_dmg` to obtain final damage value.
- `mode` [string]: Firing mode.
  - `"manual"`: One round per-click, but requires manual loading for every round; aka bolt-action rifles.
  - `"semi-automatic"`: One round per-click. e.g. a typical 9mm pistol.
  - `"burst"`: Multiple rounds per-click. Can be set by defining `burst` field. Defaults to 3. e.g. M16A4
  - `"splash"`: **(WARNING: Unimplemented)** Shotgun-style pellets; one round per-click. e.g. Remington Model 870, Winchester 94
  - `"automatic"`: Fully automatic; shoots as long as primary button is held down. e.g. AKM, M416.
  - `"hybrid"`: Same as `"automatic"`, but switches to `"burst"` mode when scope view is toggled.

- `scope` [string]: Name of scope overlay texture.
  - Overlay texture would be stretched across the screen, and center of texture will be positioned on top of crosshair.
- `zoom` [number]: **(WARNING: Unimplemented)** Sets player FOV in degrees when scope is enabled (defaults to no zoom)
  - Requires `scope` to be defined.

- `sounds` [table]: List of sounds for various events.
  - `fire` [string]: Sound played on fire. Defaults to `gunslinger_fire`.
  - `reload` [string]: Sound played on reload. Defaults to `gunslinger_reload`.
  - `ooa` [string]: Sound played when the gun is out of ammo and ammo isn't available in the player's inventory. Defaults to `gunslinger_ooa`.
  - `load` [string]: Sound played when the gun is manually loaded. Only required if `def.mode` is set to `manual`.
