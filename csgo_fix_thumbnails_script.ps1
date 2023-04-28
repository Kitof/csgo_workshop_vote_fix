#Requires -RunAsAdministrator
Write-Host ("`n** CS:GO Fix for workshop maps thumbnails during final vote **`n")
# Check collection ID parameters
function Usage {
    Write-Host ("Usage: " + $scriptName + " [MODE] [COLLECTION_ID]`n")
    Write-Host ("Options :")
    Write-Host ("-a, --append `t Append mode (default)")
    Write-Host ("-r, --replace `t Replace mode")
    Write-Host ("-s, --restore `t Restore original gamesmode.txt`n")
}


$scriptName = $MyInvocation.MyCommand.Name
if (($args.Count -lt 1) -or ($args.Count -gt 2)) {
    Usage
    exit
}
$collectionID = ""
$mode = 'append'
if ($args.Count -eq 2) {
    $mode = $args[0]
    $collectionID = $args[1]
    switch($mode.ToLower()) {
        {($_ -eq "-a") -or ($_ -eq "--append")} {
            $mode = 'append'
        }
        {($_ -eq "-r") -or ($_ -eq "--replace")} {
            $mode = 'replace'
        }
        {($_ -eq "-s") -or ($_ -eq "--restore")} {
            $mode = 'restore'
        }
        default {
            Usage
            exit
        }
    }
} else {
    if (($args[0] -eq "-s") -or ($args[0] -eq "--restore")) {
        $mode = 'restore'
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
        if (Test-Path -Path $csgoPath -PathType Container) {
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

$gamemodesFile = "$csgoInstallDir\csgo\gamemodes.txt"
Write-Host "CSGO install detected in $csgoInstallDir"

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

# Restore gamemodes file in restore mode
if($mode -eq 'restore') {
    Copy-Item -Path "$gamemodesFile.org" -Destination $gamemodesFile
    Write-Host ($gamemodesFile + " restored")
    exit
}

Write-Host ("Requested Collection ID : " + $collectionID)
# Collection scraping to get maps ids
$configuration = ""
$response = Invoke-WebRequest $collection_url

# Check if webpage is a CS:GO Collection
if(-not ($response.Content.Contains($csgo_collection_footprint))) {
    Write-Host "ERROR: Collection ID invalid - Not a CS:GO Collection"
    exit
}

$htmlDoc = ConvertFrom-Html -Content $response.Content
$workshopItemsUrls = $htmldoc.SelectNodes("//div[@class='workshopItem']/a")

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
}

# Update gamemodes configuration

# Search right place to add configuration
# Always before 'Classic Maps' comment
$endBlock = (Select-String -Path $gamemodesFile -Pattern '// Classic Maps').LineNumber - 2
$index = $endBlock;
# In append mode, add new maps between '}' (or 'maps' if found first) and '// Classic Maps'
if($mode -eq 'append') {
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
if($mode -eq 'replace') {
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
Write-Host "Done. Enjoy !"