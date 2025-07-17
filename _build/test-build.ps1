Summary of what to try:
Add this to your script:


Write-Host "Pre-UPX size:" (Get-Item $finalExe).Length
$upxResult = & $upxPath --best --lzma $finalExe
$upxResult | ForEach-Object { Write-Host $_ }
Write-Host "Post-UPX size:" (Get-Item $finalExe).Length

This will show realtime if UPX is running, and show before/after size.

Try UPX directly in CMD for a clear error:

"C:\upx-5.0.1-win64\upx.exe" --best --lzma C:\repos\rpcl3-process-control\_build\rpcl3pc_20250716_22.exe
Review the output:
but either can't compress further, can't pack this file, or the EXE is recreated afte
