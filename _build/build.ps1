# === CONFIG ===
$scriptName   = "rpcl3pc.ahk"
$baseExeName  = "rpcl3pc"
$ahk2exePath  = $env:ahk2exePath
$upxPath      = $env:upxPath
if (-not $ahk2exePath) { $ahk2exePath = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" }
if (-not $upxPath) { $upxPath = "C:\tools\upx.exe" }

$mediaFolder  = "rpcl3_media"
$iconPath     = "rpcl3_media\rpcl3.ico"
$versionDat   = "version.dat"
$versionTxt   = "version.txt"
$versionTpl   = "version_template.txt"
$extraAssets  = @("README.txt", "pc.ini", "LICENSE", $versionTxt, $versionDat)

# === GET VERSION OR ENVIRONMENT INFO ===
if ($env:GITHUB_REF_NAME) {
    $tag = $env:GITHUB_REF_NAME
    if ($tag -like 'v*') { $ver = $tag.Substring(1) } else { $ver = $tag }
    $finalExe = "${baseExeName}_$tag.exe"
    $zipName  = "${baseExeName}_$tag.zip"
} else {
    $localTag = "LocalBuild_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $finalExe = "${baseExeName}${localTag}.exe"
    $zipName  = "${baseExeName}${localTag}.zip"
}

$timestamp = Get-Date -Format "yyyyMMdd_HH"

# === VERSIONING ===
if (!(Test-Path $versionTpl)) {
    Write-Error "Template $versionTpl not found."
    Exit 1
}
Copy-Item $versionTpl $versionTxt -Force
(Get-Content $versionTxt) -replace "%%DATETIME%%", $timestamp | Set-Content $versionTxt
$timestamp | Set-Content $versionDat

# === CLEANUP OLD FILES ===
Remove-Item "$baseExeName.exe","$finalExe","$zipName" -ErrorAction SilentlyContinue

# === PATH DIAGNOSTICS ===
Write-Host "_ Current directory: $(Get-Location)"
Write-Host "- Script: $scriptName (exists: $(Test-Path $scriptName))"
Write-Host "- Ahk2Exe: $ahk2exePath (exists: $(Test-Path $ahk2exePath))"
Write-Host "- Icon: $iconPath (exists: $(Test-Path $iconPath))"
Write-Host "- UPX: $upxPath (exists: $(Test-Path $upxPath))"
Write-Host "- Output will be: $baseExeName.exe"

# === VERIFY ALL FILES EXIST ===
$allRequired = @($scriptName, $iconPath)
foreach ($p in $allRequired) {
    if (!(Test-Path $p)) { Write-Error "Required: $p NOT FOUND!"; Exit 1 }
}
foreach ($p in $extraAssets) {
    if (!(Test-Path $p)) { Write-Warning "Extra asset missing: $p" }
}

# === COMPILE SCRIPT ===
$arguments = @(
    "/in", $scriptName,
    "/out", "$baseExeName.exe",
    "/icon", $iconPath
)
Write-Host ""
Write-Host "Full command:" -ForegroundColor Cyan
Write-Host "`"$ahk2exePath`" $($arguments -join ' ')"
Write-Host "_ Executing Ahk2Exe..." -ForegroundColor Green

# Redirect Ahk2Exe output for debugging
$stdout = "ahk2exe.out.txt"
$stderr = "ahk2exe.err.txt"
if (Test-Path $stdout) { Remove-Item $stdout }
if (Test-Path $stderr) { Remove-Item $stderr }

# Start process with timeout
$proc = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr `
    -NoNewWindow -PassThru

$timeout_ms = 120000  # 2 minute timeout
if (-not $proc.WaitForExit($timeout_ms)) {
    $proc.Kill()
    Write-Error "Ahk2Exe timed out after $($timeout_ms/1000)s and was killed."
    Get-Content $stdout
    Get-Content $stderr
    Exit 1
}

Write-Host "_ Ahk2Exe output:"
if (Test-Path $stdout) { Get-Content $stdout }
if (Test-Path $stderr) { Get-Content $stderr }

# Check if output file was created
if (Test-Path "$baseExeName.exe") {
    Write-Host "_ Compilation successful!" -ForegroundColor Green
    Copy-Item "$baseExeName.exe" "$finalExe" -Force
    Write-Host "_ Copied $baseExeName.exe to $finalExe"
} else {
    Write-Host "_ Output file not created!" -ForegroundColor Red
    Write-Error "Compilation failed."
    Exit 1
}

# === COMPRESS EXE ===
if ($upxPath -and (Test-Path $upxPath)) {
    Write-Host "_ Pre-UPX size:" (Get-Item $finalExe).Length
    $upxResult = & $upxPath --best --lzma $finalExe
    $upxResult | ForEach-Object { Write-Host $_ }
    Write-Host "_ Post-UPX size:" (Get-Item $finalExe).Length
    Write-Host "_ UPX compression finished."
} else {
    Write-Host "_ Skipping UPX compression."
}

# === ZIP CONTENTS ===
Write-Host "_ Creating ZIP: $zipName"
$allFiles = @()
if (Test-Path $finalExe) { $allFiles += $finalExe; Write-Host "_ Added: $finalExe" }

foreach ($asset in $extraAssets) {
    if (Test-Path $asset) { $allFiles += $asset; Write-Host "Added: $asset" }
    else { Write-Host "Warning: $asset not found!" -ForegroundColor Yellow }
}
if (Test-Path $mediaFolder) {
    $mediaFiles = Get-ChildItem -Path $mediaFolder -File | ForEach-Object { $_.FullName }
    $allFiles += $mediaFiles
    Write-Host "Added $($mediaFiles.Count) files from $mediaFolder"
} else {
    Write-Host "Warning: $mediaFolder not found!" -ForegroundColor Yellow
}
$allFiles = $allFiles | Where-Object { Test-Path $_ }
Write-Host "_ Total files to zip: $($allFiles.Count)"

$stagingFolder = "build_temp"
Remove-Item $stagingFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingFolder | Out-Null
foreach ($file in $allFiles) {
    $relativePath = Split-Path $file -Leaf
    $destination = Join-Path $stagingFolder $relativePath
    Copy-Item $file -Destination $destination -Force
}

try {
    Compress-Archive -Path "$stagingFolder\*" -DestinationPath $zipName -Force
    Write-Host "_ ZIP created successfully: $zipName" -ForegroundColor Green
} catch {
    Write-Host "_ ZIP creation failed: $($_.Exception.Message)" -ForegroundColor Red
}
Remove-Item $stagingFolder -R
Write-Host "`n===== BUILD COMPLETE =====" -ForegroundColor Cyan
Write-Host "Output EXE: $finalExe"
Write-Host "ZIP Archive: $zipName"
Write-Host "Timestamp: $timestamp"

Write-Host "_ Done: $finalExe + $zipName"
Write-Host "Script completed!" -ForegroundColor Yellow

# Remove/skip folder opening in CI
if ($env:GITHUB_REF_NAME -eq $null) {
    Invoke-Item (Get-Item $finalExe).DirectoryName
}
