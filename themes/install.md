# How to install

In darktable, a theme is a CSS file that defines the appearance of the user
interface — colours, fonts, spacing, borders, and other visual styling.
Since darktable's interface is built with GTK, themes are written as
GTK-compatible CSS and can be selected under preferences > general > theme.

Custom themes are placed in the user's configuration
directory and typically build on one of
the built-in themes, such as darktable-elegant-dark, by overriding specific style rules.

In this repository the themes are created in such a way that you only have to copy the css file to the correct folder.

- **Linux / MacOS** ~/.config/darktable/themes/
- **Linux Flatpak** ~/.var/app/org.darktable.Darktable/config/darktable/themes/
- **Windows** C:\Users\USER-NAME\AppData\Local\darktable\themes\

In darktable they then will show in the theme settings of the general settings pages.

Please note that some themes ship as a zip file containing multiple files.
Extract the zip and place its entire contents in the themes directory.

If a theme contains custom fonts and you want to use them,
please install the fonts using your operating system's default method of installing fonts.
