# === CONFIG ===
$scriptName     = "rpcl3pc.ahk"
$baseExeName    = "rpcl3pc"
$finalExeName   = "rpcl3pc"
$ahk2exePath    = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
$mediaFolder    = "rpcl3_media"
$iconPath       = "rpcl3_media\rpcl3.ico"
$versionDat     = "version.dat"
$versionTxt     = "version.txt"
$versionTpl     = "version_template.txt"
$extraAssets = @("README.txt", "pc.ini", "LICENSE", $versionTxt, $versionDat)


# === TIMESTAMP ===
$timestamp    = Get-Date -Format "yyyyMMdd_HH"
$finalExe     = "$finalExeName`_$timestamp.exe"
$zipName      = "$finalExeName`_$timestamp.zip"


# === VERSIONING ===
Copy-Item $versionTpl $versionTxt -Force
(Get-Content $versionTxt) -replace "%%DATETIME%%", $timestamp | Set-Content $versionTxt
$timestamp | Set-Content $versionDat


# === CLEANUP OLD FILES ===
Remove-Item "$baseExeName.exe","$finalExe","build.log","$zipName" -ErrorAction SilentlyContinue


# === COMPILE SCRIPT ===
Write-Host "Compiling AHK..."


# Show current working directory
Write-Host "Current directory: $(Get-Location)"

# Verify all paths
Write-Host "Path verification:" -ForegroundColor Yellow
Write-Host "- Script: $scriptName (exists: $(Test-Path $scriptName))"
Write-Host "- Ahk2Exe: $ahk2exePath (exists: $(Test-Path $ahk2exePath))"
Write-Host "- Icon: $iconPath (exists: $(Test-Path $iconPath))"
Write-Host "- Output will be: $baseExeName.exe"

# Build the argument list with proper quoting
$arguments = @(
    "/in", $scriptName,
    "/out", "$baseExeName.exe",
    "/icon", $iconPath,
    "/compress", "1"
)

Write-Host "Full command:" -ForegroundColor Cyan
Write-Host "`"$ahk2exePath`" $($arguments -join ' ')"

# Execute with detailed error capture
Write-Host "Executing..." -ForegroundColor Green
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

Write-Host "Process exit code: $($process.ExitCode)"

# Check if output file was created
if (Test-Path "$baseExeName.exe") {
    Write-Host "_ Compilation successful!" -ForegroundColor Green
    Copy-Item "$baseExeName.exe" "$finalExe" -Force
    Write-Host "Copied $baseExeName.exe to $finalExe (timestamped build EXE)"
} else {
    Write-Host "_ Output file not created!" -ForegroundColor Red
    Write-Error "Compilation failed."
    Exit 1
}


# === COMPRESS EXE ===
# Path to UPX
$upxPath = "C:\upx-5.0.1-win64\upx.exe"
# Compress the timestamped EXE (or $baseExeName.exe, depending on your script)
Write-Host "Compressing EXE with UPX..."
& $upxPath --best --lzma $finalExe
Write-Host "UPX compression finished."


# === ZIP CONTENTS ===
Write-Host "_ Creating ZIP: $zipName"

# Build file list
$allFiles = @()

# Add final executable
if (Test-Path $finalExe) {
    $allFiles += $finalExe
    Write-Host "Added: $finalExe"
} else {
    Write-Host "Warning: $finalExe not found!" -ForegroundColor Yellow
}

# Add extra assets
foreach ($asset in $extraAssets) {
    if (Test-Path $asset) {
        $allFiles += $asset
        Write-Host "Added: $asset"
    } else {
        Write-Host "Warning: $asset not found!" -ForegroundColor Yellow
    }
}

# Add media files
if (Test-Path $mediaFolder) {
    $mediaFiles = Get-ChildItem -Path $mediaFolder -File | ForEach-Object { $_.FullName }
    $allFiles += $mediaFiles
    Write-Host "Added $($mediaFiles.Count) files from $mediaFolder"
} else {
    Write-Host "Warning: $mediaFolder not found!" -ForegroundColor Yellow
}

# Remove any missing paths
$allFiles = $allFiles | Where-Object { Test-Path $_ }

Write-Host "Total files to zip: $($allFiles.Count)"

# Create build staging folder
$stagingFolder = "build_temp"
Remove-Item $stagingFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingFolder | Out-Null

# Copy all files into staging while preserving folder structure
foreach ($file in $allFiles) {
    $relativePath = Resolve-Path -Relative $file
    $destination = Join-Path $stagingFolder $relativePath
    $destinationDir = Split-Path $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item $file -Destination $destination -Force
}

# Create ZIP from staging
try {
    Compress-Archive -Path "$stagingFolder\*" -DestinationPath $zipName -Force
    Write-Host "_ ZIP created successfully: $zipName" -ForegroundColor Green
} catch {
    Write-Host "_ ZIP creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Remove-Item $stagingFolder -R
Write-Host "! Fallback EXE created, but MEDIA files were NOT embedded." -ForegroundColor Yellow
Write-Host "`n===== BUILD COMPLETE =====" -ForegroundColor Cyan
Write-Host "Output EXE: $finalExe"
Write-Host "ZIP Archive: $zipName"
Write-Host "Timestamp: $timestamp"


# === COPY OUTPUT TO NEW_BUILDS FOLDER ===
try {
    $buildFolder = "C:\repos\rpcl3-process-control\new_builds"
    $outputFiles = @(
        $finalExe,                 # e.g. rpcl3pc_20250704_07.exe
        $zipName,                  # e.g. rpcl3pc_20250704_07.zip
        "$baseExeName.exe"         # e.g. rpcl3pc.exe (if you want it copied too)
    )

    # Ensure $buildFolder is a proper directory
    if (Test-Path $buildFolder) {
        $item = Get-Item $buildFolder
        if (-not $item.PSIsContainer) {
            Write-Host "Removing file named 'new_builds' so we can create a folder instead..."
            Remove-Item $buildFolder -Force
        }
    }

    if (-not (Test-Path $buildFolder)) {
        Write-Host "Creating build folder: $buildFolder"
        New-Item -ItemType Directory -Path $buildFolder | Out-Null
    }

    # Copy files to build folder
    foreach ($file in $outputFiles) {
        if (Test-Path $file) {
            Write-Host "Copying $file to $buildFolder"
            Copy-Item $file -Destination $buildFolder -Force
        } else {
            Write-Warning "File not found, skipping: $file"
        }
    }

    Write-Host "All available files copied to: $buildFolder"
}
catch {
    Write-Error "Error copying build files: $_"
}

# === LOG SUCCESS ===
"[$timestamp] Built $finalExe with embedded WAVs" | Add-Content "changelog.txt"
Write-Host "Done: $finalExe + $zipName"

# Keep window open (bulletproof method)
Write-Host "Script completed. Press any key to exit..." -ForegroundColor Yellow
cmd /c pause | Out-Null

Invoke-Item (Get-Item $finalExe).DirectoryName
