# Remove or comment out these lines:
# $timestamp    = Get-Date -Format "yyyyMMdd_HH"
# $finalExe     = "$finalExeName`_$timestamp.exe"
# $zipName      = "$finalExeName`_$timestamp.zip"

# Instead, use:
$timestamp = Get-Date -Format "yyyyMMdd_HH"
if ($env:GITHUB_REF_NAME) {
    $tag = $env:GITHUB_REF_NAME
    if ($tag -like 'v*') { $ver = $tag.Substring(1) } else { $ver = $tag }
    $finalExe = "${finalExeName}_$tag.exe"
    $zipName  = "${finalExeName}_$tag.zip"
} else {
    $localTag = "LocalBuild_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $finalExe = "${finalExeName}_$localTag.exe"
    $zipName  = "${finalExeName}_$localTag.zip"
}
