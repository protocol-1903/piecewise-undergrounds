[![ko-fi](https://img.shields.io/badge/Ko--fi-Donate%20-hotpink?logo=kofi&logoColor=white&style=for-the-badge)](https://ko-fi.com/protocol1903) [![](https://img.shields.io/badge/dynamic/json?color=orange&label=Factorio&query=downloads_count&suffix=%20downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fpiecewise-undergrounds&style=for-the-badge)](https://mods.factorio.com/mod/piecewise-undergrounds) [![](https://img.shields.io/badge/Discord-Community-blue?style=for-the-badge)](https://discord.gg/K3fXMGVc4z) [![](https://img.shields.io/badge/Github-Source-green?style=for-the-badge)](https://github.com/protocol-1903/piecewise-undergrounds)

# This mod alters existing undergrounds. It is incredibly finicky, so mod compatability is hard and may take time. It is not garunteed.

## What?
Piecewise Undergrounds builds undergrounds and consumes pipes based on how long they are, instead of just requiring some for the recipe (because how does that make sense)
Please report any bugs here or on [github](https://github.com/protocol-1903/piecewise-undergrounds)

## Future plans
Belts! I plan to fully support belts once pipes are working 100%. There are still a few bugs to iron out, so they aren't implemented for now.

## Compatability
Probably won't be compatible with most mods that add unique pipes/pipe mechanics, if something breaks, let me know.

Due to implementation limitations, underground pipes can't be mixed (where an underground of one type connects to an underground of another type). This is not an issue and will not be fixed. However, variations of the same type (like those added by [Pipes Plus](https://mods.factorio.com/mod/pipe_plus)) can be supported, but are not explicitly supported by default.

## Known compatibility:
- Pymods
- [RGB Pipes](https://mods.factorio.com/mod/RGBPipes)
- [Color Coded Pipes](https://mods.factorio.com/mod/color-coded-pipes)

## Known incompatibility:
- [Actual Underground Pipes](https://mods.factorio.com/mod/the-one-mod-with-underground-bits): does vastly different things. It's trying to mate two different systems that don't work together.
- [Advanced Fluid Handling](https://mods.factorio.com/mod/underground-pipe-pack): because AFH has undergrounds with multiple connections, it would be incredibly difficult to get working with how this mod is implemented. It will not be supported.
- [Pipes Plus](https://mods.factorio.com/mod/pipe_plus): Not currently supported. If desired, will be supported in the future.

If you wish to add compatibility with a mod, talk to me on here or discord so we can sort it out.