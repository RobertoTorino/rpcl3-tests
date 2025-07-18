I have everything in the root of the project folder now, but I get this error in GitHub:
Run $env:ahk2exePath = "$PWD\ahk\Compiler\Ahk2Exe.exe"
The argument 'build/build.ps1' is not recognized as the name of a script file. Check the spelling of the name, or if a path was included, verify that the path is correct and try again.

Usage: pwsh[.exe] [-Login] [[-File] <filePath> [args]]
[-Command { - | <script-block> [-args <arg-array>]
| <string> [<CommandParameters>] } ]
[-CommandWithArgs <string> [<CommandParameters>]
[-ConfigurationName <string>] [-ConfigurationFile <filePath>]
[-CustomPipeName <string>] [-EncodedCommand <Base64EncodedCommand>]
[-ExecutionPolicy <ExecutionPolicy>] [-InputFormat {Text | XML}]
[-Interactive] [-MTA] [-NoExit] [-NoLogo] [-NonInteractive] [-NoProfile]
[-NoProfileLoadTime] [-OutputFormat {Text | XML}]
[-SettingsFile <filePath>] [-SSHServerMode] [-STA]
[-Version] [-WindowStyle <style>]
[-WorkingDirectory <directoryPath>]

pwsh[.exe] -h | -Help | -? | /?

PowerShell Online Help https://aka.ms/powershell-docs

All parameters are case-insensitive.
Error: Process completed with exit code 1.



This is my build script:


# === CONFIG ===
$scriptName     = "rpcl3pc.ahk"
$baseExeName    = "rpcl3pc"
$ahk2exePath    = $env:ahk2exePath
$upxPath        = $env:upxPath
$mediaFolder    = "rpcl3_media"
$iconPath       = "rpcl3_media\rpcl3.ico"
$versionDat     = "version.dat"
$versionTxt     = "version.txt"
$versionTpl     = "version_template.txt"
$extraAssets    = @("README.txt", "pc.ini", "LICENSE", $versionTxt, $versionDat)


# === GET VERSION OR ENVIRONMENT INFO ===
if ($env:GITHUB_REF_NAME) {
    $tag = $env:GITHUB_REF_NAME
    if ($tag -like 'v*') { $ver = $tag.Substring(1) } else { $ver = $tag }
    $finalExe = "${baseExeName}_$tag.exe"
    $zipName  = "${baseExeName}_$tag.zip"
}
else {
    $localTag = "LocalBuild_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $finalExe = "${baseExeName}${localTag}.exe"
    $zipName  = "${baseExeName}${localTag}.zip"
}

$timestamp    = Get-Date -Format "yyyyMMdd_HH"
# ^ Only define $timestamp if you need it for logging, not for naming output files


# === VERSIONING ===
Copy-Item $versionTpl $versionTxt -Force
(Get-Content $versionTxt) -replace "%%DATETIME%%", $timestamp | Set-Content $versionTxt
$timestamp | Set-Content $versionDat


# === CLEANUP OLD FILES ===
Remove-Item "$baseExeName.exe","$finalExe","$zipName" -ErrorAction SilentlyContinue


# === COMPILE SCRIPT ===
Write-Host "Compiling AHK..."

# Show current working directory
Write-Host "_ Current directory: $(Get-Location)"

# Verify all paths
Write-Host "Path verification:" -ForegroundColor Yellow
Write-Host "- Script: $scriptName (exists: $(Test-Path $scriptName))"
Write-Host "- Ahk2Exe: $ahk2exePath (exists: $(Test-Path $ahk2exePath))"
Write-Host "- Icon: $iconPath (exists: $(Test-Path $iconPath))"
Write-Host "- UPX: $upxPath (exists: $(Test-Path $upxPath))"
Write-Host "- Output will be: $baseExeName.exe"

# Build the argument list with proper quoting
$arguments = @(
    "/in", $scriptName,
    "/out", "$baseExeName.exe",
    "/icon", $iconPath
#    "/compress", "1"
)

Write-Host "Full command:" -ForegroundColor Cyan
Write-Host "`"$ahk2exePath`" $($arguments -join ' ')"

# Execute with detailed error capture
Write-Host "_ Executing..." -ForegroundColor Green
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

Write-Host "_ Process exit code: $($process.ExitCode)"

# Check if output file was created
if (Test-Path "$baseExeName.exe") {
    Write-Host "_ Compilation successful!" -ForegroundColor Green
    Copy-Item "$baseExeName.exe" "$finalExe" -Force
    Write-Host "_ Copied $baseExeName.exe to $finalExe (timestamped build EXE)"
} else {
    Write-Host "_ Output file not created!" -ForegroundColor Red
    Write-Error "Compilation failed."
    Exit 1
}


# === COMPRESS EXE ===
Write-Host "_ Pre-UPX size:" (Get-Item $finalExe).Length
$upxResult = & $upxPath --best --lzma $finalExe
$upxResult | ForEach-Object { Write-Host $_ }
Write-Host "_ Post-UPX size:" (Get-Item $finalExe).Length
Write-Host "_ UPX compression finished."

# === ZIP CONTENTS ===
Write-Host "_ Creating ZIP: $zipName"

# Build file list
$allFiles = @()

# Add final executable
if (Test-Path $finalExe) {
    $allFiles += $finalExe
    Write-Host "_ Added: $finalExe"
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

Write-Host "_ Total files to zip: $($allFiles.Count)"

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
Write-Host "_ Fallback EXE created!" -ForegroundColor Yellow
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
            Write-Host "_ Removing file named 'new_builds' so we can create a folder instead..."
            Remove-Item $buildFolder -Force
        }
    }

    if (-not (Test-Path $buildFolder)) {
        Write-Host "_ Creating build folder: $buildFolder"
        New-Item -ItemType Directory -Path $buildFolder | Out-Null
    }

    # Copy files to build folder
    foreach ($file in $outputFiles) {
        if (Test-Path $file) {
            Write-Host "_ Copying $file to $buildFolder"
            Copy-Item $file -Destination $buildFolder -Force
        } else {
            Write-Warning "File not found, skipping: $file"
        }
    }

    Write-Host "_ All available files copied to: $buildFolder"
}
catch {
    Write-Error "Error copying build files: $_"
}


# === LOG SUCCESS ===
"[$timestamp] Built $finalExe with embedded WAVs" | Add-Content "changelog.txt"
Write-Host "_ Done: $finalExe + $zipName"

Write-Host "Script completed!" -ForegroundColor Yellow

# Open folder
Invoke-Item (Get-Item $finalExe).DirectoryName




And this is my release script:



param(
[string]$Message = "Automated commit"
)

git add .
git commit -m "$Message"

# Find the latest tag like v1.2.3, sorted as version
$lastTag = git tag --list "v*" | Sort-Object {[version]($_ -replace '^v','')} -Descending | Select-Object -First 1

if ($lastTag -match '^v(\d+)\.(\d+)\.(\d+)$') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
} else {
    $major = 1; $minor = 0; $patch = 0
    $lastTag = "v0.0.0"
}

Write-Host "Last tag: $lastTag"
$choice = Read-Host "Which part would you like to increment? [major/minor/patch] (default patch)"

switch ($choice.ToLower()) {
    "major" {$major++; $minor=0; $patch=0}
    "minor" {$minor++; $patch=0}
    default {$patch++}
}

$newTag = "v$major.$minor.$patch"
Write-Host "Creating and pushing tag $newTag..."

git tag $newTag
git push
git push origin $newTag

Write-Host "Committed and tagged as $newTag."
