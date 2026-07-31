nind-denoise
==============
*Forked from https://github.com/CommReteris/nind-denoise.*

---

A pytorch based image denoising tool for the removal of noise from real photographs. Implements the models developed in    
Benoit Brummer's [NIND Denoise](https://github.com/trougnouf/nind-denoise.git), and the [Darktable](https://github.com/darktable-org/darktable) workflow pioneered by [Huy Hoang](https://github.com/hqhoang) with some modifications to the Lua Plugin by [Rengo](https://github.com/CommReteris/nind-denoise).

This fork implements their work as an opinionated darktable plugin and aims at providing a smooth workflow integrating the denoising step.
The focus lies on nind-deblur without the RL deblurring step.
However the basics of this feature present in the previous methods still exists. Features include:
- Lua plugin for darktable which provides an export target
- Automatic import and grouping of denoised image into darktable
- Support different hardware setups (CUDA, ROCm, Intel Xe)
- Automatic model download

# Quick Start (Recommended)

The easiest way to use nind-denoise is through the Darktable Lua plugin.

## 1. Install Lua Scripts and Download This Script

First, install the community lua-scripts collection through Darktable's built-in interface (this will create the necessary folder structure). See the [official lua-scripts repository](https://github.com/darktable-org/lua-scripts) for installation instructions.

Once installed, download `nind_denoise_rl.lua` from this repository and place it in the contrib folder:

**Linux:**
```bash
curl -o ~/.config/darktable/lua/contrib/nind_denoise_rl.lua \
  https://gitlab.com/tobisoftware/nind-denoise-darktable/-/raw/main/src/lua-scripts/nind_denoise_rl.lua
```

**macOS:**
```bash
curl -o ~/Library/Application\ Support/darktable/lua/contrib/nind_denoise_rl.lua \
https://gitlab.com/tobisoftware/nind-denoise-darktable/-/raw/main/src/lua-scripts/nind_denoise_rl.lua
```

**Windows:**
```powershell
Invoke-WebRequest -Uri "https://gitlab.com/tobisoftware/nind-denoise-darktable/-/raw/main/src/lua-scripts/nind_denoise_rl.lua" `
  -OutFile "$env:LOCALAPPDATA\darktable\lua\contrib\nind_denoise_rl.lua"
```

Or manually download the file and copy it to the contrib folder:
- Linux: `~/.config/darktable/lua/contrib/`
- macOS: `~/Library/Application Support/darktable/lua/contrib/`
- Windows: `%LOCALAPPDATA%\darktable\lua\contrib\`

## 2. Set Up this repository

1. Download this repository `https://gitlab.com/tobisoftware/nind-denoise-darktable.git`
2. Create a python venv `python -m venv .venv`
3. Activate the venv `. .venv/bin/activate`
4. Install torch according to the instructions at [pytorch.org](https://pytorch.org/get-started/locally/)
5. Install any other dependencies `pip install -r requirements.txt`
6. Start Darktable and enable the script from the Script Manager (`lighttable > script manager`)
7. Select the directory where the repository was setup in the options of darktable. `Settings > Lua options > NindRL: nind_denoise directory`.

Now there should be another target in the export module called `Nind + RL`.

**Note:** The Environment should be displayed as Ready inside the export UI. Otherwise check your venv setup.

**Note:** The first time an image is exported the default model is downloaded which might take a while.

### 3. Verify GPU Acceleration (Optional)

```console
(nind-denoise) $ python
>>> import torch
>>> torch.accelerator.is_available()
True
>>> torch.cuda.is_available()  # For nVidia GPUs
True
>>> torch.xpu.is_available()   # For Intel GPUs
False
```

## 4 Start Denoising

1. Select one or more images in the lighttable
2. Go to the export module
3. Choose **"NIND-denoise RL"** as the target storage
4. Configure export settings:
   - Select JPEG or TIFF output format
   - Adjust RL deblur parameters (sigma, iterations)
   - Or select **"Only denoise + import & stack image"** to skip further processing and import the denoised image back into darktable
5. Click export

Processed images will be automatically grouped with their originals in your Darktable library!

# Project Goals

This repository aims at integrating the denoising process presented by [Huy Hoang](https://github.com/hqhoang/nind-denoise/tree/darktable-cli) on [pixls.us](https://discuss.pixls.us/t/feedback-needed-integrating-nind-denoise-with-darktable/51393) into darktable with the help of a lua plugin.
[Rengo](https://discuss.pixls.us/t/nind-denoise-plugin-for-darktable/53387) already did some work to implement such a [Lua Plugin](https://github.com/CommReteris/nind-denoise), which this project aims to improve in an opinionated manner.

The original process by Huy Hoang consistent of the following steps:
1. Fully process the image in darktable without any sharpening and denoising
2. Call a python script outside of darktable to export a finished image

If one wants to apply further modifications to the image after the denoising step, this is not immediately possible and the image has to be imported into darktable again.
As a result, previous modifications are "baked" into the image and cannot be changed anymore.
Under the hood, the image is first processed with only the RAW-related operations, then the denoising is applied.
Afterwards, all remaining operations are applied, exported into an image and optionally the RL step is executed.

For my use case, I don't need the RL step, as I usually use the sharpening tools inside darktable.
Additionally, I would like to take over editing of the second image again.
Thus, I introduced the "Only denoise + import & stack image" options which does exactly that.
Instead of continuing after the denoising step, the denoised image together with the xmp sidecar file for the second stage is written to disk and imported back into darktable.
Then, I can continue editing the denoised image and when I'm finished, I can manually export the final image.
However, the previous method still works as intended with some caveats towards the output format as explained below. 

Additionally, I had a lot of problems with the one-click setup presented by Rengo.
Thus, I chose to remove this functionality and stay with a manual setup of the venv.
This way the correct version of pytorch can/must be chosen by the user which allows for more flexibility and easier debugging.

### Peculiarities of this script

The output format option is not always respected as one would expect
- "Only denoise + import & stack image" is selected
  - JPG works, except for the quality slider, which is ignored
  - TIFF works as expected with the corresponding bit depths and extensions
- RL deblur + "Only denoise + import & stack image" is **not** selected
  - JPG works as expected, including the quality slider
  - TIFF always exports as a 8-bit image
- **no** RL deblur + "Only denoise + import & stack image" is **not** selected
  - JPG works, except for the quality slider, which is ignored
  - TIFF always exports as a 16-bit image with the extension ".tif"

Even when "Only denoise + import & stack image" is not selected, the denoised image is not deleted.
It will stay on disk as `<output_dir>/<output_img_without_ext>_denoised.tiff` and will be overwritten by any future exports.

---

# Advanced Usage

## Command-Line Interface

For advanced users, custom workflows, or batch processing, you can use the command-line interface directly.

### Basic Usage

To denoise an image, run:

```console
$ python3 src/denoise.py "/path/to/photo0123.RAW"
```

**Note:** On Windows, if you use forward slashes _do not_ use single forward slashes for paths. Double backslashes are OK:

```powershell 
PS> python3 src\\denoise.py "\\good\\path\\to\\photo0123.RAW"
```

### Full Command-Line Options

```python
"""
Usage:
    denoise.py [ -o <outpath> | --output-path=<outpath> ] [-e <e> | --extension=<e> ]
                [ --only-denoise ] [ --keep-denoised ]
                [ -d <darktable> | --dt=<darktable> ] [-g <gmic> | --gmic=<gmic> ] [ -q <q> | --quality=<q> ]
                [ --nightmode ] [ --no_deblur ] [ --debug ] [ --sigma=<sigma> ] [ --iterations=<iter> ]
                [ -v | --verbose ] [ --tiff-input ] [ --sidecar=<sidecar> ] <raw_image>
    denoise.py (help | -h | --help)
    denoise.py --version

Options:

  -o <outpath> --output-path=<outpath>  Where to save the result (defaults to current directory).
  -e <e> --extension=<e>                Output file extension. Supported formats are ....? [default: jpg].
  --only-denoise                        Only denoise the image (though still process the xmp sidecar file).
  --keep-denoised                       Keep the denoised image and it's xmp sidecar file.
  --dt=<darktable>                      Path to darktable-cli. Use this only if not automatically found.
  -g <gmic> --gmic=<gmic>               Path to gmic. Use this only if not automatically found.
  -q <q> --quality=<q>                  JPEG compression quality. Lower produces a smaller file at the cost of more artifacts. [default: 90].
  --nightmode                           Use for very dark images. Normalizes brightness (exposure, tonequal) before denoise [default: False].
  --no_deblur                           Do not perform RL-deblur [default: false].
  --debug                               Keep intermedia files.
  --tiff-input                          Use when input is already a TIFF from stage 1; This is for use by the lua plugin
  --sidecar=<sidecar>                   Path to the .xmp sidecar. Normally autodiscovered; This is for use by the lua plugin
  --sigma=<sigma>                       sigma to use for RL-deblur. Acceptable values are ....? [default: 1].
  --iterations=<iter>                   Number of iterations to perform during RL-deblur. Suggest keeping this to ...? [default: 10].

  -v --verbose
  --version                             Show version.
  -h --help                             Show this screen.

"""
```

---

---

# Citation

Please cite Benoit Brummer's original work:

```bibtex
@InProceedings{Brummer_2019_CVPR_Workshops,
author = {Brummer, Benoit and De Vleeschouwer, Christophe},
title = {Natural Image Noise Dataset},
booktitle = {Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR) Workshops},
month = {June},
year = {2019}
}
```
