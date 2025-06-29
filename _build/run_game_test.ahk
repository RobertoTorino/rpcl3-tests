#Include %A_ScriptDir%\tools\SQLiteDB.ahk
#Include %A_ScriptDir%\tools\Gdip.ahk
#SingleInstance force
#Persistent
#NoEnv
;#Warn
SendMode Input
DetectHiddenWindows On
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
SetTitleMatchMode, 2

lastStatus := ""   ; tracks the last known Online/Offline state
SetTimer, CheckInternetStatus, 3000  ; check every 3 seconds
online := true

; ─── needed for rpcs3 path. ────────────────────────────────────────────────────────────────────
TrimQuotesAndSpaces(str)
{
    str := Trim(str) ; trim spaces first

    ; Remove leading double quote
    while (SubStr(str, 1, 1) = """")
        str := SubStr(str, 2)

    ; Remove trailing double quote
    while (SubStr(str, 0) = """")
        str := SubStr(str, 1, StrLen(str) - 1)

    return str
}


; ─── global config variables. ────────────────────────────────────────────────────────────────────
baseDir             := A_ScriptDir
rpcs3Path           := GetRPCS3Path()
iniFile             := A_ScriptDir  . "\rpcl3.ini"
logFile             := A_ScriptDir  . "\rpcl3.log"
fallbackLog         := A_ScriptDir  . "\rpcl3_fallback.log"
lastPlayed          := ""
rpcs3Exe            := A_ScriptDir  . "\rpcs3.exe"
global muteSound    := 0

IniRead, muteSound, %iniFile%, MUTE_SOUND, Mute, 0

; ─── test sqlite database. ────────────────────────────────────────────────────────────────────
db := new SQLiteDB()
if !db.OpenDB(A_ScriptDir . "\games.db") {
    err := db.ErrorMsg
    MsgBox, 16, DB Error, Failed to open DB.`n%err%
    ExitApp
}


; ─── read rpcs3 path and extract executable name if found. ────────────────────────────────────────────────────────────
IniRead, rpcs3Path, %iniFile%, RPCS3, Path
if (rpcs3Path != "") {
    global rpcs3Exe
    SplitPath, rpcs3Path, rpcs3Exe
}


; ─── load last played game id and title with safe defaultS. ────────────────────────────────────────────────────────────
IniRead, lastGameID, %iniFile%, LAST_PLAYED, GameID, UnknownID
IniRead, lastGameTitle, %iniFile%, LAST_PLAYED, GameTitle, Unknown Title


; ─── runs a command and returns the output example: "rpcs3.exe --version", call it with "getcommandoutput". ───────────
Log("DEBUG", "Command to run:`n" . helpCommand)

GetCommandOutput(cmd) {
    tmpFile := A_Temp "\cmd_output.txt"
    ; Wrap the entire cmd in double-quotes to preserve quoted paths inside
    fullCmd := ComSpec . " /c """ . cmd . " > """ . tmpFile . """ 2>&1"""
    Log("DEBUG", "Running full command: " . fullCmd)
    RunWait, %fullCmd%,, Hide
    FileRead, output, %tmpFile%
    FileDelete, %tmpFile%
    Log("DEBUG", "Raw output from cmd: " . output)
    return Trim(output)
}


; ─── set as admin. ────────────────────────────────────────────────────────────
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


; ───────── START GUI. ────────────────────────────────────────────────────────────────────────
;title := "RPCS3 Priority Control Launcher 3 - " . Chr(169) . " " . A_YYYY . " - Philip"
;online := IsInternetAvailable()
;statusText := online ? "Online" : "Offline"
;title := "RPCS3 Priority Control Launcher 3 - " . Chr(169) . " " . A_YYYY . " - Philip [" . statusText . "]"


Gui, Show, w450 h180, %title%
Gui, +LastFound +OwnDialogs +ToolWindow
Gui, Font, s10 q5, Segoe UI
Gui, Margin, 15, 15
GuiHwnd := WinExist()


Gui, Add, Button, vRunGame gRunGame    x10 y10 w100 h60 +Center +0x200, Run Game
Gui, Add, Button, gRunRPCS3           x120 y10 w100 h60 +Center +0x200, Run RPCS3
Gui, Add, Button, gExitRPCS3          x230 y10 w100 h60 +Center +0x200, Exit RPCS3
Gui, Add, Button, gExitRPCL3          x340 y10 w100 h60 +Center +0x200, Exit RPCL3

Gui, Add, Button, gRefreshPath          x10 y80 w100 h60 +Center +0x200, Refresh Path
Gui, Add, Button, gSetRpcs3Path         x120 y80 w100 h60 +Center +0x200, Set Path
Gui, Add, Button, gSetEbootPath         x230 y80 w100 h60 +Center +0x200, Select Eboot
Gui, Add, Button, gToggleMute vMuteBtn  x340 y80 w100 h60 +Center +0x200,  % (muteSound ? "Unmute O" : "Mute X")

; ─── Status bar, 1 is used for RPCS3 status use 2 and 3. ────────────────────────────────────────────────────────────
Gui, Add, Progress,                   x0 y158 w450 h1 0x10 Backgroundc000000 Disabled
Gui, Add, Text, vCurrentPriority      x0 y160 w10,
Gui, Add, Text, vVariableText2       x10 y160 w155, [GAME_ID]
Gui, Add, Text, vVariableText3      x170 y160 w280, [GAME_TITLE]

; ─── update gui controls for last game in the custom statusbar. ──────────────────────────────────────────────
idText := "LAST_PLAYED: " . (lastGameID != "" ? lastGameID : "NoData")
GuiControl,, VariableText2, %idText%

Log("DEBUG", "Updated VariableText2 with: " . idText)

titleText := (lastGameTitle != "" ? lastGameTitle : "NoData")
GuiControl,, VariableText3, %titleText%

Log("DEBUG", "Updated VariableText3 with: " . titleText)


; ─── record timestamp of last update. ───────────────────────────────────
FormatTime, timeStamp, , yyyy-MM-dd HH:mm:ss
Log("DEBUG", "Writing Timestamp " . timeStamp . " to " . iniFile)
IniWrite, %timeStamp%, %iniFile%, LAST_UPDATE, LastUpdated


; ─── this return ends all updates to the gui. ───────────────────────────────────
return
; ─── END GUI. ───────────────────────────────────────────────────────────────────


; ───  check internet status. ──────────────────────────────────────────────
CheckInternetStatus:
    ;--- get current status
    online := IsInternetAvailable()
    statusText := online ? "Online" : "Offline"

    ;--- only update GUI if the status changed
    if (statusText != lastStatus) {
        title := "RPCS3 Priority Control Launcher 3 - " . Chr(169) . " " . A_YYYY . " - Philip - " . statusText
        Gui, Show, NA, %title%   ; NA = No Activate (won’t steal focus)
        lastStatus := statusText
        Log("INFO", "Internet status changed: " . statusText)
    }
return

IsInternetAvailable() {
    url := "https://jsonplaceholder.typicode.com/posts"
    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    try {
        http.Open("GET", url, false)
        http.Send()
        return (http.Status >= 200 && http.Status < 300)
    } catch {
        return false
    }
}


; ─── refresh path. ───────────────────────────────────────────────────────────────────
RefreshRPCS3Path()


; ─── refresh path to gameloader pcs3.exe. ────────────────────────────────────────────────────────────
RefreshPath:
    RefreshRPCS3Path()
    CustomTrayTip("Path refreshed: " rpcs3Path, 1)
    SB_SetText("PATH: " . rpcs3Path, 2)
    Log("DEBUG", "Path refreshed: " . rpcs3Path)
return


; ─── Set path to rpcs3.exe function. ────────────────────────────────────────────────────────────────────
SetRpcs3Path:
    global rpcs3Path, rpcs3Exe
    FileSelectFile, selectedPath,, , Select RPCS3 executable, Executable Files (*.exe)
    if (selectedPath != "" && FileExist(selectedPath)) {
        SaveRPCS3Path(selectedPath)

        ;Also update global rpcs3Path and rpcs3Exe
        ;global rpcs3Path, rpcs3Exe
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


; ─── Get path to rpcs3.exe function. ────────────────────────────────────────────────────────────────────
GetRPCS3Path() {
    static iniFile := A_ScriptDir . "\rpcl3.ini"
    local path

    if !FileExist(iniFile) {
        CustomTrayTip("Missing rpcl3.ini.", 3)
        SB_SetText("ERROR: Missing rpcl3.ini when calling GetRPCS3Path.", 2)
        Log("ERROR", "Missing rpcl3.ini when calling GetRPCS3Path()")
        return ""
    }

    IniRead, path, %iniFile%, RPCS3, Path
    if (ErrorLevel) {
        CustomTrayTip("Could not read [RPCS3] path from rpcl3.ini.", 3)
        SB_SetText("ERROR: Could not read [RPCS3] path from rpcl3.ini.", 2)
        Log("ERROR", "Could not read [RPCS3] path from rpcl3.ini")
        return ""
    }

    path := Trim(path, "`" " ")  ; trim surrounding quotes and spaces

    Log("DEBUG", "GetRPCS3Path, Path is: " . path)

    if (path != "" && FileExist(path) && SubStr(path, -3) = ".exe")
        return path

        CustomTrayTip("Could not read [RPCS3] path from: " . path, 3)
        SB_SetText("ERROR: Invalid or non-existent path in rpcl3.ini: " . path, 2)
        Log("ERROR", "Invalid or non-existent path in rpcl3.ini: " . path)
        return ""
    }

    SaveRPCS3Path(path) {
        static iniFile := A_ScriptDir . "\rpcl3.ini"
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


; ─── RPCS3 path function. ────────────────────────────────────────────────────────────────────
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


SetEbootPath:
{
    global iniFile
    dbPath := A_ScriptDir . "\games.db"    ; Adjust if needed

    ; 1  Ask user for an EBOOT.BIN
    FileSelectFile, selectedEboot, 3,, Select EBOOT.BIN, EBOOT.BIN
    if (ErrorLevel || !selectedEboot)
        return    ; user cancelled

    ; 2  Verify the filename is literally EBOOT.BIN
    SplitPath, selectedEboot, fileName
    if (fileName != "EBOOT.BIN") {
        MsgBox, 48, Invalid, Please select a valid EBOOT.BIN file.
        return
    }

    ; 3  Extract Game ID (handles both [BLUS30001] and dev_hdd0 style)
    gameID := ExtractGameID(selectedEboot)
    if (gameID = "") {
        MsgBox, 16, Error, Could not extract Game ID from:`n%selectedEboot%
        Log("ERROR", "Could not extract GameID from path: " . selectedEboot)
        return
    }
    Log("DEBUG", "Extracted GameID: " . gameID)

    ; 4  Open SQLite database and query GameTitle
    #Include %A_ScriptDir%\tools\SQLiteDB.ahk
    db := new SQLiteDB
    if !db.OpenDB(dbPath) {
        MsgBox, 16, Error, Failed to open database: %dbPath%
        return
    }

    gameTitle := "Unknown Title"
    if db.Query("SELECT GameTitle FROM games WHERE GameId = ?", gameID) {
        if db.NextRow()
            gameTitle := db.GetValue("GameTitle")
    }
    db.CloseDB()

    ; 5  Persist selected EBOOT and basic info
    IniWrite, %selectedEboot%, %iniFile%, RUN_GAME, EbootBinPath
    IniWrite, %gameID%,       %iniFile%, LAST_PLAYED, GameID
    IniWrite, %gameTitle%,    %iniFile%, LAST_PLAYED, GameTitle
    Log("INFO", "Saved EBOOT & game info: " . gameID . " - " . gameTitle)
}
return



; ─── Extract game id function. ────────────────────────────────────────────────────────────────────
ExtractGameID(path) {
    ; 1. Match in brackets like: [BLUS30001]
    if (RegExMatch(path, "\[([A-Z]{4,5}\d{4,5})\]", m)) {
        Log("DEBUG", "Regex [bracketed] match: " . m1)
        return m1
    }

    ; 2. Match folder inside /game/ with valid GameID format
    if (RegExMatch(path, "(?:\\|\/)game(?:\\|\/)([A-Z0-9]{4,5}\d{3,5})(?=\\|\/)", m)) {
        Log("DEBUG", "Regex [game folder] match: " . m1)
        return m1
    }

    ; 3. Fallback to directory above EBOOT.BIN
    SplitPath, path, , parentDir
    SplitPath, parentDir, , , , lastFolder
    if (RegExMatch(lastFolder, "^[A-Z0-9]{4,5}\d{3,5}$")) {
        Log("DEBUG", "Regex [parent folder] match: " . lastFolder)
        return lastFolder
    }

    Log("DEBUG", "ExtractGameID fallback failed on: " . path)
    return "" ; Failed to extract
}


; ─── Close RPCL3. ────────────────────────────────────────────────────────────────────
ExitRPCL3:
if (!muteSound)
    SoundPlay, %A_ScriptDir%\media\rpcl3_game_over.wav, 1
    ; SoundPlay, %A_ScriptDir%\media\rpcl3_game_over.wav
    Log("INFO", "Exiting AHK using the Exit button.")
    ExitApp
return


; ─── Run RPCS3 standalone function. ────────────────────────────────────────────────────────────────────
RunRPCS3:
    global iniFile
    if (!FileExist(IniFile)) {
        SplitPath, IniFile, iniFileName
        CustomTrayTip("Missing " . IniFile . " Set RPCS3 Path first.", 3)
        SB_SetText("Missing " . IniFile . " Set RPCS3 Path first.", 2)
        Return
    }

    SB_SetText("Reading from: " . IniFile, 3)

    IniRead, rpcs3Path, %IniFile%, RPCS3, Path
    if (rpcs3Path != "") {
        global rpcs3Exe
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

    ;Extract the EXE name only
    SplitPath, rpcs3Path, rpcs3Exe

    ;Kill any existing RPCS3 process by exe name
    RunWait, taskkill /im %rpcs3Exe% /F,, Hide
    Sleep, 1000

    ;Launch RPCS3
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
    if (!muteSound)
    SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav, 1
    Log("INFO", "Game Started.")
    SB_SetText("Good Morning! Game Started.", 2)
    CustomTrayTip("Good Morning! Game Started.", 1)
Return


RunGame:
    global iniFile, rpcs3Exe

    ; Kill any existing RPCS3 processes
    RunWait, taskkill /im %rpcs3Exe% /F,, Hide
    Sleep, 1000

    ; Get RunCommand from INI
    IniRead, runCommand, %iniFile%, RUN_GAME, RunCommand
    if (runCommand = "ERROR" or runCommand = "") {
        MsgBox, 16, Error, Failed to read RunCommand from INI.
        return
    }
    Log("DEBUG", "Read from INI: " . runCommand)

    ; Wrap the entire command in quotes for cmd.exe safety
    fullRunCmd := ComSpec . " /c " . Chr(34) . runCommand . Chr(34)

    Log("DEBUG", "Running command: " . fullRunCmd)

    ; Actually run the command
    Run, %fullRunCmd%, , , newPID

    ; Check if RPCS3 started
    Sleep, 2000
    Process, Exist, %rpcs3Exe%
    if (!ErrorLevel) {
        MsgBox, 16, Error, Failed to launch RPCS3:`n%runCommand%
        Log("ERROR", "RPCS3 failed to launch.")
        SB_SetText("ERROR: RPCS3 did not launch.", 2)
        return
    }
    if (!muteSound)
    SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav, 1
    Log("DEBUG", "Started RPCS3 with command from INI.")
    SB_SetText("Good Morning! Your Game Started.", 2)
return


; ─── View configuration function. ────────────────────────────────────────────────────────────────────
ViewConfigLabel:
    global iniFile
    Run, notepad.exe "%iniFile%"
    SplitPath, iniFile, iniFileName
    Log("DEBUG", "Opened: " iniFile)
return


; ─── Kill RPCS3 process with escape button function. ────────────────────────────────────────────────────────────────────
Esc::
    if (!muteSound)
        SoundPlay, %A_ScriptDir%\media\rpcl3_game_over.wav, 1

    Process, Exist, rpcs3.exe
    if (ErrorLevel) {
        ; CustomTrayTip("ESC pressed. Killing RPCS3 processes.", 2)
        Log("WARN", "ESC pressed. Killing all RPCS3 processes.")
        SB_SetText("ESC pressed. Killed all RPCS3 processes.", 2)
        KillAllProcesses1()
    } else {
        ; CustomTrayTip("No RPCS3 processes found.", 1)
        Log("INFO", "Pressed escape key but no RPCS3 processes found.")
        SB_SetText("No RPCS3 processes found.", 2)
    }
return


KillAllProcesses1() {
    RunWait, taskkill /im rpcs3.exe /F,, Hide
    RunWait, taskkill /im powershell.exe /F,, Hide
    ;RunWait, taskkill /im autohotkey.exe /F,, Hide
    Log("INFO", "ESC pressed. Killing all RPCS3 processes.")
    SB_SetText("RPCS3 processes killed.", 2)
}


; ─── Custom tray tip function ────────────────────────────────────────────────────────────────────
CustomTrayTip(Text, Icon := 1) {
    ; Parameters:
    ; Text  - Message to display
    ; Icon  - 0=None, 1=Info, 2=Warning, 3=Error (default=1)
    static Title := "RPCL3 Launcher"
    ; Validate icon input (clamp to 0-3 range)
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    ; 16 = No sound (bitwise OR with icon value)
    TrayTip, %Title%, %Text%, , % Icon|16
}

KillAllProcesses(pid := "") {
    if (pid) {
        Run, "%A_ScriptFullPath%" activate
        RunWait, taskkill /im %rpcs3Exe% /F,, Hide
        RunWait, taskkill /im powershell.exe /F,, Hide
        RunWait, %ComSpec% /c taskkill /PID %pid% /F, , Hide
        ; Optional: Kill any potential child processes
        RunWait, %ComSpec% /c taskkill /im powershell.exe /F, , Hide
        Log("INFO", "KillAllProcesses: Killed PID " . pid)
    } else {
        Log("WARN", "KillAllProcesses: No PID provided.")
    }
}


; ─── RPCS3 refresh path function. ────────────────────────────────────────────────────────────────────
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


; ─── RPCS3 check if running function. ────────────────────────────────────────────────────────────────────
GetRPCS3WindowID(ByRef hwnd) {
    WinGet, hwnd, ID, ahk_exe rpcs3.exe
    if !hwnd {
        MsgBox, rpcs3.exe is not running.
        return false
    }
    return true
}


; ─── Log function. ────────────────────────────────────────────────────────────────────
Log(level, msg) {
global logFile
    static needsRotation := true
    static inLog := false  ;recursion guard

    if (inLog)
        return  ;Already logging, avoid recursion

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

        ;User notifications
        SB_SetText("LOG ERROR: Check fallback.log.", 2)
    }

    inLog := false
}


; ─── Process exists. ────────────────────────────────────────────────────────────────────
ProcessExist(name) {
    Process, Exist, %name%
    return ErrorLevel
}


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
            break  ; Next section started, key not found
        }
        if (sectionFound && RegExMatch(line, "^\s*" . key . "\s*=\s*(.*)$", m)) {
            return m1
        }
    }
    return ""
}


; ─── Kill RPCS3 with button function. ────────────────────────────────────────────────────────────────────
ExitRPCS3:
    if (!muteSound)
        SoundPlay, %A_ScriptDir%\media\rpcl3_game_over.wav, 1

    ; Confirm what we're checking for
    Log("DEBUG", "Checking for process: " . rpcs3Exe)
    Process, Exist, %rpcs3Exe%

    pid := ErrorLevel
    if (pid) {
        KillAllProcesses(pid)  ; Pass PID to function
        ; CustomTrayTip("Killed all RPCS3 processes.", 2)
        Log("INFO", "Killed all RPCS3 processes (PID: " . pid . ")")
        SB_SetText("Killed all RPCS3 processes.", 2)
    } else {
        ; CustomTrayTip("No RPCS3 processes running.", 2)
        Log("INFO", "No RPCS3 processes running.")
        SB_SetText("No RPCS3 processes running", 2)
    }

    Gui, Show ; Show or hide GUI but keep script alive
    Menu, Tray, Show  ; Ensure tray icon stays visible
return


ToggleMute:
    muteSound := !muteSound
    IniWrite, %muteSound%, %iniFile%, MUTE_SOUND, Mute
    GuiControl,, MuteBtn, % (muteSound ? "Unmute O" : "Mute X")
    SoundBeep, 750, 150  ; Optional feedback
return


GuiClose:
    db.CloseDB()
    ExitApp
return
