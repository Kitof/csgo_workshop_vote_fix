#Requires -RunAsAdministrator
Write-Host ("`n** CS:GO Fix for workshop maps thumbnails during final vote **`n")
# Check collection ID parameters
function Usage {
    Write-Host ("Usage: " + $scriptName + " [MODE] [COLLECTION_ID] [OPTIONS]`n")
    Write-Host ("Modes :")
    Write-Host ("-ca, --client-append `t Client Append mode (default)")
    Write-Host ("-cx, --client-replace `t Client Replace mode")
    Write-Host ("-cr, --client-restore `t Client Restore original gamesmode.txt")
    Write-Host ("-so, --server-output `t Server Output mode")
    Write-Host ("-sa, --server-append `t Server Append mode")
    Write-Host ("-sr, --server-replace `t Server Replace mode")
    Write-Host ("Options :")
    Write-Host ("-wd, --working-directory `t Specified a working directory")
}

$working_dir = "."
$scriptName = $MyInvocation.MyCommand.Name
if (($args.Count -lt 1) -or ($args.Count -gt 4)) {
    Usage
    exit
}
$collectionID = ""
$mode = 'append'
if ($args.Count -eq 4) {
    if(($args[2] -ne "-wd") -and ($args[2] -ne "--working-directory")) { 
        Usage
        exit
    }
    $working_dir = $args[3]
    if(-not (Test-Path "$working_dir")) {
        Write-Host "Error: Working dir " + $working_dir + " not found."
        exit
    }
}
if ($args.Count -gt 1) {
    $mode = $args[0]
    $collectionID = $args[1]
    switch($mode.ToLower()) {
        {($_ -eq "-ca") -or ($_ -eq "--client-append")} {
            $mode = 'client-append'
        }
        {($_ -eq "-cx") -or ($_ -eq "--client-replace")} {
            $mode = 'client-replace'
        }
        {($_ -eq "-cr") -or ($_ -eq "--client-restore")} {
            $mode = 'client-restore'
        }
        {($_ -eq "-so") -or ($_ -eq "--server-output")} {
            $mode = 'server-output'
        }
        {($_ -eq "-sa") -or ($_ -eq "--server-append")} {
            $mode = 'server-append'
        }
        {($_ -eq "-sx") -or ($_ -eq "--server-replace")} {
            $mode = 'server-replace'
        }
        default {
            Usage
            exit
        }
    }
}
if ($args.Count -eq 1) {
    if (($args[0] -eq "-cr") -or ($args[0] -eq "--client-restore")) {
        $mode = 'client-restore'
        $collectionID = 0
    } else {
        $collectionID = $args[0]
    }
    
}

if (-not($collectionID -match "^[\d\.]+$")) {
    Write-Host "Error: Collection ID should be only numeric"
    exit
}

# Checking and install prerequisites
Write-Host "Checking and install prerequisites"
Install-PackageProvider -Name NuGet -Confirm:$false -Force | Out-Null
if (-not (Get-InstalledModule -Name PowerHTML -ErrorAction SilentlyContinue)) {
    Install-Module -Name PowerHTML -Confirm:$false -Force | Out-Null
}
Add-Type -AssemblyName System.Drawing
Import-Module PowerHTML

# URL of the Steam workshop collection to download the map icons from
$collection_url = "https://steamcommunity.com/sharedfiles/filedetails/?id=" + $collectionID

# URL of the Steam API endpoint to get the details of a published file
$api_url = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/"

# Specific part of HTML only existing in collection of CS:GO
$csgo_collection_footprint = '<span class="breadcrumb_separator">&gt;&nbsp;</span><a data-panel="{&quot;noFocusRing&quot;:true}" href="https://steamcommunity.com/workshop/browse/?section=collections&appid=730">'

# Trying to find the installation path of CS:GO from the registry key
if(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 730") {
	$steamApp730 = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 730"
	$csgoInstallDir = $steamApp730.InstallLocation
} else {
# If failed, try to find the installation path of CS:GO from the Steam libraryfolders file
    $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam").SteamPath
    $pathsFile = Join-Path $steamPath "steamapps\libraryfolders.vdf"
    if (!(Test-Path -Path $pathsFile -PathType Leaf)) {
		Write-Host "Error: Unable to find CS:GO install directory"
		exit
    }

    $libraries = [System.Collections.Generic.List[string]]::new()
    $libraries.Add($steamPath)
    $pathVDF = Get-Content -Path $pathsFile
    $pathRegex = [Regex]::new('"(([^"]*):\\([^"]*))"')
    foreach ($line in $pathVDF) {
        if ($pathRegex.IsMatch($line)) {
            $match = $pathRegex.Matches($line)[0].Groups[1].Value
            $libraries.Add($match.Replace('\\', '\'))
        }
    }

	$found = $false
    foreach ($library in $libraries) {
        $csgoPath = Join-Path $library "steamapps\common\Counter-Strike Global Offensive"
        if (Test-Path -Path "$csgoPath\csgo" -PathType Container) {
            $csgoInstallDir = $csgoPath
			$found = $true
			break
        }
    }
	
	if(-not $found) {
		Write-Host "Error: Unable to find CS:GO install directory"
		exit
    }
}
Write-Host "CSGO install detected in $csgoInstallDir"

$gamemodesFile = "$csgoInstallDir\csgo\gamemodes.txt"

# Restore gamemodes file in restore mode
if($mode -eq 'client-restore') {
    Copy-Item -Path "$gamemodesFile.org" -Destination $gamemodesFile
    Write-Host ($gamemodesFile + " restored")
    exit
}

# Collection scraping to get maps ids
Write-Host ("Requested Collection ID : " + $collectionID)
$response = Invoke-WebRequest $collection_url

# Check if webpage is a CS:GO Collection
if(-not ($response.Content.Contains($csgo_collection_footprint))) {
    Write-Host "ERROR: Collection ID invalid - Not a CS:GO Collection"
    exit
}

if($mode -like 'client-*') {
    # Check and create tree structure for the workshop thumbnail
    $csgoMapIconsDir = "$csgoInstallDir\csgo\materials\panorama\images\map_icons"
    if(-not (Test-Path "$csgoMapIconsDir\screenshots")) {
        New-Item -ItemType Directory -Path "$csgoMapIconsDir\screenshots" | Out-Null
    }
    if(-not (Test-Path "$csgoMapIconsDir\screenshots\360p")) {
        New-Item -ItemType Directory -Path "$csgoMapIconsDir\screenshots\360p" | Out-Null
    }
    if(-not (Test-Path "$csgoMapIconsDir\screenshots\360p\workshop")) {
        New-Item -ItemType Directory -Path "$csgoMapIconsDir\screenshots\360p\workshop" | Out-Null
    }
}

$htmlDoc = ConvertFrom-Html -Content $response.Content
$workshopItemsUrls = $htmldoc.SelectNodes("//div[@class='workshopItem']/a")
$configuration = ""

ForEach ($url in $workshopItemsUrls){
    # Getting the details of the published file using the Steam API
    $id = $url.Attributes['href'].Value.Split('=')[1]
    $params = "itemcount=1&publishedfileids[0]=$id"
    $response = Invoke-WebRequest -Uri $api_url -Method POST -Body $params
    $fullname = ($response.Content | ConvertFrom-Json).response.publishedfiledetails[0].filename
    $thumbnail = ($response.Content | ConvertFrom-Json).response.publishedfiledetails[0].preview_url

    # Extracting the mapname from the filename without the path and extension
    if ($fullname) {
        $filename = $fullname -replace '\\', ''
        $mapName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    }

    if($mode -like 'client-*') {
    # CLIENT MODES
        # Building the configuration
        $configuration += "`n`t`t`"workshop/" + $id + "/" + $mapName + "`" {}`n"
        Write-Host "Download & convert map thumbnail of workshop/$id/$mapName"
        # Downloading and resizing the map thumbnail
        if ($thumbnail -and (-not (Test-Path "$csgoMapIconsDir\screenshots\360p\workshop\$id\$mapName.png"))) {
            
            # Download
            $response = Invoke-WebRequest -Uri $thumbnail -UseBasicParsing
            $imageBytes = $response.Content
            $imageStream = [IO.MemoryStream]::new($imageBytes)
            $image = [System.Drawing.Image]::FromStream($imageStream)

            # Resize
            $resized_image = $image.GetThumbnailImage(640, 360, $null, [System.IntPtr]::Zero)
            $ms = New-Object System.IO.MemoryStream
            $resized_image.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)

            # Save
            if(-not (Test-Path "$csgoMapIconsDir\screenshots\360p\workshop\$id")) {
                New-Item -ItemType Directory -Path "$csgoMapIconsDir\screenshots\360p\workshop\$id" | Out-Null
            }
            $ms.ToArray() | Set-Content -Path "$csgoMapIconsDir\screenshots\360p\workshop\$id\$mapName.png" -Encoding Byte | Out-Null
        }
        
    } else {
    # SERVER MODES
        # Building the configuration
        $configuration += "`n`t`t`"workshop/" + $id + "/" + $mapName + "`" `"`"`n"
    }
}

# Update gamemodes configuration

if($mode -like 'client-*') {
# CLIENT MODES
    # Search right place to add client configuration
    # Check if gamemodesFile is valid'
    if(-not (Select-String -Path $gamemodesFile -Pattern '// Classic Maps' -Quiet)) {
        Write-Host ("ERROR: Unable to find '// Classic Maps' pattern in client configuration.")
        exit
    }
    # Always before 'Classic Maps' comment
    $endBlock = (Select-String -Path $gamemodesFile -Pattern '// Classic Maps').LineNumber - 2
    $index = $endBlock;
    # In append mode, add new maps between '}' (or 'maps' if found first) and '// Classic Maps'
    if($mode -eq 'client-append') {
        while($index -ge 1) {
            $line = (Get-Content -Path $gamemodesFile -TotalCount $index)[-1]
            if(($line -match '}') -or ($line -match '\s*maps\s*'))  {
                $index++
                break
            }
            $index--
        }
    }
    # In replace mode, replace everything between 'maps {' and '// Classic Maps'
    if($mode -eq 'client-replace') {
        while($index -ge 1) {
            $line = (Get-Content -Path $gamemodesFile -TotalCount $index)[-1]
            if($line -match '\s*maps\s*') {
                while(-not ($line -match '{')) {
                    $index++
                    $line = (Get-Content -Path $gamemodesFile -TotalCount $index)[-1]
                }
                break
            }
            $index--
        }
    }
    $startBlock = $index

    # Backup the file
    $date = Get-Date -Format "yyyyMMdd"
    Copy-Item -Path $gamemodesFile -Destination "$gamemodesFile.$date"

    # Original backup of the file (for restore)
    if(-not (Test-Path "$gamemodesFile.org")) {
        Copy-Item -Path $gamemodesFile -Destination "$gamemodesFile.org"
    }

    Write-Host "Backup and modify gamemodes.txt"
    # Write new configuration
    $new_content = Get-Content -Path $gamemodesFile -TotalCount $startBlock
    $new_content += $configuration
    $new_content += Get-Content -Path $gamemodesFile | Select-Object -Skip $endBlock
    Set-Content -Path $gamemodesFile -Value $new_content
} else {
# SERVER MODES
    # Search right place to add server configuration
    $destFile = $working_dir + "\gamemodes_server.txt"
    if($mode -eq 'server-append') {
        $srcFile = $working_dir + "\gamemodes_server.txt"
    } else {
        $srcFile = $working_dir + "\gamemodes_server.txt.template"
    }
    # Check if srcFile already exist'
    if(-not (Test-Path $srcFile)) {
        Write-Host ("ERROR: Unable to find source server configuration : "+ $srcFile +" not found.")
        exit
    }
    # Check if srcFile is valid'
    if(-not (Select-String -Path $srcFile -Pattern '// ADD MAPS HERE' -Quiet)) {
        Write-Host ("ERROR: Unable to find '// ADD MAPS HERE' pattern in server configuration.")
        exit
    }
    # Always before '// ADD MAPS HERE' comment
    $endBlock = (Select-String -Path $srcFile -Pattern '// ADD MAPS HERE').LineNumber - 1
    $index = $endBlock;
    if($mode -eq 'server-append') {
        # In append mode, add new maps between '"' (or 'maps' if found first) and '// ADD MAPS HERE'
        while($index -ge 1) {
            $line = (Get-Content -Path $srcFile -TotalCount $index)[-1]
            if(($line -match '"') -or ($line -match '\s*maps\s*'))  {
                $index++
                break
            }
            $index--
        }
    }
    if($mode -eq 'server-replace') {
        # In replace mode, replace everything between 'maps {' and '// ADD MAPS HERE'
        while($index -ge 1) {
            $line = (Get-Content -Path $srcFile -TotalCount $index)[-1]
            if($line -match '\s*maps\s*') {
                while(-not ($line -match '{')) {
                    $index++
                    $line = (Get-Content -Path $srcFile -TotalCount $index)[-1]
                }
                break
            }
            $index--
        }
    }
    $startBlock = $index

    # Write new configuration
    $new_content = Get-Content -Path $srcFile -TotalCount $startBlock
    $new_content += $configuration
    $new_content += Get-Content -Path $srcFile | Select-Object -Skip $endBlock
    if($mode -eq 'server-output') {
        Write-Host $new_content
    } else {
        Set-Content -Path $destFile -Value $new_content
        Write-Host "gamemodes_server.txt generated.`n"
    }
    Write-Host "YOU NEED TO :"
    Write-Host "- Adapt and copy gamemodes_server.txt for your server"
    Write-Host "- Add 'mapgroup my_custom_group' to 'csgo/cfg/server.txt'"
    Write-Host "- Launch your server with additionnal parameters +host_workshop_collection <collection ID> +workshop_start_map <first map ID>`n"
}

Write-Host "Enjoy !"