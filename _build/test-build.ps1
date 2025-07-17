"C:/Program Files/PowerShell/7/pwsh.exe" -File C:/repos/rpcl3-process-control/_build/build.ps1
Full command:
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in rpcl3pc.ahk /out rpcl3pc.exe /icon rpcl3_media\rpcl3.ico /compress 1
Executing...
Process exit code: 0
_ Compilation successful!
Copied rpcl3pc.exe to rpcl3pc_20250717_08.exe (timestamped build EXE)
Pre-UPX size: 3215360
Ultimate Packer for eXecutables
Copyright (C) 1996 - 2025
UPX 5.0.1       Markus Oberhumer, Laszlo Molnar & John Reiser    May 6th 2025

File size         Ratio      Format      Name
--------------------   ------   -----------   -----------
3215360 ->   2058752   64.03%    win64/pe     rpcl3pc_20250717_08.exe

Packed 1 file.
Post-UPX size: 2058752
Compressing EXE with UPX...
Ultimate Packer for eXecutables
Copyright (C) 1996 - 2025
UPX 5.0.1       Markus Oberhumer, Laszlo Molnar & John Reiser    May 6th 2025

File size         Ratio      Format      Name
--------------------   ------   -----------   -----------
upx: rpcl3pc_20250717_08.exe: AlreadyPackedException: already packed by UPX

Packed 1 file: 0 ok, 1 error.
UPX compression finished.
_ Creating ZIP: rpcl3pc_20250717_08.zip
Added: rpcl3pc_20250717_08.exe
Added: README.txt
Added: pc.ini
Added: LICENSE
Added: version.txt
Added: version.dat
Added 4 files from rpcl3_media
Total files to zip: 10
_ ZIP created successfully: rpcl3pc_20250717_08.zip
! Fallback EXE created, but MEDIA files were NOT embedded.

===== BUILD COMPLETE =====
Output EXE: rpcl3pc_20250717_08.exe
ZIP Archive: rpcl3pc_20250717_08.zip
Timestamp: 20250717_08
Copying rpcl3pc_20250717_08.exe to C:\repos\rpcl3-process-control\new_builds
Copying rpcl3pc_20250717_08.zip to C:\repos\rpcl3-process-control\new_builds
Copying rpcl3pc.exe to C:\repos\rpcl3-process-control\new_builds
All available files copied to: C:\repos\rpcl3-process-control\new_builds
Done: rpcl3pc_20250717_08.exe + rpcl3pc_20250717_08.zip
Script completed. Press any key to exit...