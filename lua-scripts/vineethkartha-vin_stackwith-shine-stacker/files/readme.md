# darktableluascripts
This is a collection of LUA scripts to be used in darktable
## How to use the scripts
### Windows
Follow instructions to enable lua scripts from darktable documentation
https://docs.darktable.org/lua/stable/lua.scripts.manual/installation/
git clone this repo into C:\Users\<USERNAME>\AppData\Local\darktable\lua\
### Linux
git clone this repo into ~/.config/darktable/lua/
## vin_attach_exif_tags.lua
This script, after enabling, can be associated via a shortcut from the  darktable preferences menu. Select images and trigger this script via the newly assigned shortcut. This will add the camera maker, model, lens name and the folder of the image as tags.
This will also add the copyright line to your images.

## vin_generate_tags.lua
This script will use ollama installed locally to generate tags and a title for selected image
Install ollama and gemma3:4b in your local machine and then install the script.
To run the script associate a keyboard shortcut to the script and select an image and trigger the script
This script has been influenced by https://github.com/AyedaOk/DT_custom_script/blob/main/AI_toolbox.lua