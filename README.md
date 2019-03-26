# Gunslinger

This mod provides an API to add a variety of realistic and enjoyable guns to Minetest. A variety of different guns are provided with the mod, and can be disabled if required.

## License

- **Code**: MIT
- **Media**: CC0

`gunslinger_ammo.png` (placeholder ammo texture until a better one comes by) has been taken from the `shooter` modpack by stujones11.

## Settings

- `gunslinger.lite` [`bool`] (defaults to `false`)
  - Toggles [lite mode](###Lite-mode)
- `gunslinger.disable_builtin` [`bool`] (defaults to `false`)
  - Enables/Disables builtin guns - only the API will be provided.
  - Useful if mods/games provide custom guns.

## Architecture

Gunslinger makes use of gun _types_ in order to ease registration of similar guns. A `type` is made up of a name and a table of default values to be applied to all guns registered with that type. Types are optional, and can also be omitted altogether. Guns are allowed to override their type defaults, for maximum customisability. `Raycast` is used to find target in line-of-sight, and all objects including non-player entities take damage. See [Deferred Raycasting](###Deferred-Raycasting) section to know more about gunslinger's projectile calculations.

Final damage is calculated like so:

- Initial/rated damage = `base_dmg * def.dmg_mult`
- If headshot, damage is increased by 50%
- If shooter was looking through scope, damage is increased by 20%

### Lite mode

Enabling lite mode will disable the realistic/fancy features which are potentially lag-inducing. Recommended for large servers.

> Note: As of now, enabling lite mode will only disable automatic guns, but there are plans to allow lite mode to disable much more (see #22).

### Automatic guns

`gunslinger` supports automatic guns out of the box, while not causing excessive lag. This is achieved by adding players who left-click while wielding automatic guns to a special list - the entry remains in the list only as long as their left mouse button is held down. A globalstep iterates through the table and fires one shot for all players in the list (while also respecting the fire-rate of the wielded guns).

The use of a dedicated list improves performance greatly, as the globalstep would have to otherwise iterate through **all** connected players, check if their mouse button is down, and only then, fire a shot. Nevertheless, disabling automatic guns (by enabling [lite mode](###Lite-mode)) is recommended on large public servers as it would still cause quite a bit of lag, in spite of this optimisation.

### Deferred Raycasting

Deferred Raycasting is a technique which adds the realism of entity-based projectiles, but without entities. This technique throws in a couple more calculations and an extra raycast, but the vastly improved realism at the cost of a negligible performance hit is always great to have. Here's how it works:

- Perform initial raycast to get position of target if it exists.
- Calculate time taken for projectile to travel from gun to target.
- Perform actual raycast after the calculated time.

### See [API.md](API.md) for the complete gunslinger API reference
