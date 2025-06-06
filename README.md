[![ko-fi](https://img.shields.io/badge/Ko--fi-Donate%20-hotpink?logo=kofi&logoColor=white&style=for-the-badge)](https://ko-fi.com/protocol1903) [![](https://img.shields.io/badge/dynamic/json?color=orange&label=Factorio&query=downloads_count&suffix=%20downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fpiecewise-undergrounds&style=for-the-badge)](https://mods.factorio.com/mod/piecewise-undergrounds) [![](https://img.shields.io/badge/Discord-Community-blue?style=for-the-badge)](https://discord.gg/K3fXMGVc4z) [![](https://img.shields.io/badge/Github-Source-green?style=for-the-badge)](https://github.com/protocol-1903/piecewise-undergrounds)

# This mod alters existing undergrounds. It is incredibly finicky, so mod compatability is hard and may take time. It is not garunteed.
### Please report any bugs here or on [github](https://github.com/protocol-1903/piecewise-undergrounds)

## What?
After some development into [Actual Underground Pipes](https://mods.factorio.com/mod/the-one-mod-with-underground-bits), I realized that there was a second, different alteration I could make to the fluid system mechanics to give it more depth. Now, when you place undergrounds, you will only consume as many pipes as needed to span that distance. It fully supports bots, modded pipes, pipe braiding, fluid shenanigans, rotation, undo, redo, NPT, CCP, and more.

Piecewise Undergrounds builds undergrounds and consumes pipes based on how long they are, instead of just requiring some for the recipe (because how does that make sense)

## How does it work?
Just place the pipe to grounds down, and the mod will take pipes from your inventory to complete them. It works with bots, too. If you don't have enough pipes in your inventory, just hover over the incomplete pipe to grounds and the mod will attempt to complete them.

## Future plans
Belts! I plan to fully support belts once pipes are working 100%. There are still a few bugs to iron out, so they aren't implemented for now.

## Compatability
Probably won't be compatible with most mods that add unique pipes/pipe mechanics, if something breaks, let me know.

Due to implementation limitations, underground pipes can't be mixed (where an underground of one type connects to an underground of another type). This is not an issue and will not be fixed. However, variations of the same type (like those added by [Pipes Plus](https://mods.factorio.com/mod/pipe_plus)) can be supported, but are not implicitly supported by default.

## Known issues:
- When placing pipe to grounds, they will not automatically rotate to the other direction after placing one down. As far as I know there is no way to implement that in scripting.
- (Related to previous issue) When drag-placing pipe to grounds, it will continually place them in a line. I again don't think this is fixable via script.

## Known compatibility:
- Pymods
- [RGB Pipes](https://mods.factorio.com/mod/RGBPipes)
- [Color Coded Pipes](https://mods.factorio.com/mod/color-coded-pipes)

## Known incompatibility:
- [Actual Underground Pipes](https://mods.factorio.com/mod/the-one-mod-with-underground-bits): does vastly different things. It's trying to mate two different systems that don't work together.
- [Advanced Fluid Handling](https://mods.factorio.com/mod/underground-pipe-pack): because AFH has undergrounds with multiple connections, it would be incredibly difficult to get working with how this mod is implemented. It will not be supported.
- [Pipes Plus](https://mods.factorio.com/mod/pipe_plus): Not currently supported. If desired, will be supported in the future.

If you wish to add compatibility with a mod, talk to me on here or discord so we can sort it out.

Thumbnail courtesy of JigSaW on Discord.

### Some history:
https://discord.com/channels/139677590393716737/1217399815370182696/1317458797899284510
https://discord.com/channels/139677590393716737/1217399815370182696/1346257323496181823
https://discord.com/channels/139677590393716737/1217399815370182696/1373940206675165274