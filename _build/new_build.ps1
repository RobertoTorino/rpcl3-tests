C:\repos\rpcl3-process-control\_build>run_build.cmd
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
Process exit code: 0
_ Compilation successful!
Creating resource script...
=== add_media.rc content ===
LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL
RPCL3_GOOD_MORNING WAVE "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_GOOD_MORNING.wav"
RPCL3_GAME_OVER WAVE "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_GAME_OVER.wav"
RPCL3_DEFAULT_256 PNG "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_DEFAULT_256.png"
============================
RC file created successfully:
LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL
RPCL3_GOOD_MORNING WAVE "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_GOOD_MORNING.wav"
RPCL3_GAME_OVER WAVE "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_GAME_OVER.wav"
RPCL3_DEFAULT_256 PNG "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_DEFAULT_256.png"
Embedding resources directly from RC with Resource Hacker...
Executing Resource Hacker with arguments:
"C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe"
-open "C:\repos\rpcl3-process-control\_build\rpcl3pc.exe"
-save "rpcl3pc_20250714_21.exe"
-action addoverwrite
-resource "C:\repos\rpcl3-process-control\_build\add_media.rc" -log "build.log"

Resource Hacker output:
RESOURCE EMBEDDING ERROR: Output file was not created
Resource Hacker log contents:
[14 Jul 2025, 21:28:14]
Current Directory: C:\repos\rpcl3-process-control\_build

Commandline:
"C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe"
-open "C:\repos\rpcl3-process-control\_build\rpcl3pc.exe"
-save "rpcl3pc_20250714_21.exe"
-action addoverwrite -resource "C:\repos\rpcl3-process-control\_build\add_media.rc"
-log "build.log"

Open    : C:\repos\rpcl3-process-control\_build\rpcl3pc.exe
Save    : C:\repos\rpcl3-process-control\_build\rpcl3pc_20250714_21.exe
Resource: C:\repos\rpcl3-process-control\_build\add_media.rc
Error   : Both resource type and resource name must be specified.

Success!

Attempting fallback (copy without resources)...
Fallback successful (no embedded resources)
_ Creating ZIP: rpcl3pc_20250714_21.zip
Added: rpcl3pc_20250714_21.exe
Added: README.txt
Added: pc.ini
Added: LICENSE
Added: version.txt
Added: version.dat
Added 4 files from rpcl3_media
Total files to zip: 10
_ ZIP created successfully: rpcl3pc_20250714_21.zip
! Fallback EXE created, but MEDIA files were NOT embedded.

===== BUILD COMPLETE =====
Output EXE: rpcl3pc_20250714_21.exe
ZIP Archive: rpcl3pc_20250714_21.zip
Timestamp: 20250714_21
Copying rpcl3pc_20250714_21.exe to C:\repos\rpcl3-process-control\new_builds
Copying rpcl3pc_20250714_21.zip to C:\repos\rpcl3-process-control\new_builds
Copying rpcl3pc.exe to C:\repos\rpcl3-process-control\new_builds
All available files copied to: C:\repos\rpcl3-process-control\new_builds
Done: rpcl3pc_20250714_21.exe + rpcl3pc_20250714_21.zip
Script completed. Press any key to exit...
PS C:\repos\rpcl3-process-control\_build>
