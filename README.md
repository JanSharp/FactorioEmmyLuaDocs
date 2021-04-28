
# Setup

If some requires don't work, make sure your environment variables for lua,
if you have then overwritten that is, still include `./?.dll` and `./?.lua` respectively.
(one being for c path the other for regular lua path thing. also use the right separators
for your system, on windows it shouldn't matter i believe.)

# running the script

Put the source data file in `source_data/api.json`.
Then run this in the root directory of the project:
```
./lua main.lua -- --source-file source_data/api.json --cache-dir cache --target-dir output
```
(for some reason git bash wants that `./` at the start. Idk why.)

# Story about debugging and cache

The debugger makes loading the json file take several seconds, maybe even a minute.
That's why the cache exists.
To validate the cache is up to date the script stores the crc32 of the source file
and checks that against the source file every time it runs.
Calculating the crc32 of said sorce file takes even longer than loading the json file
with the debugger enabled.
That's why `--debug-api-json-crc` exists. It bypasses calculating the crc32 and just
uses what you give it.
Then we are left with just loading the cache file which is nearly instant even with
the debugger enabled.
This means if you are debugging and using `--debug-api-json-crc` you need to remove
that whenever you change the source file, let it parse the source file and write the
new data to the cache as well as the new crc32. Then copy that crc32 from the file in
the cache dir and use that for `--debug-api-json-crc` again.
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
But i'm pretty sure i'm not even using anything the plugin provides. I just added it at the start
because i thought i'd want to use it.
