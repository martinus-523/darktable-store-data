# FXLM (Film eXperience Look Manager) - Darktable Lua Plugin

A Lua-based plugin for Darktable that allows users to create, manage, and share film-inspired looks. FXLM provides a progressive skill tier system from one-click presets to expert-level film simulation control.

## Features

- **Tier 1: One-Click Looks** - Simple preset selection with intensity control
- **Tier 2: Recipe Import** - Convert Fujifilm and Mood Camera recipes to Darktable
- **Tier 3: Expert Workspace** - Full control over film simulation parameters
- **FXLM Preset Format** - Shareable `.fxlm` preset files
- **Film Simulation Elements** - Based on real film characteristics

## Project Structure

```
darktable-lua-fxlm/
├── lua/
│   └── fxlm/
│       ├── init.lua          # Main plugin entry point
│       ├── ui.lua            # UI components (Tier 1, 2, 3)
│       ├── core.lua          # Film simulation logic
│       ├── recipes.lua       # Recipe conversion system
│       ├── presets.lua       # Preset management
│       └── presets/          # Sample preset files
│           ├── soft_portrait.fxlm
│           └── vintage_warm.fxlm
├── test_fxlm.lua            # Test script
├── README.md                # This file
└── documentation/
    ├── information.txt      # Project vision and decisions
    ├── pipeline.txt         # Build pipeline
    ├── coreelement.txt      # Film simulation technical reference
    ├── recipe-conversion.txt # Recipe conversion guide
    └── ui-mockup.txt        # UI design mockups
```

## Installation

### Prerequisites

1. **Darktable** (version 3.0 or later)
2. **Lua support** (usually built into Darktable)
3. **Basic understanding** of Darktable's module system

### Installation Steps

#### Option A: Manual Installation

1. **Copy the plugin files** to Darktable's Lua directory:

   ```bash
   # Linux/macOS
   mkdir -p ~/.config/darktable/lua/fxlm
   cp -r lua/fxlm/* ~/.config/darktable/lua/fxlm/

   # Windows
   mkdir -p %APPDATA%\darktable\lua\fxlm
   xcopy lua\fxlm %APPDATA%\darktable\lua\fxlm\ /E /I
   ```

2. **Enable the plugin** in Darktable:
   - Open Darktable
   - Go to `Preferences > Lua`
   - Enable the FXLM plugin
   - Restart Darktable

#### Option B: Development Installation

1. **Clone or download** the repository
2. **Create a symbolic link** to the Lua directory:
   ```bash
   ln -s /path/to/darktable-lua-fxlm/lua/fxlm ~/.config/darktable/lua/fxlm
   ```
3. **Enable the plugin** in Darktable preferences

## Usage

### Tier 1: One-Click Looks

1. Open Darktable and select an image
2. Open the FXLM panel (usually in the left sidebar)
3. Select a preset from the dropdown
4. Adjust the intensity slider
5. Click "Save Look" to save as `.fxlm` file

### Tier 2: Recipe Import

1. Click "Import Recipe" in the FXLM panel
2. Paste a Fujifilm or Mood Camera recipe
3. The plugin will convert it to FXLM format
4. Save as a new `.fxlm` preset

### Tier 3: Expert Workspace

1. Click "Expert" to access full controls
2. Adjust individual module parameters
3. Fine-tune film simulation characteristics
4. Save custom presets

## Development

### Testing

Run the test script to verify the plugin structure:

```bash
cd /path/to/darktable-lua-fxlm
lua test_fxlm.lua
```

### Adding New Presets

1. Create a new `.fxlm` file in the `presets/` directory
2. Follow the format in `soft_portrait.fxlm`
3. Add the preset to the UI dropdown in `ui.lua`

### Extending Recipe Support

1. Add new mappings in `recipes.lua`
2. Update the `convert_recipe` function
3. Test with sample recipes

## Technical Details

### Film Simulation Elements

FXLM simulates film characteristics using Darktable's existing modules:

1. **Base Tone Mapping**
   - Filmic RGB (contrast, highlight roll-off)
   - Exposure adjustment
   - Tone equalizer

2. **Color Science**
   - Color Balance RGB (saturation, warmth, tint)
   - RGB curves
   - Channel mixer

3. **Film Character**
   - Grain simulation
   - Vignette effects
   - Local contrast

4. **Finishing**
   - Contrast equalizer
   - Micro-contrast

### FXLM Preset Format

FXLM presets are Lua files with this structure:

```lua
return {
    name = "Preset Name",
    description = "Description",
    version = "1.0",
    author = "Author Name",
    intensity = 100,
    parameters = {
        filmic_rgb = {
            contrast = 1.0,
            saturation = 1.0,
            highlight_compression = 0.5,
            shadow_compression = 0.5
        },
        color_balance_rgb = {
            saturation = 1.0,
            warmth = 0.0,
            tint = 0.0
        },
        grain = {
            amount = 0.1,
            size = 0.5,
            roughness = 0.5
        }
    }
}
```

## Recipe Conversion

### Fujifilm Recipe Support

FXLM can convert common Fujifilm recipes:

- Film Simulation (PROVIA, Velvia, Classic Chrome, etc.)
- Dynamic Range (DR100, DR200, DR400)
- Highlight/Shadow adjustments
- Color settings
- Grain settings
- White Balance and WB Shift

### Mood Camera Recipe Support

FXLM supports Mood Camera recipes:

- Intensity
- Fade
- Contrast
- Warmth/Tint
- Grain
- Glow/Halation

## Limitations

- **Lua Limitations**: FXLM cannot modify Darktable's core image processing pipeline
- **Module Availability**: Some Darktable modules may not be available in all versions
- **Performance**: Complex presets may impact performance with large images
- **Compatibility**: Tested with Darktable 3.0+, may work with earlier versions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is released under the MIT License. See `LICENSE` for details.

## Acknowledgments

- Darktable team for the excellent open-source RAW processor
- Fujifilm and Mood Camera communities for recipe inspiration
- Film simulation researchers for technical insights

## Support

For issues, questions, or contributions:

- Check the documentation files in the `documentation/` directory
- Review the test script for usage examples
- Open an issue on the project repository

---

**Note**: This is a development version. Some features may not be fully implemented or may require additional Darktable API integration.
