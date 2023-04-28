@echo off

set collection_id="2967702171"

powershell -ExecutionPolicy Bypass -file csgo_fix_thumbnails_script.ps1 %collection_id%

pause
