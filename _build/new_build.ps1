RPCL3_GOOD_MORNING WAVE "C:\\repos\\rpcl3-process-control\\_build\\rpcl3_media\\RPCL3_GOOD_MORNING.wav"
RPCL3_GAME_OVER WAVE "C:\\repos\\rpcl3-process-control\\_build\\rpcl3_media\\RPCL3_GAME_OVER.wav"
RPCL3_DEFAULT_256 PNG "C:\\repos\\rpcl3-process-control\\_build\\rpcl3_media\\RPCL3_DEFAULT_256.png"


$rcContent = @()
foreach ($wav in $wavFiles) {
    $wavPath = (Resolve-Path $wav -ErrorAction Stop).Path
    $resName = [System.IO.Path]::GetFileNameWithoutExtension($wav).ToUpper()
    $rcContent += "$resName WAVE `"$wavPath`""
}
foreach ($png in $pngFile) {
    $pngPath = (Resolve-Path $png).Path
    $resName = [System.IO.Path]::GetFileNameWithoutExtension($png).ToUpper()
    $rcContent += "$resName PNG `"$pngPath`""
}
$rcContent | Out-File "add_media.rc" -Encoding ASCII
