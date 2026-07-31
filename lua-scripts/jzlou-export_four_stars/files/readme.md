# darktable-scripts
Lua scripts to help with my photography workflow

# Loose instructional notes

## installation
- Use the scripts manager from darktable's lua scripts [repository](https://github.com/darktable-org/lua-scripts)

## debugging and working in lua (in Windows)
- Run darktable in debug mode. The command is: `"C:\Program Files\darktable\bin\darktable" -d lua > log.txt`
- It helps to run the above command while inside the appdata directory (for me that's `C:\Users\username\AppData\Local\darktable`)
- Follow the logfile in Powershell by 'tailing' it in that directory `Get-Content .\log.txt -Wait -Tail 5`
- For some reason normal print statements don't seem to work for me: `dt.print_log("debug statement")`