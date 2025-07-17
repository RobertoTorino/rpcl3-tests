$scriptName     = "rpcl3pc.ahk"
$finalExeName   = "rpcl3pc"
$ahk2exePath    = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
$upxPath        = "C:\upx-5.0.1-win64\upx.exe"
$mediaFolder    = "rpcl3_media"
$iconPath       = "rpcl3_media\rpcl3.ico"
$versionDat     = "version.dat"
$versionTxt     = "version.txt"
$versionTpl     = "version_template.txt"
$extraAssets    = @("README.txt", "pc.ini", "LICENSE", $versionTxt, $versionDat)

if ($env:GITHUB_REF_NAME) {
    $tag = $env:GITHUB_REF_NAME
    if ($tag -like 'v*') { $ver = $tag.Substring(1) } else { $ver = $tag }
    $suffix = "_$tag"
} else {
    $suffix = "LocalBuild_" + (Get-Date -Format "yyyyMMdd_HHmmss")  # NO LEADING UNDERSCORE
}
$finalExe = "$finalExeName$suffix.exe"
$zipName  = "$finalExeName$suffix.zip"
