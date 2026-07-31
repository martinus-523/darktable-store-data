# Installing third-party darktable Lua scripts
This catalog collects **third-party** Lua scripts for [darktable](https://www.darktable.org/)
that are **not** part of darktable's own bundled `lua-scripts`. Each script is in its
own folder; the `files/` sub-folder holds the script and everything it needs — its
`.lua` file, any helper library folder, and (where the author provided them) a
`readme` and a `license`.

---

> **!WARNING: These scripts are unverified. Use them entirely at your own risk.**
>
> - They were gathered from public repositories and forums and are **not tested**
>   by this project — unless indicated otherwise.
> - They may be **broken, incomplete, or incompatible** with your version of
>   darktable, and could behave unexpectedly.
> - Some run **external programs** or send images to **online / AI services**.
>   Read what a script does before enabling it.
> - **Back up** your darktable library (`library.db`) and your image files before
>   trying anything new. A misbehaving script can modify tags, ratings, metadata,
>   or files.
> - Each script keeps its original author's **licence** (see the bundled `license`
>   and `readme` files in the script's folder). Respect it.

---

## Before you start

1. **darktable must have Lua support.** Most official builds do. To confirm, open
   **darktable → preferences**; if there is a **“lua options”** tab, Lua is enabled.
   (Flatpak, the official Windows/macOS installers, and most Linux packages include it.)

2. **Some scripts need darktable's own script library.** Many third-party scripts
   start with a line like `require "lib/dtutils"`. That helper library ships with
   darktable's official `lua-scripts` (bundled since darktable 5.6, or installable
   from within darktable via the **script manager**). If a script uses `dtutils`
   and you get a “module not found” error, install/enable the official lua-scripts
   first.

3. **Some scripts need external software.** Where the author included a `readme` in
   the script's folder, read it first — it names anything extra you must install,
   for example ExifTool, ImageMagick, Hugin/enfuse, a local Ollama AI model, a
   Python environment, or a commercial app. Install those before enabling the script.

## Where scripts go

darktable loads Lua scripts from the `lua/` folder inside its configuration directory:

| OS | darktable config directory |
|----|----------------------------|
| Linux | `~/.config/darktable/` |
| macOS | `~/.config/darktable/` |
| Windows | `%LOCALAPPDATA%\darktable\` (e.g. `C:\Users\<you>\AppData\Local\darktable\`) |

Inside it you will use two things:

- a **`lua/`** sub-folder that holds the script files, and
- a **`luarc`** text file that lists which scripts to load at start-up.

## Install a script

1. **Pick a script folder** (for example `andhet-uncrop/`) and, if it includes a
   `readme` in its `files/`, read it — plus the `license`.

2. **Copy the script files.** Copy everything from that folder's **`files/`** into
   your darktable `lua/` directory, **keeping any sub-folders** (such as `lib/`)
   intact — those are helper modules the script needs. You do **not** need to copy
   the `license` / `readme` files (they are documentation).

   Example (Linux/macOS):
   ```sh
   mkdir -p ~/.config/darktable/lua
   cp andhet-uncrop/files/uncrop.lua ~/.config/darktable/lua/
   ```
   For a multi-file script, copy the `.lua` file(s) **and** any `lib/` (or similar)
   folder next to them, preserving the layout.

3. **Enable it in `luarc`.** Open (or create) `~/.config/darktable/luarc` in a text
   editor and add one line per script — the file name **without** the `.lua`
   extension:
   ```
   require "uncrop"
   ```
   If a script sits in a sub-folder, use a slash, e.g. `require "fxlm/init"`.

4. **Restart darktable.** The script's panel, shortcut, or export option should now
   appear (typically in the lighttable or darkroom side panels, or under
   *preferences → shortcuts*).

> **Tip:** darktable's official **script manager** module gives you a click-to-enable
> list and is the easiest way to manage the bundled library that many of these
> scripts depend on. Third-party scripts placed directly in `lua/` and required from
> `luarc` work alongside it.

## Disable or remove a script

- **Disable:** delete or comment out (`--`) its `require "…"` line in `luarc` and
  restart darktable.
- **Remove:** also delete its `.lua` file (and any helper folder it added) from the
  `lua/` directory.

## Troubleshooting

- **Nothing appears / errors on start-up:** launch darktable from a terminal with
  `darktable -d lua` to see Lua log messages, which usually name the failing script
  and line.
- **“module 'lib/dtutils' not found”:** install/enable darktable's official
  `lua-scripts` (see *Before you start*, step 2).
- **“attempt to call a nil value” / API errors:** the script likely targets an older
  or newer darktable Lua API than yours. Check its `readme` for the darktable version
  it was written for, and make sure your darktable is up to date.
- **An external command fails:** confirm the tool named in the script's `readme` is
  installed and on your `PATH`.

---

*Reminder: everything here is provided as-is, without any guarantee that it works or
is safe for your setup. If in doubt, don't enable it. You are responsible for what
you run.*
