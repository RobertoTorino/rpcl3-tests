# === EMBED RESOURCES DIRECTLY FROM RC ===
Write-Host "Embedding resources directly from RC with Resource Hacker..." -ForegroundColor Cyan

# Always create the RC file as ASCII/ANSI for maximum compatibility
$rcContent | Out-File "add_media.rc" -Encoding ASCII

# Build Resource Hacker command with proper quoting
$rhArgs = @(
    "-open", "`"$(Resolve-Path "$baseExeName.exe")`"",
    "-save", "`"$finalExe`"",
    "-action", "addoverwrite",
    "-resource", "`"$(Resolve-Path "add_media.rc")`"",
    "-log", "`"build.log`""
)

Write-Host "Executing Resource Hacker with arguments:" -ForegroundColor Yellow
Write-Host "`"$resHackerPath`" $($rhArgs -join ' ')"

try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $resHackerPath
    $psi.Arguments = $rhArgs
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    Write-Host "Resource Hacker output:" -ForegroundColor DarkGray
    Write-Host $stdout
    Write-Host $stderr

    if ($process.ExitCode -ne 0) {
        throw "Resource Hacker failed with exit code $($process.ExitCode)"
    }

    if (-not (Test-Path "$finalExe")) {
        throw "Output file was not created"
    }

    Write-Host "Resource embedding successful!" -ForegroundColor Green
}
catch {
    Write-Host "RESOURCE EMBEDDING ERROR: $_" -ForegroundColor Red

    # Check log file if it exists
    if (Test-Path "build.log") {
        Write-Host "Resource Hacker log contents:" -ForegroundColor Yellow
        Get-Content "build.log" | ForEach-Object { Write-Host "  $_" }
    }

    # Fallback to copying without resources
    Write-Host "Attempting fallback (copy without resources)..." -ForegroundColor Yellow
    try {
        Copy-Item "$baseExeName.exe" "$finalExe" -Force
        Write-Host "Fallback successful (no embedded resources)" -ForegroundColor Green
    }
    catch {
        Write-Error "Fallback copy failed: $_"
        Exit 1
    }
}
