; AutoHotkey portion to embed assets
FileInstall, rpcl3_media\RPCL3_GOOD_MORNING.wav, %A_Temp%\RPCL3_GOOD_MORNING.wav
FileInstall, rpcl3_media\RPCL3_GAME_OVER.wav, %A_Temp%\RPCL3_GAME_OVER.wav
FileInstall, rpcl3_media\RPCL3_DEFAULT_256.png, %A_Temp%\RPCL3_DEFAULT_256.png

; In your code you can now use:
; %A_Temp%\RPCL3_GOOD_MORNING.wav etc
MsgBox, WAV will be at: %A_Temp%\RPCL3_GOOD_MORNING.wav




# Build FileInstall lines for your .ahk
$fileInstallLines = @()
foreach ($wav in $wavFiles) {
    $assetName = Split-Path $wav -Leaf
    $fileInstallLines += "FileInstall, $wav, `%A_Temp`%\\$assetName"
}
foreach ($png in $pngFile) {
    $assetName = Split-Path $png -Leaf
    $fileInstallLines += "FileInstall, $png, `%A_Temp`%\\$assetName"
}
Write-Host "`n# Copy-paste these lines to your AHK script:`n"
$fileInstallLines | ForEach-Object { Write-Host $_ }
