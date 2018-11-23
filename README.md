# Gunslinger

This mod provides an API to add a variety of realistic and enjoyable guns to Minetest. A variety of different guns are provided with the mod, and can be disabled if required.

## License

- **Code**: MIT
- **Media**: CC0

## Architecture

Gunslinger makes use of gun _types_ in order to ease registration of similar guns. A `type` is made up of a name and a table of default values to be applied to all guns registered with that type. At least one type needs to be registered in order to register guns. Guns are also allowed to override their type defaults, for the maximum customisability possible.

`Raycast` is used to find target in line-of-sight, and all objects take damage. Damage is calculated as detailed in [Damage calculation](##Damage-calculation)

## Damage calculation

Weapon damage = `def.type.base_dmg * def.dmg_mult`

If headshot, damage is increased by 50%

If shooter was looking through scope, damage is increased by 20%
