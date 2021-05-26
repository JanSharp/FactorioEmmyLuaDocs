
# Private Repo

For the duration of this repo being private and you who is reading this being
a collaborator i (as a user account) don't have the ability to disallow you to
push to the repo, however i would ask you to basically treat it as if it was a
public repo and you weren't a collaborator. Thank you!

# running the script

Put the source data file in `source_data/runtime-api.json`.
Then run this in the root directory of the project:
```
./lua main.lua -- --source-file source_data/runtime-api.json --target-dir output
```
(for some reason git bash wants that `./` at the start. Idk why.)

if you want the cache which is currently really just useful for debugging performace:
```
./lua main.lua -- --source-file source_data/runtime-api.json --target-dir output --cache-dir cache
```

## Working with sumneko.lua

Once you have `sumneko.lua` installed, add the output directory of this script to the `Lua.workspace.library` setting.

Additionally `sumneko.lua` has a limit on file size and file count for preloading files,
specifically the `Lua.workspace.preloadFileSize` _has to be_ increased for this, and to be save for the future,
might as well increase `Lua.workspace.maxPreload`.

For example (i just went with stupid numbers):
```json
"Lua.workspace.library": [
  "C:/Dev/FactorioEmmyLuaDocs/output",
],
"Lua.workspace.preloadFileSize": 1000000,
"Lua.workspace.maxPreload": 1000000,
```

### Plugin

The [FactorioSumnekoLuaPlugin](https://github.com/JanSharp/FactorioSumnekoLuaPlugin) is another thing you can use to improve
the experience working with factorio and sumneko.lua, if you are willing to deal with sumneko.lua being drunk a bit more often because of it,
though it's not that bad. For installation of the plugin see it's readme.

## Issues running the script

If some requires don't work, make sure your environment variables for lua,
if you have them overwritten that is, still include `./?.dll` and `./?.lua` respectively.
(one being for c path the other for regular lua path thing. also use the right separators
for your system, on windows it shouldn't matter i believe.)

## Arguments

- `--source-file` (Required) Relative or full path of the source json file including name and extension.
- `--target-dir` (Required) Relative or full path of the dir all generated files will be stored in.
- `--cache-dir` Relative or full path of the dir cache files will be stored in/read from. Cache automatically gets invalidated if the source file is different using the crc32 of said file. If ommited no caching takes place.
- `--disable-specific-diagnostics` By default all diagnostics get disabled in all generated files in the hopes of that improving performance. If that is not desired you may define this followed by any number of strings defining which diagnostics to disable. If there are 0 given, no diagnostics get disabled, however you most definitely want to disable `trailing-space` at the very least because that is currently used for linebreaks in the markdown descriptions.\
  Since There should be zero other infos, warnings or errors in the generated files this argument is mostly considered useful for debugging.
- `--debug-runtime-api-json-crc` See "Story about debugging and cache".

# Story about debugging and cache

The debugger makes loading the json file take several seconds, maybe even a minute.
That's why the cache exists.
To validate the cache is up to date the script stores the crc32 of the source file
and checks that against the source file every time it runs.
Calculating the crc32 of said source file takes even longer than loading the json file
with the debugger enabled.
That's why `--debug-runtime-api-json-crc` exists. It bypasses calculating the crc32 and just
uses what you give it.
Then we are left with just loading the cache file which is nearly instant even with
the debugger enabled.
This means if you are debugging and using `--debug-runtime-api-json-crc` you need to remove
that whenever you change the source file, let it parse the source file and write the
new data to the cache as well as the new crc32. Then copy that crc32 from the file in
the cache dir and use that for `--debug-runtime-api-json-crc` again.
The End.

# Libs

From the internet, smile:
- [lua](http://www.lua.org/)
- [LuaFileSystem](https://keplerproject.github.io/luafilesystem/)
- [The json lib](https://github.com/rxi/json.lua)
- [crc32](https://gist.github.com/SafeteeWoW/080e784e5ebfda42cad486c58e6d26e4)
- [serpent](https://github.com/pkulchenko/serpent)

The following are from the [LuaPreprocessor](https://github.com/JanSharp/FactorioLuaPreprocessor) project and should be moved to a library project:
- args_service.lua (modified to fit this project's args)
- args_util.lua
- path.lua
- classes.lua (this has been updated in this repository)

# Submodules

If you want the submodule you can do something like this iirc:
```
git submodule init
git submodule update
```
But i hardly use anything the plugin provides. I think a few `---@typelist` or `---@narrow` annotations here and there.
