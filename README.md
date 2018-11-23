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

### See API.md for the complete gunslinger API reference
