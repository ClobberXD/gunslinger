# Gunslinger

Gunslinger is a ranged weapons API that allows mods to add realistic and
enjoyable guns to Minetest. A variety of different guns are provided with the
mod, and can be disabled if required (see [Settings](#settings)).

## License

- **Code**: MIT
- **Media**: CC0

`gunslinger_ammo.png` (placeholder ammo texture until a better one comes by) has
been taken from the `shooter` modpack by stujones11.

## Settings

- `gunslinger.lite` [`bool`] (defaults to `false`)
  - Toggles [lite mode](#lite-mode)
- `gunslinger.disable_builtin` [`bool`] (defaults to `false`)
  - Disables builtin guns - only the API will be provided.
  - Useful if mods/games provide custom guns.

## Architecture

### Type inheritance

Gunslinger makes use of gun _types_ in order to ease registration of similar
guns. A `type` is made up of a name and a table of default values to be applied
to all guns registered with that type. Types are optional, and can also be
omitted altogether. Guns are allowed to override their type defaults, for
maximum customizability.

### Ammo

Each type/gun needs to be associated with ammo (registered using
`gunslinger.register_ammo`). If a weapon definition doesn't explicitly define the
appropriate field, it will be automatically linked with the default ammo provided
by Gunslinger.

### Projectile Engine

Gunslinger uses the term "Projectile Engine" to refer to the code that handles
the tracking and control of fired projectiles. Once a projectile hits a target,
the damage to the target is equivalent to:

`base_dmg * def.dmg_mult` (base damage * gun's damage multiplier)

TODO: The default damage handling would be overridable by using on_hit callbacks.
If a gun specifies an `on_hit` callback, the default damage code would be
ignored.

#### Progressive Raycast

Progressive Raycast is the default projectile engine of Gunslinger. It technique
works by simulating the movement of a projectile along its trajectory every
server step. Once a target is hit by a projectile, the default damage code is run.

### Automatic guns

`gunslinger` supports automatic guns out of the box, while not causing excessive
lag. Nevertheless, disabling automatic guns (by enabling [lite mode](###Lite-mode))
is recommended on large public servers as it would still cause quite a bit of
lag, in spite of this optimization.

### Lite mode

Enabling lite mode will disable the non-essential features which are potentially
lag-inducing. Recommended for large public servers.

Note: As of now, enabling lite mode will only disable automatic guns, but there
are plans to allow lite mode to disable much more.

## API Documentation

See [API.md](API.md) for the complete gunslinger API documentation, including
the main API methods, internal and helper methods, data structures, etc.
