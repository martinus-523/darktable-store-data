# Darktable Store - Data
This repository contains all the presets, styles, themes, lua scripts, etc, for the darktable store.
The darktable store aims to be a centralized store for all users contributions.

## Structure
The content in this repository follows a strict structure. Content is first
categorised by type, and each individual piece is then placed in its own
subfolder, identified by a unique [slug](https://en.wikipedia.org/wiki/Clean_URL#Slug).
Every folder in a collection must also contain a **meta.json** file describing
the content.

A slug is always lowercase and may contain letters, numbers, and hyphens.

While each content category defines its own fields, the following fields
are required for every content item:

| Field         | Required | Description                                                                         |
| ------------- | -------- | ----------------------------------------------------------------------------------- |
| author        | Yes      | The author(s) of the content                                                        |
| name          | Yes      | The name of the content                                                             |
| description   | Yes      | A short explanation of what the content is about                                    |
| license       | Yes      | The license of the content                                                          |
| contributor   | Yes      | An unqiue slug identifying the contributor                                          |
| creation-date | Yes      | ISO date (YYYY-MM-DD) the item was added to the repository, taken from git history  |
| url           | No       | A url to more information about the content                                         |
| notes         | No       | An optional note field.                                                             |
| readme        | No       | Boolean indicating whether the folder contains a readme.md with more information    |
| native        | No       | Indicates if this item is imported from another or native to this repository        |
| source        | No       | A link to the source material for this item                                         |

### Themes
A theme is a CSS file that customises the look of darktable's
user interface, including colours, fonts, and spacing.

| Field       | Required | Description                                                                 |
| ----------- | -------- | --------------------------------------------------------------------------- |
| file        | Yes      | An array with files containg the theme. At least one file required          |
| screenshots | Yes      | An array with screenshots of the theme. At least one screenshot is required |
| dt-versions | Yes      | An array with darktable version in swich this theme is tested. e.q. 5.6.    |
| type        | Yes      | must be a value of: color, dark, grey of light                              |

### Presets
A preset folder contains, next to the **meta.json**, a `presets/` folder with
one subfolder per language (e.g. `presets/en/`, `presets/de/`) holding the
`.dtpreset` files for that language. Optionally, the folder may contain a
`readme.md` with more information and an `images/` folder with images
showcasing the presets.

```
presets/<slug>/
├── meta.json
├── readme.md          (optional)
├── images/            (optional)
│   └── *.png
└── presets/
    ├── en/
    │   └── *.dtpreset
    └── <lang>/        (one folder per language)
        └── *.dtpreset
```

| Field       | Required | Description                                                                          |
| ----------- | -------- | ------------------------------------------------------------------------------------ |
| files       | Yes      | An object mapping each language code to an array of the preset filename(s) in `presets/<lang>/`. Filenames may be localized per language. |
| languages   | Yes      | An array of language codes for which the presets are available, e.q. ["en", "de"]. Must match the keys of `files`. |
| readme      | Yes      | Boolean indicating whether the folder contains a readme.md with more information.    |
| images      | No       | An array of image filenames (in the images/ folder) show casing the presets.         |
| dt-versions | Yes      | An array with darktable version in swich this preset is tested. e.q. 5.6.            |
| modules     | Yes      | An array of the modules of the presets is for, e.q. agx                              |

### Styles
A style is a `.dtstyle` file: a saved set of darktable module settings that can be
applied to an image in one click. A style folder contains, next to the **meta.json**,
a `styles/` folder with one or more `.dtstyle` files and an `images/` folder with
before/after preview WebPs.

The previews are generated with `assets/generate-style-jpgs.py`: every style is applied
to each of the raw files in `assets/raw-files/`, producing one image per style/raw
combination named `<style>_<raw name>.webp`. They are not hand-made; regenerate them
after changing a style. `styles/validate.py` checks the meta.json fields and that the
`images/` folder is complete.

```
styles/<slug>/
├── meta.json
├── images/
│   └── <style>_<raw name>.webp  (one per style/raw combination, generated)
└── styles/
    └── *.dtstyle
```

| Field       | Required | Description                                                                            |
| ----------- | -------- | -------------------------------------------------------------------------------------- |
| files       | Yes      | An array of filenames of the style(s) in the `styles/` folder (can be a collection).   |
| category    | Yes      | An array of categories, each one of: camera-profile, film-emulation, technical, creative. |
| dt-versions | Yes      | An array with darktable versions in which these styles are tested, e.q. 5.6.           |
| source      | Yes*     | A non-empty array of http(s) URLs to the source material. Required unless `native` is true, in which case it must be omitted. |

### Luts
A LUT (look-up table) is a file — typically .cube, .3dl, or hald-CLUT PNG — that transforms
colours to achieve a specific look, applied in darktable via the lut 3D module. A LUT folder
contains, next to the **meta.json**, a `luts/` folder with the LUT files and an `images/`
folder with before/after preview WebPs.

The previews are generated with `assets/generate-lut-jpgs.py`: every LUT is applied (via the
lut 3D module) to each of the raw files in `assets/raw-files/`, producing one image per
LUT/raw combination named `<lut>_<raw name>.webp`. They are not hand-made; regenerate them
after changing a LUT. `luts/validate.py` checks the meta.json
fields and that the `images/` folder is complete.

```
luts/<slug>/
├── meta.json
├── license.txt                    (optional, full license text)
├── images/
│   └── <lut>_<raw name>.webp     (one per LUT/raw combination, generated)
└── luts/
    └── *.cube / *.png / *.3dl
```

| Field             | Required | Description                                                                            |
| ----------------- | -------- | -------------------------------------------------------------------------------------- |
| files             | Yes      | An array of filenames of the lut(s) in the `luts/` folder (can be a collection).       |
| input-colorspace  | Yes      | The colorspace the lut expects as input, e.q. sRGB.                                    |
| output-colorspace | Yes      | The colorspace the lut outputs, e.q. sRGB.                                             |
| dt-versions       | Yes      | An array with darktable versions in which these luts are tested, e.q. 5.6.             |
| source            | Yes*     | A non-empty array of http(s) URLs to the source material. Required unless `native` is true, in which case it must be omitted. |

### Camera profiles
A camera profile is an ICC camera **input** profile (.icc/.icm): it maps a specific
camera's raw colours to a reference colorspace, often giving better colours than
darktable's built-in standard matrix. Users install profiles by copying them to
`~/.config/darktable/color/in/`, after which they appear in darktable's *input color
profile* module. Note that darktable's dropdown shows the profile's *embedded*
description, not the filename — some profiles are embedded as "Unknown Camera" and
become indistinguishable when several are installed at once (see the per-file notes).

Unlike styles and LUTs there is no generated `images/` folder: an input profile is
only meaningful on raw files from the camera it was made for, so the shared raw set
cannot be used to preview it.

```
camera-profiles/<slug>/
├── meta.json
├── license.txt        (optional, full license text)
└── profiles/
    └── *.icc / *.icm
```

| Field       | Required | Description                                                                            |
| ----------- | -------- | -------------------------------------------------------------------------------------- |
| files       | Yes      | An array of filenames of the profile(s) in the `profiles/` folder (can be a collection). |
| cameras     | Yes      | An array of camera names ("Make Model") the profiles are made for, e.q. "Nikon D750".  |
| notes       | No       | An object mapping a filename to a short note (matrix or LUT, origin, caveats, original filename). |
| dt-versions | Yes      | An array with darktable versions in which these profiles are tested, e.q. 5.6.         |
| source      | Yes*     | A non-empty array of http(s) URLs to the source material, in the same order as `files`. Required unless `native` is true, in which case it must be omitted. |

## Assets
The folders assets does **not** contain files for darktables. But it does contain files to generate images
for the luts and styles.

## Licenses
Each of the content items are provided under there respective license as stated in the meta.json (per folder).
Any code in this repository is provided under GPL-3, all other files, include the meta.json files,
the data models and reamde license are CC BY-NC 4.0, copyright martinus and contributors.

This repository have been carefully curated to respect the license of each individual.
If nonetherless, you claim your rights are violated, please reach out via
[https://discuss.pixls.us/t/a-marketplace-for-darktable/59418/47].

The raw images used to generate examples for the styles and LUTs are from https://www.signatureedits.com/free-raw-photos/ see license here: https://www.signatureedits.com/free-raw-license-terms/