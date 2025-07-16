cmd.exe /c run_build.cmd
Compiling AHK...
Current directory: C:\repos\rpcl3-process-control\_build
Path verification:
- Script: rpcl3pc.ahk (exists: True)
- Ahk2Exe: C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe (exists: True)
- Icon: rpcl3_media\rpcl3.ico (exists: True)
- Output will be: rpcl3pc.exe
Full command:
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in rpcl3pc.ahk /out rpcl3pc.exe /icon rpcl3_media\rpcl3.ico /compress 1
Executing...
Successfully compiled as:
"C:\repos\rpcl3-process-control\_build\rpcl3pc.exe"
Process exit code: 0
_ Compilation successful!
_ Creating ZIP: rpcl3pc_20250716_22.zip
Warning: rpcl3pc_20250716_22.exe not found!
Added: README.txt
Added: pc.ini
Added: LICENSE
Added: version.txt
Added: version.dat
Added 4 files from rpcl3_media
Total files to zip: 9
_ ZIP created successfully: rpcl3pc_20250716_22.zip
! Fallback EXE created, but MEDIA files were NOT embedded.

===== BUILD COMPLETE =====
Output EXE: rpcl3pc_20250716_22.exe
ZIP Archive: rpcl3pc_20250716_22.zip
Timestamp: 20250716_22
WARNING: File not found, skipping: rpcl3pc_20250716_22.exe
Copying rpcl3pc_20250716_22.zip to C:\repos\rpcl3-process-control\new_builds
Copying rpcl3pc.exe to C:\repos\rpcl3-process-control\new_builds
All available files copied to: C:\repos\rpcl3-process-control\new_builds
Done: rpcl3pc_20250716_22.exe + rpcl3pc_20250716_22.zip
Script completed. Press any key to exit...

Get-Item : Cannot find path 'C:\repos\rpcl3-process-control\_build\rpcl3pc_20250716_22.exe' because it does not exist.
At C:\repos\rpcl3-process-control\_build\build.ps1:184 char:14
+ Invoke-Item (Get-Item $finalExe).DirectoryName
+              ~~~~~~~~~~~~~~~~~~
+ CategoryInfo          : ObjectNotFound: (C:\repos\rpcl3-...20250716_22.exe:String) [Get-Item], ItemNotFoundExcep
tion
+ FullyQualifiedErrorId : PathNotFound,Microsoft.PowerShell.Commands.GetItemCommand

Invoke-Item : Cannot bind argument to parameter 'Path' because it is null.
At C:\repos\rpcl3-process-control\_build\build.ps1:184 char:13
+ Invoke-Item (Get-Item $finalExe).DirectoryName
+             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
+ CategoryInfo          : InvalidData: (:) [Invoke-Item], ParameterBindingValidationException
+ FullyQualifiedErrorId : ParameterArgumentValidationErrorNullNotAllowed,Microsoft.PowerShell.Commands.InvokeItemC
ommand

