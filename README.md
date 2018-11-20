# Gunslinger

This mod provides an API to add a variety of realistic and enjoyable guns to Minetest. A variety of different guns are provided with the mod, and can be disabled if required.

## License

- **Code**: MIT
- **Media**: CC0

## Architecture

Gunslinger makes use of gun _types_ in order to ease registration of similar guns. A `type` is made up of a name and a table of default values to be applied to all guns registered with that type. At least one type needs to be registered in order to register guns.

`Raycast` is used to find target in line-of-sight, and all objects take damage. Damage is calculated as detailed in [Damage calculation](###Damage-calculation)

## API

### Damage calculation

Weapon damage = `def.type.base_dmg * def.dmg_mult`

If headshot, damage is increased by 50%

If shooter was looking through scope, damage is increased by 20%

### Methods

#### `gunslinger.register_type(name, def)`

- Registers a def table for the type `name`.
- The def table contains the default values for all the guns registered with this type. e.g. `style_of_fire`, `enable_scope`, etc.

#### `gunslinger.register_gun(name, def)`

- Registers a gun with the type `def.type`, and assigns the type defaults to the gun.
- The def table contains gun-specific values like `clip_size`, `wield_image`, `scope_image`, etc.
- Default type values can also be overridden per gun by just including that value in the def table.

### Definition table fields used by API methods

#### Fields passed to `gunslinger.register_type`

- `type` [string]: Name of a valid type (i.e. type registered by `gunslinger.register_type`)
- `style_of_fire` [string]: Sets style of fire
  - `"manual"`: One shot per-click.
  - `"burst"`: Three shots per-click.
  - `"splash"`: Shotgun-style pellets; one burst per-click.
  - `"automatic"`: Fully automatic; shoots as long as primary button is held down.
  - `"semi-automatic"`: Same as `"automatic"`, but switches to `"burst"` when scope view is toggled.
- `scope` [string]: Sets style of scope.
  - `"none"`: Default. No scope functionality.
  - `"ironsight"`: Ironsight, without zoom. Unrestricted peripheral vision
  - `"scope"`: Proper scope, with zoom. Restricted peripheral vision.
- `base_dmg` [number]: Base amount of damage dealt in HP.

#### Fields passed to `gunslinger.register_gun`

- `itemdef` [table]: Item definition table passed to `minetest.register_item`.
- `fire_sound` [string]: Name of ogg sound file without extension. Played on fire.
- `scope_overlay` [string]: Name of scope overlay texture. Must be provided if `scope` is defined. Overlay texture would be stretched across the screen.
- `clip_size` [number]: Number of bullets per-clip.
- `fire_rate` [number]: Number of shots per-second.
- `dmg_mult` [number]: Damage multiplier value. Final damage is calculated by multiplying `dmg_mult` with the type's `base_dmg`.
