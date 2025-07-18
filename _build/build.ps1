# Variables
Write-Host ":: Starting build script"

# Resolve full paths to inputs and tools
$input = Join-Path $PWD "rpcl3pc.ahk"
$output = Join-Path $PWD "rpcl3pc.exe"
$icon = Join-Path $PWD "rpcl3_media\rpcl3.ico"
$ahk2exe = Join-Path $PWD "Ahk2Exe.exe"
$upx = Join-Path $PWD "upx\upx.exe"

# Check all files exist
foreach ($file in @($input, $icon, $ahk2exe, $upx)) {
    if (-not (Test-Path $file)) {
        Write-Error "Required file not found: $file"
        exit 1
    } else {
        Write-Host "Found: $file"
    }
}

# Prepare logs for stdout and stderr
$outLog = Join-Path $PWD "ahk2exe_stdout.log"
$errLog = Join-Path $PWD "ahk2exe_stderr.log"

Write-Host ":: Building EXE..."

# Run Ahk2Exe.exe with args
$proc = Start-Process -FilePath $ahk2exe `
    -ArgumentList "/in", "`"$input`"", "/out", "`"$output`"", "/icon", "`"$icon`"" `
    -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog

Write-Host "Ahk2Exe ExitCode: $($proc.ExitCode)"

# Output logs for debugging
Write-Host "===== Ahk2Exe Standard Output ====="
Get-Content $outLog

Write-Host "===== Ahk2Exe Standard Error ====="
Get-Content $errLog

# Check if output exe was created
if (!(Test-Path $output)) {
    Write-Error ":: Build failed — output file not found at $output."
    exit 1
}

Write-Host ":: Build succeeded - output exe found."

# Optional: Compress output EXE using UPX
Write-Host ":: Compressing EXE with UPX..."
$upxProc = Start-Process -FilePath $upx `
    -ArgumentList "--best", "`"$output`"" `
    -NoNewWindow -Wait -PassThru

Write-Host "UPX ExitCode: $($upxProc.ExitCode)"

Write-Host ":: Build script complete."
exit 0


