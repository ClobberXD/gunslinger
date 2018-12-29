# Gunslinger

This mod provides an API to add a variety of realistic and enjoyable guns to Minetest. A variety of different guns are provided with the mod, and can be disabled if required.

## License

- **Code**: MIT
- **Media**: CC0

## Architecture

Gunslinger makes use of gun _types_ in order to ease registration of similar guns. A `type` is made up of a name and a table of default values to be applied to all guns registered with that type. Types are optional, and can also be omitted altogether. Guns are allowed to override their type defaults, for maximum customisability. `Raycast` is used to find target in line-of-sight, and all objects including non-player entities take damage.

Final damage is calculated like so:

- Initial/rated damage = `def.base_dmg`
- If headshot, damage is increased by 50%
- If shooter was looking through scope, damage is increased by 20%

### Automatic guns

`gunslinger` supports automatic guns out of the box, while not causing excessive lag. This is achieved by adding players who left-click while wielding automatic guns to a special list, and the entry remains in the list only as long as their left mouse button is held down. A globalstep iterates through the table and fires one shot for all players in the list (while also respecting the fire-rate of the wielded guns).

The use of a dedicated list improves performance greatly, as the globalstep would have to otherwise iterate through **all** connected players, check if their mouse button is down, and only then, fire a shot. Nevertheless, disabling automatic guns is recommended on large public servers as it would cause quite a bit of lag, in spite of this optimisation.

`gunslinger` provides a setting `"gunslinger.enable_automatic"`. Disabling this setting will throw an error when an automatic gun is registered.

## TODO

- Gun perks (special effects when bullet finds its target)
- Visible projectiles and entity-based collision/damage system.
- Customisable recoil per-gun.

### See API.md for the complete gunslinger API reference
