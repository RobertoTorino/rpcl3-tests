ALERT_SOUND WAVE "C:\TestEmbed\alert.wav"

# Adjust paths as needed
$baseExe    = "C:\TestEmbed\source.exe"
$outputExe  = "C:\TestEmbed\withsound.exe"
$wav        = "C:\TestEmbed\alert.wav"
$resHacker  = "C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe"
$rcPath     = "C:\TestEmbed\add_media.rc"
$logPath    = "C:\TestEmbed\build.log"

# Write RC file (no blank lines)
[System.IO.File]::WriteAllText($rcPath, 'ALERT_SOUND WAVE "' + $wav + '"', [System.Text.Encoding]::ASCII)

# Build Resource Hacker command
$rhArgs = @(
    '-open',    "`"$baseExe`"",
    '-save',    "`"$outputExe`"",
    '-action',  'addoverwrite',
    '-resource',"`"$rcPath`"",
    '-log',     "`"$logPath`""
)

Write-Host "Running: $resHacker $($rhArgs -join ' ')"
& $resHacker @rhArgs
Write-Host "Done. See build.log for details."

