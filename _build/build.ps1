if (Test-Path "$baseExeName.exe") {
    # ... your current success message ...
    Copy-Item "$baseExeName.exe" "$finalExe" -Force
    Write-Host "Copied $baseExeName.exe to $finalExe (timestamped build EXE)"
} else {
    # ... your error branch ...
}
