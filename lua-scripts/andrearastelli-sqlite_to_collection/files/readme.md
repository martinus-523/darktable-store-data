

# My Darktable LUA Scripts

A collection of all the scripts I've made for Darktable and that are helping my Photo editing workflow.

## [HIGHLY EXPERIMENTAL] SQLite TXT/CSV to collection
This is an interesting script that started as an experiment and grew into a more full fledged complex tool.

The idea was to:
1. Tag photos based on a date range (at the minute it's just the YEAR the photo was taken)
2. Export a resized version of the photo into a specific folder, as well as a CSV with the photo destination path and some additional metadata (like creation date/time and little more)
3. Import back a similar TXT or CSV file that can be decoded. All the images in the file can be matched 1:1 with the Darktable image database and tagged to be included in an album.

I already have a Python Flask tool (which I will eventually open source) that I use to load this CSV data and the exported images to compile a SQLite3 db, and the WebUI in my local network can be used to select images that are then grouped into a Darktable tag to be then edited and printed.

The current iteration is kinda strange, and the script name is also not quite the best name ever, hence the "highly experimental" label.

# License
![alt](https://www.gnu.org/graphics/gplv3-with-text-136x68.png)

More info on [LICENSE](LICENSE.md)