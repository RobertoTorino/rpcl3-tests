ALERT_SOUND WAVE "C:\TestEmbed\alert.wav"

# Adjust paths as needed
$baseExe    = "C:\TestEmbed\source.exe"
$outputExe  = "C:\TestEmbed\withsound.exe"
$wav        = "C:\TestEmbed\alert.wav"
$resHacker  = "C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe"
$rcPath     = "C:\TestEmbed\add_media.rc"
$logPath    = "C:\TestEmbed\build.log"

Remove-Item 'C:\TestEmbed\add_media.rc' -ErrorAction SilentlyContinue
Remove-Item 'C:\TestEmbed\withsound.exe' -ErrorAction SilentlyContinue
Remove-Item 'C:\TestEmbed\build.log' -ErrorAction SilentlyContinue

Test-Path 'C:\TestEmbed\source.exe'      # Should be True
Test-Path 'C:\TestEmbed\alert.wav'       # Should be True

# Write RC file (no blank lines)
[System.IO.File]::WriteAllText(
        'C:\TestEmbed\add_media.rc',
        'ALERT_SOUND WAVE "C:\TestEmbed\alert.wav"',
        [System.Text.Encoding]::ASCII
)

Get-Content 'C:\TestEmbed\add_media.rc'

[System.IO.File]::ReadAllBytes('C:\TestEmbed\add_media.rc') | % { "{0:X2}" -f $_ } | -join ' '

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

