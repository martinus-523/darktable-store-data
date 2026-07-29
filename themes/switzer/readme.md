# Darktable Theme Pack

This pack contains:

- `user.css`
- `Switzer_Complete.zip`

## What This Is

This theme is built for darktable's `user.css` override layer.

It includes:

- clearer module separation
- unified module header and border color treatment
- stronger subsection styling
- improved spacing and panel structure
- a Switzer-first font stack with sensible fallbacks

## Install

The simplest install method is to copy `user.css` into darktable's config folder and restart darktable.

### macOS

1. Quit darktable.
2. Back up your existing `user.css` if you already use one.
3. Copy this pack's `user.css` to:
   `~/.config/darktable/user.css`
4. Start darktable again.

### Linux

1. Quit darktable.
2. Back up your existing `user.css` if you already use one.
3. Copy this pack's `user.css` to:
   `~/.config/darktable/user.css`
4. Start darktable again.

### Windows

1. Quit darktable.
2. Back up your existing `user.css` if you already use one.
3. Copy this pack's `user.css` to:
   `%LOCALAPPDATA%\darktable\user.css`
4. Start darktable again.

### Optional: CSS Tweaks Editor

If your darktable build exposes the CSS tweaks editor in Preferences > General:

1. Open this pack's `user.css` in a text editor.
2. Copy the contents.
3. Paste them into the CSS tweaks field.
4. Save and apply the CSS.

darktable should write the result back to your local `user.css`.

## Optional Font Install

For the intended typography, install the Switzer fonts from `Switzer_Complete.zip`.

If Switzer is not installed, the theme still works and falls back to:

- `Avenir Next`
- `Avenir`
- `Helvetica Neue`
- `Segoe UI`
- `Roboto`
- other system sans-serif fonts

## Notes

- This pack only changes darktable UI styling.
- If the theme does not appear after restart, confirm that darktable is loading `user.css` overrides.
- If you already maintain a custom `user.css`, merge changes carefully instead of overwriting it blindly.