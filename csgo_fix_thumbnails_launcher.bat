@echo off

set collection_id="2967702171"

set "cur_path=%cd%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs powershell -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File \"%cur_path%\csgo_fix_thumbnails_script.ps1\" -ca %collection_id% -wd \"%cur_path%\"'"