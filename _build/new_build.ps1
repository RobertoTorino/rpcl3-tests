# === BUILD ROBUST RC FILE ===

$rcLines = @()

# Add WAV resources
foreach ($wav in $wavFiles) {
    $wavPath = (Resolve-Path $wav -ErrorAction Stop).Path
    $resName = [System.IO.Path]::GetFileNameWithoutExtension($wav).ToUpper()
    $rcLines += "$resName WAVE `"$wavPath`""
}

# Add PNG resources
foreach ($png in $pngFile) {
    if (Test-Path $png) {
        $pngPath = (Resolve-Path $png).Path
        $resName = [System.IO.Path]::GetFileNameWithoutExtension($png).ToUpper()
        $rcLines += "$resName PNG `"$pngPath`""
    }
}

# Filter out any accidental empty lines
$rcLines = $rcLines | Where-Object { $_.Trim().Length -gt 0 }

# Optionally, add a LANGUAGE line at the top (not mandatory)
# $rcLines = @('LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL') + $rcLines

# Join with literal newlines, NO trailing blank line, ASCII encoding
[System.IO.File]::WriteAllText("add_media.rc", ($rcLines -join "`n"), [System.Text.Encoding]::ASCII)

# === Verification (Optional) ===
Write-Host "=== add_media.rc content ===" -ForegroundColor Cyan
Get-Content "add_media.rc" | ForEach-Object { Write-Host "  $_" }
Write-Host "============================"
