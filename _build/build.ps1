The files are still not embedded, this is my builscript and below that my AHK script which is build in AHK version 1.

# === CONFIG ===
$scriptName     = "rpcl3pc.ahk"
$baseExeName    = "rpcl3pc"
$finalExeName   = "rpcl3pc"
$ahk2exePath    = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
$mediaFolder    = "rpcl3_media"
$iconPath       = "rpcl3_media\rpcl3.ico"
$versionDat     = "version.dat"
$versionTxt     = "version.txt"
$versionTpl     = "version_template.txt"
$extraAssets = @("README.txt", "pc.ini", "LICENSE", $versionTxt, $versionDat)

# === TIMESTAMP ===
$timestamp    = Get-Date -Format "yyyyMMdd_HH"
$finalExe     = "$finalExeName`_$timestamp.exe"
$zipName      = "$finalExeName`_$timestamp.zip"


# === VERSIONING ===
Copy-Item $versionTpl $versionTxt -Force
(Get-Content $versionTxt) -replace "%%DATETIME%%", $timestamp | Set-Content $versionTxt
$timestamp | Set-Content $versionDat

# === CLEANUP OLD FILES ===
Remove-Item "$baseExeName.exe","$finalExe","build.log","$zipName" -ErrorAction SilentlyContinue

# === COMPILE SCRIPT ===
Write-Host "Compiling AHK..."


# Show current working directory
Write-Host "Current directory: $(Get-Location)"

# Verify all paths
Write-Host "Path verification:" -ForegroundColor Yellow
Write-Host "- Script: $scriptName (exists: $(Test-Path $scriptName))"
Write-Host "- Ahk2Exe: $ahk2exePath (exists: $(Test-Path $ahk2exePath))"
Write-Host "- Icon: $iconPath (exists: $(Test-Path $iconPath))"
Write-Host "- Output will be: $baseExeName.exe"

# Build the argument list with proper quoting
$arguments = @(
    "/in", $scriptName,
    "/out", "$baseExeName.exe",
    "/icon", $iconPath,
    "/compress", "1"
)

Write-Host "Full command:" -ForegroundColor Cyan
Write-Host "`"$ahk2exePath`" $($arguments -join ' ')"

# Execute with detailed error capture
Write-Host "Executing..." -ForegroundColor Green
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

Write-Host "Process exit code: $($process.ExitCode)"

# Check if output file was created
if (Test-Path "$baseExeName.exe") {
    Write-Host "_ Compilation successful!" -ForegroundColor Green
} else {
    Write-Host "_ Output file not created!" -ForegroundColor Red
    Write-Error "Compilation failed."
    Exit 1
}


# === ZIP CONTENTS ===
Write-Host "_ Creating ZIP: $zipName"

# Build file list
$allFiles = @()

# Add final executable
if (Test-Path $finalExe) {
    $allFiles += $finalExe
    Write-Host "Added: $finalExe"
} else {
    Write-Host "Warning: $finalExe not found!" -ForegroundColor Yellow
}

# Add extra assets
foreach ($asset in $extraAssets) {
    if (Test-Path $asset) {
        $allFiles += $asset
        Write-Host "Added: $asset"
    } else {
        Write-Host "Warning: $asset not found!" -ForegroundColor Yellow
    }
}

# Add media files
if (Test-Path $mediaFolder) {
    $mediaFiles = Get-ChildItem -Path $mediaFolder -File | ForEach-Object { $_.FullName }
    $allFiles += $mediaFiles
    Write-Host "Added $($mediaFiles.Count) files from $mediaFolder"
} else {
    Write-Host "Warning: $mediaFolder not found!" -ForegroundColor Yellow
}

# Remove any missing paths
$allFiles = $allFiles | Where-Object { Test-Path $_ }

Write-Host "Total files to zip: $($allFiles.Count)"

# Create build staging folder
$stagingFolder = "build_temp"
Remove-Item $stagingFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingFolder | Out-Null

# Copy all files into staging while preserving folder structure
foreach ($file in $allFiles) {
    $relativePath = Resolve-Path -Relative $file
    $destination = Join-Path $stagingFolder $relativePath
    $destinationDir = Split-Path $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item $file -Destination $destination -Force
}

# Create ZIP from staging
try {
    Compress-Archive -Path "$stagingFolder\*" -DestinationPath $zipName -Force
    Write-Host "_ ZIP created successfully: $zipName" -ForegroundColor Green
} catch {
    Write-Host "_ ZIP creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Remove-Item $stagingFolder -R
Write-Host "! Fallback EXE created, but MEDIA files were NOT embedded." -ForegroundColor Yellow
Write-Host "`n===== BUILD COMPLETE =====" -ForegroundColor Cyan
Write-Host "Output EXE: $finalExe"
Write-Host "ZIP Archive: $zipName"
Write-Host "Timestamp: $timestamp"


# === COPY OUTPUT TO NEW_BUILDS FOLDER ===
try {
    $buildFolder = "C:\repos\rpcl3-process-control\new_builds"
    $outputFiles = @(
        $finalExe,                 # e.g. rpcl3pc_20250704_07.exe
        $zipName,                  # e.g. rpcl3pc_20250704_07.zip
        "$baseExeName.exe"         # e.g. rpcl3pc.exe (if you want it copied too)
    )

    # Ensure $buildFolder is a proper directory
    if (Test-Path $buildFolder) {
        $item = Get-Item $buildFolder
        if (-not $item.PSIsContainer) {
            Write-Host "Removing file named 'new_builds' so we can create a folder instead..."
            Remove-Item $buildFolder -Force
        }
    }

    if (-not (Test-Path $buildFolder)) {
        Write-Host "Creating build folder: $buildFolder"
        New-Item -ItemType Directory -Path $buildFolder | Out-Null
    }

    # Copy files to build folder
    foreach ($file in $outputFiles) {
        if (Test-Path $file) {
            Write-Host "Copying $file to $buildFolder"
            Copy-Item $file -Destination $buildFolder -Force
        } else {
            Write-Warning "File not found, skipping: $file"
        }
    }

    Write-Host "All available files copied to: $buildFolder"
}
catch {
    Write-Error "Error copying build files: $_"
}

# === LOG SUCCESS ===
"[$timestamp] Built $finalExe with embedded WAVs" | Add-Content "changelog.txt"
Write-Host "Done: $finalExe + $zipName"

# Keep window open (bulletproof method)
Write-Host "Script completed. Press any key to exit..." -ForegroundColor Yellow
cmd /c pause | Out-Null

Invoke-Item (Get-Item $finalExe).DirectoryName


The AHK script:
; YouTube: @game_play267
; Twitch: RR_357000
; X:@relliK_2048
; Discord:
; RPCL3 Process Control
#SingleInstance force
#Persistent
#NoEnv

SetWorkingDir %A_ScriptDir%

; ─── Globals. ─────────────────────────────────────────────────────────────────────────────────────────────────────────
OnExit("SaveSettings")
logInterval := 120000
lastResourceLog := 0


; ─── Global config variables. ─────────────────────────────────────────────────────────────────────────────────────────
global muteSound    := 0
baseDir             := A_ScriptDir
iniFile             := A_ScriptDir . "\pc.ini"
logFile             := A_ScriptDir . "\pc.log"
fallbackLog         := A_ScriptDir . "\pc_fallback.log"
rpcs3Exe            := A_ScriptDir  . "\rpcs3.exe"


; ─── Conditionally set default priority if it's not already set. ──────────────────────────────────────────────────────
IniRead, priorityValue, %iniFile%, PRIORITY, Priority
if (priorityValue = "")
IniWrite, Normal, %iniFile%, PRIORITY, Priority


; ─── Read rpcs3 path and extract executable name if found. ────────────────────────────────────────────────────────────
IniRead, rpcs3Path, %iniFile%, RPCS3, Path
if (rpcs3Path != "") {
    global rpcs3Exe
    SplitPath, rpcs3Path, rpcs3Exe
}


; ─── Set as admin. ────────────────────────────────────────────────────────────────────────────────────────────────────
if not A_IsAdmin
{
    try
    {
        Run *RunAs "%A_ScriptFullPath%"
    }
    catch
    {
        MsgBox, 0, Error, This script needs to be run as Administrator.
    }
    ExitApp
}


; ─── Unique window class name. ────────────────────────────────────────────────────────────────────────────────────────
#WinActivateForce
scriptTitle := "RPCS3 Process Priority"
if WinExist("ahk_class AutoHotkey ahk_exe " A_ScriptName) && !A_IsCompiled {
;Re-run if script is not compiled
ExitApp
}

;Try to send a message to existing instance
if A_Args[1] = "activate" {
    PostMessage, 0x5555,,,, ahk_class AutoHotkey
    ExitApp
}

; AutoHotkey portion to embed assets
FileInstall, rpcl3_media\RPCL3_GOOD_MORNING.wav, %A_Temp%\\RPCL3_GOOD_MORNING.wav
FileInstall, rpcl3_media\RPCL3_GAME_OVER.wav, %A_Temp%\\RPCL3_GAME_OVER.wav
FileInstall, rpcl3_media\RPCL3_DEFAULT_256.png, %A_Temp%\\RPCL3_DEFAULT_256.png


; ─── Sound settings at startup. ───────────────────────────────────────────────────────────────────────────────────────
IniRead, muteSound, %iniFile%, MUTE_SOUND, Mute, 0


; ─── Start GUI. ───────────────────────────────────────────────────────────────────────────────────────────────────────
title := "RPCS3 Process Priority - " . Chr(169) . " " . A_YYYY . " - Philip"
Gui, Show, w670 h244, %title%
Gui, +LastFound +AlwaysOnTop
Gui, Font, s10 q5, Segoe UI
Gui, Margin, 15, 15
GuiHwnd := WinExist()

; Priority section.
Gui, Font, s10 q5 bold, Segoe UI
Gui, Add, GroupBox,                      x10 y5 w650 h180, RPCL3 Process Priority Manager
Gui, Add, Text,                          x20 y35, Priority:
Gui, Add, DropDownList, vPriorityChoice  x20 y59 w150 r6, Idle|Below Normal|Normal|Above Normal|High|Realtime
LoadSettings()
Gui, Add, Button, gSetPriority           x20 y95 w150 h75, SET PRIORITY
Gui, Add, Button, gRunRPCS3             x180 y95 w150 h75, RUN RPCS3
Gui, Add, Button, gRefreshPath          x340 y95 w150 h75, REFRESH PATH
Gui, Add, Button, gSetRpcs3Path         x500 y95 w150 h75, SET PATH
Gui, Add, Button, gToggleMute vMuteBtn  x180 y58 w150 h27 +Center +0x200, % (muteSound ? "UNMUTE" : "MUTE")
defaultIcon := A_ScriptDir . "%A_Temp%\RPCL3_DEFAULT_256.png"
if FileExist(defaultIcon) {
Gui, Add, Picture, x580 y22 w65 h65 vRPCL3Icon, %defaultIcon%
}
Gui, Add, Text,                         x342 y66, Press the Escape button to quit rpcs3.

; ─── Custom status bar, 1 is used for RPCS3 status, use 2 and 3. ──────────────────────────────────────────────────────
Gui, Add, GroupBox,                   x0 y190 w670 h33
Gui, Add, Text, vCurrentPriority      x6 y202 w150,

; ─── Bottom statusbar, 1 is reserved for process priority status, use 2. ──────────────────────────────────────────────
Gui, Add, StatusBar, vStatusBar1 hWndhStatusBar
SB_SetParts(345, 325)
UpdateStatusBar(msg, segment := 1) {
SB_SetText(msg, segment)
}

; ─── Start timers for cpu/memory every x second(s). ───────────────────────────────────────────────────────────────────
SetTimer, UpdateCPUMem, 1000

; ─── Force one immediate priority update. ─────────────────────────────────────────────────────────────────────────────
Gosub, UpdatePriority

; ─── Start priority timer after a delay (3s between updates), runs every 3 seconds. ───────────────────────────────────
SetTimer, UpdatePriority, 3000

; ─── Record timestamp of last update. ─────────────────────────────────────────────────────────────────────────────────
FormatTime, timeStamp, , yyyy-MM-dd HH:mm:ss
Log("DEBUG", "Writing Timestamp " . timeStamp . " to " . iniFile)
IniWrite, %timeStamp%, %iniFile%, LAST_UPDATE, LastUpdated

; ─── This return ends all updates to the gui. ─────────────────────────────────────────────────────────────────────────
return
; ─── END GUI. ─────────────────────────────────────────────────────────────────────────────────────────────────────────


OpenScriptDir:
Run, %A_ScriptDir%
return


; ─── Toggle sound in app. ─────────────────────────────────────────────────────────────────────────────────────────────
ToggleMute:
muteSound := !muteSound
IniWrite, %muteSound%, %iniFile%, MUTE_SOUND, Mute
GuiControl,, MuteBtn, % (muteSound ? "UNMUTE" : "MUTE")
SoundBeep, 750, 150
return


; ─── Refresh path. ────────────────────────────────────────────────────────────────────────────────────────────────────
RefreshRPCS3Path()


; ─── Refresh path to pcs3.exe. ────────────────────────────────────────────────────────────────────────────────────────
RefreshPath:
RefreshRPCS3Path()
CustomTrayTip("Path refreshed: " rpcs3Path, 1)
SB_SetText("PATH: " . rpcs3Path, 2)
Log("DEBUG", "Path refreshed: " . rpcs3Path)
return


; ─── Set path to rpcs3.exe function. ──────────────────────────────────────────────────────────────────────────────────
SetRpcs3Path:
Global rpcs3Path, rpcs3Exe
FileSelectFile, selectedPath,, , Select RPCS3 executable, Executable Files (*.exe)
if (selectedPath != "" && FileExist(selectedPath)) {
SaveRPCS3Path(selectedPath)

rpcs3Path := selectedPath
SplitPath, rpcs3Path, rpcs3Exe

SB_SetText("Path: " . selectedPath, 2)
Log("INFO", "Path saved: " . selectedPath)
} else {
CustomTrayTip("Path not selected or invalid.", 3)
SB_SetText("ERROR: No valid RPCS3 executable selected.", 2)
Log("ERROR", "No valid RPCS3 executable selected.")
}
Return


; ─── Get path to rpcs3.exe function. ──────────────────────────────────────────────────────────────────────────────────
GetRPCS3Path() {
static iniFile := A_ScriptDir . "\pc.ini"
local path

if !FileExist(iniFile) {
CustomTrayTip("Missing pc.ini.", 3)
SB_SetText("ERROR: Missing pc.ini when calling GetRPCS3Path.", 2)
Log("ERROR", "Missing pc.ini when calling GetRPCS3Path()")
return ""
}

IniRead, path, %iniFile%, RPCS3, Path
if (ErrorLevel) {
CustomTrayTip("Could not read [RPCS3] path from pc.ini.", 3)
SB_SetText("ERROR: Could not read [RPCS3] path from pc.ini.", 2)
Log("ERROR", "Could not read [RPCS3] path from pc.ini")
return ""
}

path := Trim(path, "`" " ")  ; trim surrounding quotes and spaces

    Log("DEBUG", "GetRPCS3Path, Path is: " . path)

    if (path != "" && FileExist(path) && SubStr(path, -3) = ".exe")
        return path

    CustomTrayTip("Could not read [RPCS3] path from: " . path, 3)
    SB_SetText("ERROR: Invalid or non-existent path in pc.ini: " . path, 2)
    Log("ERROR", "Invalid or non-existent path in pc.ini: " . path)
    return ""
}

SaveRPCS3Path(path) {
    static iniFile := A_ScriptDir . "\pc.ini"
    IniWrite, %path%, %iniFile%, RPCS3, Path
    Log("DEBUG", "Saved path to config: " . rpcs3Path)
    CustomTrayTip("Saved Path to config: " . rpcs3Path, 1)
}

rpcs3Path := GetRPCS3Path()
Log("DEBUG", "Saved path to config: " . rpcs3Path)

if (rpcs3Path = "") {
    MsgBox, 52, Warning, Path not set or invalid. Please select it now.
    FileSelectFile, selectedPath,, , Select RPCS3 executable, Executable Files (*.exe)
    if (selectedPath != "" && FileExist(selectedPath)) {
        SaveRPCS3Path(selectedPath)
        rpcs3Path := selectedPath
        MsgBox, 64, Info, Saved Path:`n%rpcs3Path%
    } else {
        MsgBox, 16, Error, No valid path selected. Exiting.
        ExitApp
    }
} else {
    MsgBox, 64, Info, Using Path:`n%rpcs3Path%
}
Return


; ─── RPCS3 path function. ─────────────────────────────────────────────────────────────────────────────────────────────
Rpcs3Path:
    FileSelectFile, selectedPath,, 3, Select RPCS3 executable, Executable Files (*.exe)
    if (selectedPath != "")
    {
        rpcs3Path := selectedPath
        IniWrite, %rpcs3Path%, %iniFile%, RPCS3, Path
        SB_SetText("Saved: Path saved: " . selectedPath, 2)
        Log("INFO", "Path saved: " . selectedPath)
    }
Return


; ─── Set process priority function. ───────────────────────────────────────────────────────────────────────────────────
SetPriority:
    Gui, Submit, NoHide
    if PriorityChoice =  ;empty or not selected
    {
        CustomTrayTip("Please select a priority before setting.", 2)
        return
    }

    priorityCode := ""
    if (PriorityChoice = "Idle")
        priorityCode := "L"
    else if (PriorityChoice = "Below Normal")
        priorityCode := "B"
    else if (PriorityChoice = "Normal")
        priorityCode := "N"
    else if (PriorityChoice = "Above Normal")
        priorityCode := "A"
    else if (PriorityChoice = "High")
        priorityCode := "H"
    else if (PriorityChoice = "Realtime")
        priorityCode := "R"

    Process, Exist, rpcs3.exe
    if (ErrorLevel) {
        Process, Priority, %ErrorLevel%, %priorityCode%
        CustomTrayTip("Set to: " PriorityChoice, 1)
        Log("INFO", "Set RPCS3 priority to " . PriorityChoice)
        SB_SetText("Priority set to " . PriorityChoice, 2)
        IniWrite, %PriorityChoice%, %iniFile%, PRIORITY, Priority
    } else {
        CustomTrayTip("RPCS3 not running.", 1)
        Log("WARN", "Attempted to set priority, but RPCS3 is not running.")
        SB_SetText("RPCS3 must be running when trying to set priority.", 2)
    }
return


; ─── Update process priority function. ────────────────────────────────────────────────────────────────────────────────
UpdatePriority:
    Process, Exist, rpcs3.exe
    if (!ErrorLevel) {
        GuiControl,, CurrentPriority, RPCS3 is not running.
        GuiControl, Disable, PriorityChoice
        GuiControl, Disable, Set Priority
        UpdateCPUMem()
        return
    }

    pid := ErrorLevel
    current := GetPriority(pid)

    GuiControl,, CurrentPriority, Priority: %current%

    Global lastPriority
    if (current != lastPriority) {
        GuiControl,, PriorityChoice, %current%
        lastPriority := current
        SB_SetText("Priority updated to " . current, 2)
    }

    GuiControl, Enable, PriorityChoice
    GuiControl, Enable, Set Priority
    UpdateCPUMem()
return


; ─── Get currrent process priority function. ──────────────────────────────────────────────────────────────────────────
GetPriority(pid) {
    try {
        wmi := ComObjGet("winmgmts:")
        query := "Select Priority from Win32_Process where ProcessId=" pid
        for proc in wmi.ExecQuery(query)
            return MapPriority(proc.Priority)
        return "Unknown"
    } catch e {
        CustomTrayTip("Failed to get priority.", 3)
        SB_SetText("ERROR: Failed to get priority: " . e.Message, 2)
        return "Error"
    }
}

MapPriority(val) {
    if (val = 4)
        return "Idle"
    if (val = 6)
        return "Below Normal"
    if (val = 8)
        return "Normal"
    if (val = 10)
        return "Above Normal"
    if (val = 13)
        return "High"
    if (val = 24)
        return "Realtime"
    if (val = 32)
        return "Normal"
    if (val = 64)
        return "Idle"
    if (val = 128)
        return "High"
    if (val = 256)
        return "Realtime"
    if (val = 16384)
        return "Below Normal"
    if (val = 32768)
        return "Above Normal"
    return "Unknown (" val ")"
}


; ─── Load settings function. ──────────────────────────────────────────────────────────────────────────────────────────
LoadSettings() {
    Global PriorityChoice, iniFile, rpcs3Exe

    Process, Exist, %rpcs3Exe%
    if (!ErrorLevel) {
        defaultPriority := "Normal"
        IniWrite, %defaultPriority%, %iniFile%, PRIORITY, Priority

        ; Extract just the filename for display
        SplitPath, iniFile, iniFileName

        ; Status bar message with clean formatting
        SB_SetText("Process Not Found. Priority [" defaultPriority "] Saved to " iniFileName ".", 2)
        CustomTrayTip("Initial Priority Set to " defaultPriority, 1)

        ; Update GUI
        GuiControl, ChooseString, PriorityChoice, %defaultPriority%
        PriorityChoice := defaultPriority

        Log("INFO", "Set default priority to " defaultPriority " in " iniFile)
    }
    else {
        ; Load saved priority if process exists
        IniRead, savedPriority, %iniFile%, PRIORITY, Priority, Normal
        GuiControl, ChooseString, PriorityChoice, %savedPriority%
        PriorityChoice := savedPriority
    }
}


; ─── Save current settings function. ──────────────────────────────────────────────────────────────────────────────────
SaveSettings() {
    Global PriorityChoice, iniFile

    ; Get current selection from GUI (important!)
    GuiControlGet, currentPriority,, PriorityChoice
    Log("DEBUG", "Attempting to save priority: " currentPriority)

    ; Save to INI
    ; IniWrite, %currentPriority%, %iniFile%, PRIORITY, Priority
    Log("INFO", "TrayTip shown: Priority set to " currentPriority)
}


; ─── Log system usage with time interval function. ────────────────────────────────────────────────────────────────────
LogSystemUsageIfDue(cpuLoad, freeMem, totalMem) {
    Global lastResourceLog, logInterval
    timeNow := A_TickCount
    if (timeNow - lastResourceLog >= logInterval) {
        lastResourceLog := timeNow
        Log("DEBUG", "CPU: " . cpuLoad . "% | Free RAM: " . freeMem . " MB / " . totalMem . " MB")
    }
}


; ─── Update CPU status function. ──────────────────────────────────────────────────────────────────────────────────────
UpdateCPUMem() {
    try {
        ComObjError(false)
        objWMIService := ComObjGet("winmgmts:\\.\root\cimv2")
        colCompSys := objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
        for obj in colCompSys {
            totalMem := Round(obj.TotalVisibleMemorySize / 1024, 1)
            freeMem := Round(obj.FreePhysicalMemory / 1024, 1)
        }

        colProc := objWMIService.ExecQuery("Select * from Win32_Processor")
        for objItem in colProc {
            cpuLoad := objItem.LoadPercentage
        }

        SB_SetText(" CPU: " . cpuLoad . "% | Free RAM: " . freeMem . " MB / " . totalMem . " MB")

        Global lastResourceLog := 0  ; Global variable to track last log time
        Global logInterval := logInterval   ; 5 seconds in milliseconds

        LogSystemUsageIfDue(cpuLoad, freeMem, totalMem)

    } catch e {
        SB_SetText("Error fetching CPU/memory: " . e.Message, 2)
    }
}


; ─── Kill RPCS3 process with escape button function. ──────────────────────────────────────────────────────────────────
Esc::
    if (!muteSound) {
        wav := "%A_Temp%\\RPCL3_GAME_OVER.wav"
        if FileExist(wav)
            SoundPlay, %wav%
    }

    Process, Exist, rpcs3.exe
    if (ErrorLevel) {
        CustomTrayTip("ESC pressed. Killing RPCS3 processes.", 2)
        Log("WARN", "ESC pressed. Killing all RPCS3 processes.")
        SB_SetText("ESC pressed. Killed all RPCS3 processes.", 2)
        KillAllProcessesEsc()
    } else {
        CustomTrayTip("No RPCS3 processes found.", 1)
        Log("INFO", "Pressed escape key but no RPCS3 processes found.")
        SB_SetText("No RPCS3 processes found.", 2)
    }
return


KillAllProcessesEsc() {
    RunWait, taskkill /im rpcs3.exe /F,, Hide
    RunWait, taskkill /im powershell.exe /F,, Hide
    ;RunWait, taskkill /im autohotkey.exe /F,, Hide
    Log("INFO", "ESC pressed. Killing all RPCS3 processes.")
    SB_SetText("RPCS3 processes killed.", 2)
}


; ─── RPCS3 refresh path function. ─────────────────────────────────────────────────────────────────────────────────────
RefreshRPCS3Path() {
    global rpcs3Path
    global iniFile

    IniRead, path, %iniFile%, RPCS3, Path
    path := Trim(path, "`" " ")

if (path = "" || !FileExist(path) || SubStr(path, -3) != ".exe") {
MsgBox, 48, Path, Invalid path in INI file. Please select rpcs3.exe manually.

FileSelectFile, userPath, 3, , Select RPCS3 Executable, Executable (*.exe)
if (userPath = "") {
MsgBox, 48, Cancelled, No file selected. Path unchanged.
return
}

userPath := Trim(userPath, "`" " ")
        IniWrite, %userPath%, %iniFile%, RPCS3, Path
        rpcs3Path := userPath
        Log("INFO", "User manually selected Path: " . userPath)
        MsgBox, 64, Path Updated, Path successfully updated to:`n%userPath%
        return
    }

    rpcs3Path := path
    Log("INFO", "Path refreshed: " . path)
    CustomTrayTip("Path refreshed: " . path, 1)
    SB_SetText("PATH: " . path, 2)
}


; ─── RPCS3 check if running function. ─────────────────────────────────────────────────────────────────────────────────
GetRPCS3WindowID(ByRef hwnd) {
    WinGet, hwnd, ID, ahk_exe rpcs3.exe
    if !hwnd {
        MsgBox, rpcs3.exe is not running.
        return false
    }
    return true
}


; ─── Process exists. ──────────────────────────────────────────────────────────────────────────────────────────────────
ProcessExist(name) {
    Process, Exist, %name%
    return ErrorLevel
}


; ─── Run RPCS3 standalone function. ───────────────────────────────────────────────────────────────────────────────────
RunRPCS3:
    Global iniFile
    if (!FileExist(IniFile)) {
        SplitPath, IniFile, iniFileName
        CustomTrayTip("Missing " . IniFile . " Set RPCS3 Path first.", 3)
        SB_SetText("Missing " . IniFile . " Set RPCS3 Path first.", 2)
        Return
    }

    SB_SetText("Reading from: " . IniFile, 3)

    IniRead, rpcs3Path, %IniFile%, RPCS3, Path
    if (rpcs3Path != "") {
        Global rpcs3Exe
        SplitPath, rpcs3Path, rpcs3Exe
    }
    SB_SetText("Path read: " . rpcs3Path, 3)

    if (ErrorLevel) {
        CustomTrayTip("Could not read path from " . IniFile, 3)
        SB_SetText("Could not read the path from " . IniFile, 3)
        Log("ERROR", "Could not read the path from section [RPCS3] in`n" . IniFile)
        Return
    }

    if !FileExist(rpcs3Path) {
        CustomTrayTip("File not found: " . rpcs3Path, 3)
        SB_SetText("File not found: " . rpcs3Path, 3)
        Log("ERROR", "The file does not exist:`n" . rpcs3Path)
    Return
    }

    ; Extract the EXE name only
    SplitPath, rpcs3Path, rpcs3Exe

    ; Kill any existing RPCS3 process by exe name
    RunWait, taskkill /im %rpcs3Exe% /F,, Hide
    Sleep, 1000

    ; Launch RPCS3
    Run, %rpcs3Path%

    Sleep, 2000
    Process, Exist, %rpcs3Exe%
    if (!ErrorLevel)
    {
    MsgBox, 16, Error, Failed to launch RPCS3:`n%rpcs3Path%
    Log("ERROR", "RPCS3 failed to launch.")
    SB_SetText("ERROR: RPCS3 did not launch.", 2)
    CustomTrayTip("ERROR: RPCS3 did not launch!", 3)
    return
    }

    if (!muteSound) {
        wav := "%A_Temp%\\RPCL3_GOOD_MORNING.wav"
        if FileExist(wav)
            SoundPlay, %wav%)
    }

    Log("INFO", "Game Started.")
    SB_SetText("Good Morning! Game Started.", 2)
    CustomTrayTip("Good Morning! Game Started.", 1)
    UpdateStatusBar("Good Morning! Game Started.", 3)
Return


; ─── Custom msgbox. ───────────────────────────────────────────────────────────────────────────────────────────────────
ShowCustomMsgBox(title, text, x := "", y := "") {
    Gui, MsgBoxGui:New, +AlwaysOnTop +ToolWindow, %title%
    Gui, MsgBoxGui:Add, Text,, %text%
    Gui, MsgBoxGui:Add, Button, gCloseCustomMsgBox Default, OK

    if (x != "" && y != "")
        Gui, MsgBoxGui:Show, x%x% y%y% AutoSize
    else
        Gui, MsgBoxGui:Show, AutoSize Center
}

CloseCustomMsgBox:
    Gui, MsgBoxGui:Destroy
return


; ─── Raw ini valuer. ──────────────────────────────────────────────────────────────────────────────────────────────────
GetIniValueRaw(file, section, key) {
    sectionFound := false
    Loop, Read, %file%
    {
        line := A_LoopReadLine
        if (RegExMatch(line, "^\s*\[" . section . "\]\s*$")) {
            sectionFound := true
            continue
        }
        if (sectionFound && RegExMatch(line, "^\s*\[.*\]\s*$")) {
            break
        }
        if (sectionFound && RegExMatch(line, "^\s*" . key . "\s*=\s*(.*)$", m)) {
            return m1
        }
    }
    return ""
}


; ─── Log function. ────────────────────────────────────────────────────────────────────────────────────────────────────
Log(level, msg) {
Global logFile
    static needsRotation := true
    static inLog := false

    if (inLog)
        return

    inLog := true

    if (needsRotation && FileExist( logfile)) {
        FileGetSize, logSize, %logfile%
        if (logSize > 1024000) {  ;>1MB
            FormatTime, timestamp,, yyyyMMdd_HHmmss
            FileMove, %logfile%, %A_ScriptDir%\rpcl3_%timestamp%.log
        }
        needsRotation := false
    }

    try {
        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        logEntry := "[" timestamp "] [" level "] " msg "`n"
        FileAppend, %logEntry%, %logfile%
    }
    catch e {
        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        FileAppend, [%timestamp%] [MAIN-LOG-FAILED] %e%`n, %fallbackLog%
        FileAppend, %logEntry%, %fallbackLog%
        SB_SetText("LOG ERROR: Check fallback.log.", 2)
    }

    inLog := false
}


; ─── rotate logs function. ────────────────────────────────────────────────────────────────────────────────────────────
RotateFfmpegLog(maxLogs = "", maxSize = "") {
    if (maxLogs = "")
        maxLogs := 5
    if (maxSize = "")
        maxSize := 1024 * 1024  ; 1 MB

    logDir := A_ScriptDir
    logFile := logDir . "\rpcl3_ffmpeg.log"

    ; Step 1: Rotate if file is too big
    if FileExist(logFile) {
        FileGetSize, logSize, %logFile%
        if (logSize > maxSize) {
            FormatTime, timestamp,, yyyyMMdd_HHmmss
            FileMove, %logFile%, %logDir%\rpcl3_ffmpeg_%timestamp%.log
        }
    }

    ; Step 2: Delete old logs if more than maxLogs
    logPattern := logDir . "\rpcl3_ffmpeg_*.log"
    logs := []

    Loop, Files, %logPattern%, F
        logs.push(A_LoopFileFullPath)

    if (logs.MaxIndex() > maxLogs) {
        SortLogsByDate(logs)
        Loop, % logs.MaxIndex() - maxLogs
            FileDelete, % logs[A_Index]
    }
}

SortLogsByDate(ByRef arr) {
    Loop, % arr.MaxIndex()
        Loop, % arr.MaxIndex() - A_Index
            if (FileExist(arr[A_Index]) && FileExist(arr[A_Index + 1])) {
                FileGetTime, time1, % arr[A_Index], M
                FileGetTime, time2, % arr[A_Index + 1], M
                if (time1 > time2) {
                    temp := arr[A_Index]
                    arr[A_Index] := arr[A_Index + 1]
                    arr[A_Index + 1] := temp
                }
            }
}


; ─── Custom tray tip function ─────────────────────────────────────────────────────────────────────────────────────────
CustomTrayTip(Text, Icon := 1) {
    ; Parameters:
    ; Text  - Message to display
    ; Icon  - 0=None, 1=Info, 2=Warning, 3=Error (default=1)
    static Title := "RPCL3 Process Control"
    ; Validate icon input (clamp to 0-3 range)
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    ; 16 = No sound (bitwise OR with icon value)
    TrayTip, %Title%, %Text%, , % Icon|16
}


; ─── Show GUI. ────────────────────────────────────────────────────────────────────────────────────────────────────────
ShowGui:
    Gui, Show
    SB_SetText("RPCS3 Priority Control Launcher 3 GUI Shown.", 2)
return

CreateGui:
    Gui, New
    Gui, Add, Text,, The GUI was Refreshed, Right Click in the Tray Bar to Reload.
    Gui, Show
Return

ExitScript:
    Log("INFO", "Exiting script via tray menu.")
    ExitApp
return

RefreshGui:
    Gui, Destroy
    Gosub, CreateGui
return


GuiClose:
    ExitApp
return
