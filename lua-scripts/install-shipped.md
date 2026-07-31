# Enabling darktable's bundled Lua scripts
This sscript is shipped with darktable, you don't need to download it or install it.

> **Prerequisite:** darktable must have Lua support. Check under
> **preferences → lua options**. Start darktable once first so it creates its
> config folders.

## darktable 5.6 and newer
The scripts are **bundled with darktable** — nothing to install.

1. In the **lighttable** view, open the **scripts** module (lower-left panel).
2. Choose which scripts to turn on under **preferences → lua**, or toggle them from
   the module. Scripts are grouped by **official / contrib / tools** (the `group`
   field in each `meta.json`).
3. Click a script to **start/stop** it; the change takes effect immediately.

## Older darktable versions
Install the script collection once, then manage it with the script manager:

- **In darktable:** expand the **lua scripts installer** module (lighttable,
  lower-left), run **install scripts**, and restart.
- **Or from a terminal**, clone the repository into darktable's config directory:
  ```sh
  # Linux / macOS
  cd ~/.config/darktable/ && git clone https://github.com/darktable-org/lua-scripts.git lua
  # Windows
  cd %LOCALAPPDATA%\darktable && git clone https://github.com/darktable-org/lua-scripts.git lua
  ```
  Then add this line to your `luarc` file and restart darktable:
  ```
  require "tools/script_manager"
  ```
  The **script manager** then lets you enable or disable individual scripts from a
  simple button list (no manual `luarc` editing). Update later with `git pull` in
  that `lua` folder.

## External software
Some scripts call external programs (for example Hugin, enfuse, ImageMagick, or
ExifTool). Each script's `meta.json` `description-extensive` names what it needs;
install that first.

---

**Official documentation:**
- Using darktable's scripts —
  <https://docs.darktable.org/usermanual/development/en/lua/darktables-scripts/>
- Lua API reference — <https://docs.darktable.org/lua/stable/>
- Script source & readmes — <https://github.com/darktable-org/lua-scripts>
