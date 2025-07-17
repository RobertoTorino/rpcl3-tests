FileInstall, rpcl3_media\RPCL3_GOOD_MORNING.wav, %A_Temp%\RPCL3_GOOD_MORNING.wav
FileInstall, rpcl3_media\RPCL3_GAME_OVER.wav, %A_Temp%\RPCL3_GAME_OVER.wav
FileInstall, rpcl3_media\RPCL3_DEFAULT_256.png, %A_Temp%\RPCL3_DEFAULT_256.png




defaultIcon := A_Temp . "\RPCL3_DEFAULT_256.png"
if FileExist(defaultIcon) {
    Gui, Add, Picture, x580 y22 w65 h65 vRPCL3Icon, %defaultIcon%
}


wav := A_Temp . "\RPCL3_GOOD_MORNING.wav"
if FileExist(wav)
SoundPlay, %wav%
else
MsgBox, WAV not found at: %wav%


# Path to UPX (update this if you put it elsewhere)
$upxPath = "C:\path\to\upx.exe"
# Compress the timestamped EXE (or $baseExeName.exe, depending on your script)
Write-Host "Compressing EXE with UPX..."
& $upxPath --best --lzma $finalExe
Write-Host "UPX compression finished."
