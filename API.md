# API documentation

This file aims to document all the internal and external methods of the `gunslinger` API.

## Helper functions

### `play_sound(sound, obj)`

- Helper function to play object-centric sound.
- `sound` [SimpleSoundSpec]: Sound to be played.
- `obj` [ObjectRef]: Origin of the played sound.

## External API methods

### `gunslinger.register_type(name, typedef)`

- Registers a type for `name`.
- `typedef` [table]: [Type definition table](###Type-definition).

### `gunslinger.register_gun(name, gundef)`

- Registers a gun with the name `name`.
- `gundef` [table]: [Gun definition table](###Gun-definition).

### `gunslinger.get_def(name)`

- Retrieves the [Gun definition](###Gun-definition) of `name`.

## Internal API methods

### `show_scope(player, def)`

- Activates gun scope, handles placement of HUD scope element.
- `player` [ObjectRef]: Player obj. used for HUD element creation.
- `def` [Gun Definition]: Gun def used for retrieving scope type and scope overlay.

### `hide_scope(player)`

- De-activates gun scope, removes HUD element.
- `player` [ObjectRef]: Player obj. to remove HUD element from.

### `on_lclick(stack, player)`

- `on_use` callback for all registered guns. This is where most of the firing logic happens.
- Handles gun firing depending on their `style_of_fire`.
- [`reload`] is called when the gun's magazine is empty.
- If `style_of_fire` is `"automatic"`, an entry is added to the `automatic` table which is parsed by the `on_step` globalstep.
- `stack` [ItemStack]: ItemStack of wielditem.
- `player` [ObjectRef]: ObjectRef of user.

### `on_rclick(stack, player)`

- `on_place`/`on_secondary_use` callback for all registered guns. Toggles scope view.
- `stack` [ItemStack]: ItemStack of wielditem.
- `player` [ObjectRef]: ObjectRef of user.

### `fire(stack, player)`

- Responsible for firing one single shot and dealing damage if required. Reduces ammo based on `clip_size`.
- `stack` [ItemStack]: ItemStack passed by `on_lclick`.
- `player` [ObjectRef]: Shooter player passed by `on_lclick`.

### `reload(stack, player)`

- Reloads gun in `stack` if there's ammo in player inventory. Else, plays a click sound.
- `stack` [ItemStack]: ItemStack passed by `on_lclick`.
- `player` [ObjectRef]: Shooter player passed by `on_lclick`.

### `on_step(dtime)`

- This is the globalstep callback that's responsible for firing automatic guns.
- This works by calling `fire` for all guns in the `automatic` table if player's LMB is pressed.
- If LBM is released, the respective entry is removed from the table.

## Definition tables

### Type definition

- `style_of_fire` [string]: Sets style of fire.
  - `"manual"`: One shot per-click.
  - `"burst"`: Three rounds per-click.
  - `"splash"`: Shotgun-style pellets; one burst per-click.
  - `"automatic"`: Fully automatic; shoots as long as primary button is held down.
  - `"semi-automatic"`: Same as `"automatic"`, but switches to `"burst"` when scope view is toggled.
- `scope` [string]: Sets style of scope.
  - `"none"`: Default. No sight/scope functionality.
  - `"sight"`: Sight, without zoom. Unrestricted peripheral vision.
  - `"scope"`: Proper scope, with zoom. Restricted peripheral vision.
- `base_dmg` [number]: Base amount of damage dealt in HP.

### Gun definition

- `itemdef` [table]: Item definition table passed to `minetest.register_item`.
- `fire_sound` [string]: Name of ogg sound file without extension. Played on fire.
- `scope_overlay` [string]: Name of scope overlay texture. Must be provided if `scope` is defined. Overlay texture would be stretched across the screen.
- `clip_size` [number]: Number of bullets per-clip.
- `fire_rate` [number]: Number of shots per-second.
- `dmg_mult` [number]: Damage multiplier value. Final damage is calculated by multiplying `dmg_mult` with the type's `base_dmg`.
- `range` [number]: Range of fire in number of nodes.
