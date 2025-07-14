do I need this if i set this as the default bin in the AHK compiler?

$baseFile = "$($ahk2exePath.Replace('Ahk2Exe.exe', 'SC_CustomRPCL3PC.bin'))"

My test rc file contents:
LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL

RPCL3_GAME_OVER RCDATA "RPCL3_GAME_OVER.bin"

The rc file contents from the build:
RPCL3_GOOD_MORNING WAVE "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_GOOD_MORNING.wav"
RPCL3_GAME_OVER WAVE "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_GAME_OVER.wav"
RPCL3_DEFAULT_256 PNG "C:\repos\rpcl3-process-control\_build\rpcl3_media\RPCL3_DEFAULT_256.png"


The log output:
Embedding resources directly from RC with Resource Hacker...
Executing Resource Hacker with arguments:
"C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe" -open "C:\repos\rpcl3-process-control\_build\rpcl3pc.exe" -save "rpcl3pc_20250714_21.exe" -action addoverwrite -resource "C:\repos\rpcl3-process-control\_build\add_media.rc" -log "build.log"
Resource Hacker output:


RESOURCE EMBEDDING ERROR: Output file was not created
Resource Hacker log contents:
[14 Jul 2025, 21:00:22]

Current Directory:
C:\repos\rpcl3-process-control\_build

Commandline:
"C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe"
-open "C:\repos\rpcl3-process-control\_build\rpcl3pc.exe"
-save "rpcl3pc_20250714_21.exe"
-action addoverwrite
-resource "C:\repos\rpcl3-process-control\_build\add_media.rc"
-log "build.log"

Open    : C:\repos\rpcl3-process-control\_build\rpcl3pc.exe
Save    : C:\repos\rpcl3-process-control\_build\rpcl3pc_20250714_21.exe
Resource: C:\repos\rpcl3-process-control\_build\add_media.rc

Error: Both resource type and resource name must be specified.
Success!

Attempting fallback (copy without resources)...
Fallback successful (no embedded resources)

