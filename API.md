# `gunslinger` API documentation

This file aims to document all the internal and external methods of the `gunslinger` API.

## External API methods

### `gunslinger.register_type(name, def)`

- Registers a type for `name`.
- `def` [table]: [Gun definition table](###Gun-definition-table).

### `gunslinger.register_gun(name, def)`

- Registers a gun with the name `name`.
- `def` [table]: [Gun definition table](###Gun-definition-table).

### `gunslinger.get_def(name)`

- Retrieves the [Gun definition table](###Gun-definition-table).

## Internal API methods

### `play_sound(sound, obj)`

- Helper function to play object-centric sound.
- `sound` [SimpleSoundSpec]: Sound to be played.
- `obj` [ObjectRef]: Origin of the played sound.

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

### `fire(stack, player)`

- Responsible for firing one single shot and dealing damage if required. Reduces ammo based on `clip_size`.
- If gun is worn out, reloads gun in `stack` if there's ammo in player inventory; else, plays a click sound.
- `stack` [ItemStack]: ItemStack passed by `on_lclick`.
- `player` [ObjectRef]: Shooter player passed by `on_lclick`.

### `burst_fire(stack, player)`

- Helper method to fire in burst mode. Takes the same arguments as `fire`.

### `on_step(dtime)`

- This is the globalstep callback that's responsible for firing automatic guns.
- This works by calling `fire` for all guns in the `automatic` table if player's LMB is pressed.
- If LMB is released, the respective entry is removed from the table.

## Gun Definition table

- `itemdef` [table]: Item definition table passed to `minetest.register_item`.
  - Note that `on_use`, `on_place`, and `on_secondary_use` will be overridden.
- `ammo` [itemstring]: What type of ammo to use when reloading.
- `clip_size` [number]: Number of bullets per-clip.
- `fire_rate` [number]: Number of shots per-second.
- `range` [number]: Range of fire in number of nodes.
- `spread` [number]: How much bullets will spread away from the cursor.(0 is nothing, 1000 is anywhere in front of the player (I think))
- `base_dmg` [number]: Base amount of damage dealt in HP.
- `pellets` [number]: Number of bullets per shot, used for shotguns.
- `mode` [string]: Firing mode.
  - `"manual"`: One shot per-click, but requires manual loading for every round; aka Bolt-action.
  - `"semi-automatic"`: One shot per-click.
  - `"burst"`: Multiple rounds per-click. Can be set by defining `burst` field. Defaults to 3.
  - `"automatic"`: Fully automatic; shoots as long as primary button is held down.
  - `"hybrid"`: Same as `"automatic"`, but switches to `"burst"` mode when scope view is toggled.

- `scope` [string]: Name of scope overlay texture.
  - Overlay texture would be stretched across the screen, and center of texture will be positioned on top of crosshair.
- `zoom` [number]: **(WARNING: Unimplemented)** Sets player FOV in degrees when scope is enabled (defaults to 0, i.e. no zoom)
  - Requires `scope` to be defined.

- `fire_sound` [string]: Name of .ogg sound file without extension. Played on gun-fire.
