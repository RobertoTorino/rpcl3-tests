;YouTube: @game_play267
;Twitch: RR_357000
;X:@relliK_2048
;Discord:
;Launcher for RPCS3

#Include %A_ScriptDir%\tools\JSON.ahk
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

; ─── globals. ────────────────────────────────────────────────────────────────────
OnExit("SaveSettings")
logInterval := 120000
lastResourceLog := 0

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

;; ─── try to discover rpcs3.exe in rpcl3_games_db.json (one pass, fist match) returns "" ───────────────────────────────
;DiscoverRPCS3FromJSON()
;{
;    local jsonFile := A_ScriptDir "\rpcl3_games_db.json"
;
;    if !FileExist(jsonFile)
;        return ""
;
;    FileRead, raw, %jsonFile%
;    if ErrorLevel
;        return ""
;
;    db := JSON.Load(raw)
;    for _, game in db
;    {
;        loader := TrimQuotesAndSpaces(game.Properties.Loader)
;        if (loader = "")
;            continue
;
;        ; If Loader is just "rpcs3.exe", make it absolute (= script dir)
;        if !RegExMatch(loader, "^[A-Z]:\\|^\\\\")
;            loader := A_ScriptDir "\" loader
;
;        if FileExist(loader)
;            return loader
;    }
;    return ""
;}

; ─── global variables. ────────────────────────────────────────────────────────────────────
global RPCS3_UpdateAPI      := "https://update.rpcs3.net/?api=v2"
global RPCS3_LatestAPI      := "https://api.github.com/repos/RPCS3/rpcs3-binaries-win/releases/latest"
gDestinationHomeDiscordURL  := "https://discord.com/channels/621722473695805450/@home"
RPCS3_YouTubeURL            := "https://www.youtube.com/c/RPCS3_emu/videos"
RPCS3_DestinationHomeURL    := "https://web.destinationhome.live/"
updateURL                   := "https://www.playstation.com/en-us/support/hardware/ps3/system-software/#:~:text=Do%20not%20perform%20updates%20using,install%20the%20official%20update%20data."
rpcs3URL                    := "https://rpcs3.net/download"
grpcs3ForumURL              := "https://forums.rpcs3.net/"
rpcs3WiKiURL                := "https://wiki.rpcs3.net/index.php?title=Main_Page"
discordURL                  := "https://discord.com/invite/RPCS3"
vbCableDownloadURL          := "https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip"
downloadNircmdURL           := "https://www.nirsoft.net/utils/nircmd.zip"
RPCL3_YouTubeURL            := "https://www.youtube.com/@game_play267"
global audioPrepared        := false


; ─── global config variables. ────────────────────────────────────────────────────────────────────
baseDir         := A_ScriptDir
rpcs3Path       := GetRPCS3Path()
iniFile         := A_ScriptDir  . "\rpcl3.ini"
logFile         := A_ScriptDir  . "\rpcl3.log"
fallbackLog     := A_ScriptDir  . "\rpcl3_fallback.log"
noImage         := A_ScriptDir  . "\media\rpcl3_no_image_found.png"
FFmpegFolder    := A_ScriptDir  . "\tools"
FFmpegZip       := A_ScriptDir  . "\ffmpeg-release-essentials.zip"
jsonFile        := A_ScriptDir  . "\rpcl3_games_db.json"
ffmpegExe       := "tools\ffmpeg.exe"
recording       := false
ffmpegPID       := 0
lastPlayed      := ""
ffplayPID       := 0
rpcs3Exe        := A_ScriptDir  . "\rpcs3.exe"

; ─── save screen size. ────────────────────────────────────────────────────────────────────
IniRead, SavedSize, %iniFile%, SIZE_SETTINGS, SizeChoice, 1920x1080
SizeChoice := SavedSize
selectedControl := sizeToControl[SavedSize]
for key, val in sizeToControl {
    label := (val = selectedControl) ? "[" . key . "]" : key
    GuiControl,, %val%, %label%
}
DefaultSize := "1920x1080"
DefaultNudge := 20

; ─── load window settings from ini. ────────────────────────────────────────────────────────────────────
IniRead, SizeChoice, %iniFile%, SIZE_SETTINGS, SizeChoice, %DefaultSize%
IniRead, NudgeStep, %iniFile%, NUDGE_SETTINGS, NudgeStep, %DefaultNudge%

; ─── set nudge step field. ────────────────────────────────────────────────────────────────────
GuiControl,, NudgeStep, %NudgeStep%

; ─── highlight selected nudge button if visible. ────────────────────────────────────────────────────────────────────
Loop, 6 {
    step := 10 + (A_Index * 5)  ; 15, 20, 25, ...
    name := "Btn" . step
    label := (step = NudgeStep) ? "[" . step . "]" : step
    GuiControl,, %name%, %label%
}

; ─── conditionally set default priority if it's not already set. ─────────────────────────────────────────────────────
IniRead, priorityValue, %iniFile%, PRIORITY, Priority
if (priorityValue = "")
    IniWrite, Normal, %iniFile%, PRIORITY, Priority

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

;GetCommandOutput(cmd) {
;    tmpFile := A_Temp "\cmd_output.txt"
;    fullCmd := ComSpec . " /c " . cmd . " > `"" . tmpFile . "`" 2>&1"
;    Log("DEBUG", "Running full command: " . fullCmd)
;    RunWait, %fullCmd%,, Hide
;    FileRead, output, %tmpFile%
;    FileDelete, %tmpFile%
;    Log("DEBUG", "Raw output from cmd: " . output)
;    return Trim(output)
;}

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

; ─── system info. ────────────────────────────────────────────────────────────
monitorIndex := 1  ; Change this to 2 for your second monitor

SysGet, MonitorCount, MonitorCount
if (monitorIndex > MonitorCount) {
    MsgBox, Invalid monitor index: %monitorIndex%
    ExitApp
}

SysGet, monLeft, Monitor, %monitorIndex%
SysGet, monTop, Monitor, %monitorIndex%
SysGet, monRight, Monitor, %monitorIndex%
SysGet, monBottom, Monitor, %monitorIndex%

; ─── Get real screen dimensions. ────────────────────────────────────────────────────────────
SysGet, Monitor, Monitor, %monitorIndex%
monLeft := MonitorLeft
monTop := MonitorTop
monRight := MonitorRight
monBottom := MonitorBottom

monWidth := monRight - monLeft
monHeight := monBottom - monTop

msg := "Monitor Count: " . MonitorCount . "`n`n"
    . "Monitor " . monitorIndex . ":" . "`n"
    . "Left: " . monLeft . "`n"
    . "Top: " . monTop . "`n"
    . "Right: " . monRight . "`n"
    . "Bottom: " . monBottom . "`n"
    . "Width: " . monWidth . "`n"
    . "Height: " . monHeight

Log("DEBUG", msg)

; ───────────────────────────────────────────────────────────────
;Unique window class name
#WinActivateForce
scriptTitle := "RPCS3 Priority Control Launcher 3"
if WinExist("ahk_class AutoHotkey ahk_exe " A_ScriptName) && !A_IsCompiled {
    ;Re-run if script is not compiled
    ExitApp
}

;Try to send a message to existing instance
if A_Args[1] = "activate" {
    PostMessage, 0x5555,,,, ahk_class AutoHotkey
    ExitApp
}

OnMessage(0x5555, "BringToFront")
BringToFront(wParam, lParam, msg, hwnd) {
    Gui, Show
    WinActivate
}

;Log system info on startup
Log("INFO", "RPCS3 Launcher started (elevated)")
Log("INFO", "OS: " A_OSVersion ", Arch: " (A_Is64bitOS ? "64-bit" : "32-bit"))

GetSystemInfo() {
    comp := A_ComputerName
    winVer := GetWindowsVersion()
    arch := (A_Is64bitOS ? "64-bit" : "32-bit")
    screen := A_ScreenWidth "x" A_ScreenHeight
    cpu := GetCPUInfo()
    gpu := GetGPUInfo()
    info .= "`nComputer: " comp
    info .= "`nOS: " winVer
    info .= "`nArchitecture: " arch
    info .= "`nScreen: " screen
    info .= "`nCPU: " cpu
    info .= "`nGPU: " gpu
    return info
}

GetCPUInfo() {
    psCmd := "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"
    return RunPowerShell(psCmd)
}

GetGPUInfo() {
    psCmd := "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"
    return RunPowerShell(psCmd)
}

RunPowerShell(psCmd) {
    tmpFile := A_Temp "\ps_output.txt"
    fullCmd := "powershell -NoProfile -Command """ psCmd """ > """ tmpFile """ 2>&1"
    RunWait, %ComSpec% /c %fullCmd%,, Hide
    FileRead, output, %tmpFile%
    FileDelete, %tmpFile%
    output := Trim(output)
return output
}

GetWindowsVersion() {
    psCmd := "Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber | ForEach-Object { $_.Caption + ' Version ' + $_.Version + ' (Build ' + $_.BuildNumber + ')' }"
    return RunPowerShell(psCmd)
}

; ───────────────────────────────────────────────────────────────
IniRead, gameCount, %iniFile%, GAMES_FOUND, Count, 0

; ───────── START GUI. 🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮
title := "RPCS3 Priority Control Launcher 3 - " . Chr(169) . " " . A_YYYY . " - Philip"
Gui, Show, w1190 h700, %title%
Gui, +LastFound +OwnDialogs +ToolWindow
Gui, Color, 24292F
Gui, Font, cCCCCCC s10 q5, Segoe UI Emoji
Gui, Margin, 15, 15
GuiHwnd := WinExist()

GuiControl,, NudgeStep, %lastNudge%
highlight := "Btn" . lastNudge

; ─── row 1. ────────────────────────────────────────────────────────────
Gui, Font, bold q5
Gui, Add, Text, vPriorityLabel                  x10 y10 w150 h30 cFFCC66 +Center +0x200 BackgroundTrans, SELECT PRIORITY
Gui, Add, DropDownList, vPriorityChoice         x10 y40 w150 r6, Idle|Below Normal|Normal|Above Normal|High|Realtime
LoadSettings()
Gui, Add, Text, gSetPriority                    x10 y70 w150 h30 cFFCC66 +Center +0x200 BackgroundTrans, SET PRIORITY
Gui, Add, Text,                                 x10 y10 w150 h130 Border
Gui, Add, Progress, x10 y100 w150 h10 0x10 Background00FF00 Disabled
Gui, Add, Progress, x10 y115 w150 h10 0x10 BackgroundFFFF00 Disabled
Gui, Add, Progress, x10 y130 w150 h10 0x10 BackgroundFF0000 Disabled

Gui, Add, Picture, vRunGame gRunRPCS3GameLabel  x180  y10 w150 h80  vRPCL2ArcadeIcon, media/rpcl3_run_game.png
Gui, Add, Picture, gRunRPCS3Label              x1030  y10 w150 h80, media/rpcl3_run_rpcs3.png
Gui, Add, Picture, gCloseRpcs3Label              x10 y560 w150 h80, media/rpcl3_exit_rpcs3.png
Gui, Add, Picture, gExitRPCL3Label             x1030 y560 w150 h80, media/rpcl3_exit_rpcl3.png

Gui, Font, bold q5 s10
Gui, Add, Edit, vSearchTerm x350 y10 w150 h30 cBlack +Center +0x200,
Gui, Add, Button, gDoSearch x520 y10 w150 h30 cFF0000 +Center +0x200, Search
Gui, Add, Text, gRefreshPath                    x690 y10 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x1F5D8) " REFRESH PATH"
Gui, Add, Text, gSetRpcs3Path                   x860 y10 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x1F5C1) " SET PATH"

; ─── row 2. ────────────────────────────────────────────────────────────
Gui, Add, Text, gDownloadRPCS3Label             x350 y60 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x2B73) " GET RPCS3"
Gui, Add, Text, gDownloadFirmware               x520 y60 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x2B73) " GET FW 4.92"
Gui, Add, Text, gInstallfirmware                x690 y60 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x21CA) " INSTALL FW"
Gui, Add, Text, gInstallPkg                     x860 y60 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x25F0) " INSTALL PKG"

; ─── row 3. ────────────────────────────────────────────────────────────
Gui, Add, Text, vGameCount gRefreshGameCount    x180 y110 w320 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x1F3AE) . " GAMES IN DB: (click to refresh): " . gameCount
Gui, Add, Text, gTakeScreenshotLabel            x520 y110 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x1F4F8) " SCREENSHOT"
Gui, Add, Text, gPrepareRecordingLabel          x690 y110 w150 h30 cFFCC66 +Center Border BackgroundTrans +0x200, SET AUDIO DEVICE
Gui, Add, Text, gVideoCaptureLabel              x860 y110 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x1F4F9) " RECORD VIDEO"
Gui, Add, Text, gAudioCaptureLabel             x1030 y110 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x1F50A) " RECORD AUDIO"

; ─── row 4. ────────────────────────────────────────────────────────────
Gui, Add, Text, gMoveToMonitor                   x10 y160 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x239A) " MONITOR 1/2"
Gui, Add, Text,                                 x180 y160 w150 h30 cFFCC66 +Center BackgroundTrans +0x200, SCREEN POSITION:
Gui, Add, Text, gNudgeLeft                      x350 y160 w35 h30 cFFCC66 +Center BackgroundTrans Border +0x200, L
Gui, Add, Text, gNudgeRight                     x388 y160 w35 h30 cFFCC66 +Center BackgroundTrans Border +0x200, R
Gui, Add, Text, gNudgeUp                        x427 y160 w35 h30 cFFCC66 +Center BackgroundTrans Border +0x200, U
Gui, Add, Text, gNudgeDown                      x465 y160 w35 h30 cFFCC66 +Center BackgroundTrans Border +0x200, D
Gui, Add, Text,                                 x520 y160 w150 h30 cFFCC66 +Center BackgroundTrans +0x200, NUDGE STEPS: PIXELS
Gui, Add, Text, vBtn5 gSetNudge                 x690 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 5
Gui, Add, Text, vBtn10 gSetNudge                x728 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 10
Gui, Add, Text, vBtn15 gSetNudge                x767 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 15
Gui, Add, Text, vBtn20 gSetNudge                x805 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 20
Gui, Add, Text, vBtn25 gSetNudge                x860 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 25
Gui, Add, Text, vBtn30 gSetNudge                x898 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 30
Gui, Add, Text, vBtn35 gSetNudge                x937 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 35
Gui, Add, Text, vBtn40 gSetNudge                x975 y160 w35 h30 cFFCC66  +Center Border BackgroundTrans +0x200, 40
Gui, Add, Text,                                 x1030 y160 w150 h30 cFFCC66  +Center Border BackgroundTrans +0x200 +0x200,
Gui, Add, Edit, vNudgeStep                      x975 y160 w50 h30 hidden, 20
IniRead, lastNudge, %iniFile%, NUDGE_SETTINGS, NudgeStep, 20

; ─── row 5. ────────────────────────────────────────────────────────────
Gui, Add, Text,                                 x10 y210 w152 h30 cFFCC66 +Center +0x200, CUSTOM SCREEN SIZE:
Gui, Add, Text, vSize800        gSetSizeChoice x180 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 800x600
Gui, Add, Text, vSize1024       gSetSizeChoice x290 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 1024x768
Gui, Add, Text, vSize1280       gSetSizeChoice x400 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 1280x720
Gui, Add, Text, vSize1920       gSetSizeChoice x510 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 1920x1080
Gui, Add, Text, vSize2560       gSetSizeChoice x620 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 2560x1440
Gui, Add, Text, vSizeFull       gSetSizeChoice x750 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, FullScreen
Gui, Add, Text, vSizeWindowed   gSetSizeChoice x860 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Windowed
Gui, Add, Text, vSizeHidden     gSetSizeChoice x970 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Hidden
Gui, Add, Text, gResetDefaults                 x1080 y210 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Reset

; ─── row 6. ────────────────────────────────────────────────────────────
Gui, Add, Text, gDownloadFFMPEGLabel            x10 y260 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, INSTALL FFMPEG
Gui, Add, Text, gAddFFMPEGToPathLabel           x180 y260 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, FFMPEG TO PATH
Gui, Add, Text, gRemoveFFMPEGLabel              x350 y260 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, REMOVE FFMPEG
Gui, Add, Text,                                 x520 y260 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, INSTALL VA CABLE
Gui, Add, Text,                                 x690 y260 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, INSTALL NIRCMD
Gui, Add, Text,                                 x860 y260 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,
Gui, Add, Text,                                x1030 y260 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,

; ─── row 7. ────────────────────────────────────────────────────────────
; Optional preview image
;Gui, Add, Picture, vVideoPreview w300 h170 Border

; ─── row 8. ────────────────────────────────────────────────────────────
Gui, Add, Text, gRpcs3Web                   x10 y310 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F310) " RPCS3 HOME"
Gui, Add, Text, gRpcs3Wiki                  x180 y310 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F310) " RPCS3 WIKI"
Gui, Add, Text, gRpcs3Discord               x350 y310 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F310) " RPCS3 DISCORD"
Gui, Add, Text, gPsHomeWeb                  x520 y310 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F310) " PS HOME"
Gui, Add, Text, RPCS3YouTubeLabel           x690 y310 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F310) " RPCS3 YOUTUBE"
Gui, Add, Text, RPCL3YouTubeLabel           x860 y310 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F310) " RPCL3 YOUTUBE"
Gui, Add, Text,                             x1030 y310 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,

; ─── row 9. ────────────────────────────────────────────────────────────
Gui, Add, Text, gShowVersionLabel            x10 y360 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F6C8) " SHOW VERSION"
Gui, Add, Text, gShowHelpLabel              x180 y360 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x2753) " SHOW HELP"
Gui, Add, Text, gViewLog                    x350 y360 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x1F56E) " VIEW LOGS"
Gui, Add, Text, gClearLog                   x520 y360 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x274C) " CLEAR LOGS"
Gui, Add, Text, gViewConfigLabel            x690 y360 w150 h30 cFFCC66 +Center BackgroundTrans Border +0x200, % Chr(0x26EE) " VIEW CONFIG"
Gui, Add, Text,                             x860 y360 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,
Gui, Add, Text,                             x1030 y360 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,
Gui, Add, Text, gRefreshGui                 x1030 y360 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans +0x200, % Chr(0x1F5D8) " REFRESH GUI"
Gui, Add, Text,                             x10 y410 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,

Gui, Add, Picture, gShowVideoPlayer         x690 y410 w320 h110, media/rpcl3_start_videoplayer.png
Gui, Add, Picture,                          x690 y530 w320 h110, media/rpcl3_start_musicplayer.png

Gui, Font, bold q5 s10
Gui, Add, Text,                              x10 y460 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,
Gui, Add, Text,                              x10 y510 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,
Gui, Add, Text,                              x10 y560 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,
Gui, Add, Text,                             x690 y610 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans,


; ─── last segment. ────────────────────────────────────────────────────────────
Gui, Add, Progress, x10 y399 w1170 h1 0x10 BackgroundcFFCC66 cCCCCCC Disabled
;global noImage
;icon := A_ScriptDir . "\games\Ridge Racer 7 [BLUS30001]\PS3_GAME\ICON0.PNG"
Gui, Add, Picture,  x173 y410 +BackgroundTrans vGameIcon
if (found)
    hbm := LoadPicture(iconPath, "GDI+ h230")
else
hbm := LoadPicture(noImage, "GDI+ h230")
GuiControl,, GameIcon, HBITMAP:%hbm%
;Gui, Add, Button,                   x180 y410 w490 h230 cFFCC66 +Center +0x200 Border,
Gui, Add, Picture, gAbout x1058 y411 w90 h90 vRPCL3Icon, media/rpcl3_default_256_dark.png

Gui, Add, Text, gSystemInfoLabel            x1030 y510 w150 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % Chr(0x2139) " SYSTEM INFO"


; ─── System tray. ────────────────────────────────────────────────────────────
Gui, Add, Progress, x0 y650 w1190 h1 0x10 BackgroundcFFCC66 cCCCCCC Disabled
;Menu, Tray, NoStandard                       ;Remove default items like "Pause Script"
;Menu, Tray, Add, Exit, ExitScript            ;Add Exit
Menu, Tray, Add, Show GUI, ShowGui           ;Add a custom "Show GUI" option
Menu, Tray, Add                              ;Add a separator line
Menu, Tray, Add, About RPCL3..., ShowAboutDialog
Menu, Tray, Default, Show GUI                ;Make "Show GUI" the default double-click action
Menu, Tray, Tip, RPCS3 Priority Control Launcher 3    ;Tooltip when hovering
;Menu, Tray, Show


; ─── Status bar, 1 is used for RPCS3 status use 2 and 3. ────────────────────────────────────────────────────────────
Gui, Font, cCCCCCC s10.5 regular norm q5, Segoe UI Emoji
Gui, Add, Text, vCurrentPriority   x3 y655 w180,
Gui, Add, Text, vVariableText2   x200 y655 w180 cCCCCCC, [GAME_ID]
Gui, Add, Text, vVariableText3   x390 y655 w820 BackgroundTrans, [GAME_TITLE]
Gui, Add, Progress, x0 y676 w1190 h1 0x10 BackgroundcFFCC66 cCCCCCC Disabled


; ─── Bottom statusbar, 1 is reserved for process priority status, use 2. ──────────────────────────────────────────────
Gui, Add, StatusBar, vStatusBar1 hWndhStatusBar
SB_SetParts(345, 835)
UpdateStatusBar(msg, segment := 1) {
    SB_SetText(msg, segment)
}


; ─── update gui controls for last game in the custom statusbar. ──────────────────────────────────────────────
;idText := "LAST_PLAYED: " . (lastGameID != "" ? lastGameID : "NoData")
;GuiControl,, VariableText2, %idText%

Log("DEBUG", "Updated VariableText2 with: " . idText)

titleText := (lastGameTitle != "" ? lastGameTitle : "NoData")
GuiControl,, VariableText3, %titleText%

Log("DEBUG", "Updated VariableText3 with: " . titleText)


; ─── start timers for cpu/memory every x second(s). ──────────────────────────────────────────────
SetTimer, UpdateCPUMem, 1000


; ─── force one immediate priority update. ──────────────────────────────────────────────
Gosub, UpdatePriority


; ─── start priority timer after a delay (3s between updates), runs every 3 seconds. ───────────────────────────────────
SetTimer, UpdatePriority, 3000


; ─── record timestamp of last update. ───────────────────────────────────
FormatTime, timeStamp, , yyyy-MM-dd HH:mm:ss
Log("DEBUG", "Writing Timestamp " . timeStamp . " to " . iniFile)
IniWrite, %timeStamp%, %iniFile%, GAMES_FOUND, LastUpdated


; ─── this return ends all updates to the gui. ───────────────────────────────────
return
; ─── END GUI. ───────────────────────────────────────────────────────────────────


; ─── refresh path. ───────────────────────────────────────────────────────────────────
RefreshRPCS3Path()


; Load JSON once
FileRead, jsonData, %jsonFile%
if (ErrorLevel) {
    MsgBox, Failed to read JSON file!
    ExitApp
}
games := JSON.Load(jsonData)


SearchGame(jsonObj, searchTerm) {
    matches := []
    for gameId, gameData in jsonObj {
        props := gameData.Properties
        if !props
            continue
        title := props.GameTitle
        if (InStr(title, searchTerm, false) || InStr(gameId, searchTerm, false)) {
            match := {}
            match.GameId := gameId
            match.Title := title
            match.Eboot := props.Eboot
            matches.Push(match)
        }
    }

    if (matches.MaxIndex() = "") {
        MsgBox, No matching games found for "%searchTerm%".
        return
    }

    for i, match in matches {
        msg := "Match #" . i . ":`n`nGame ID: " . match.GameId . "`nTitle: " . match.Title . "`n`nUse this one?"
        MsgBox, 4,, %msg%
        IfMsgBox, Yes
            return match
    }

    MsgBox, No selection made.
    return
}


DoSearch:
InputBox, searchTerm, Game Search, Enter part of the title or Game ID:
if (searchTerm = "")
    return

FileRead, jsonText, rpcl3_games_db.json
jsonObj := JSON.Load(jsonText)

match := SearchGame(jsonObj, searchTerm)
if (match) {
    ebootPath := match.Eboot

    ; Chr(34) = double quotes character
    runCommand := rpcs3Path " --no-gui --fullscreen " . Chr(34) . ebootPath . Chr(34)

    IniWrite, %runCommand%, %iniFile%, RUN_GAME, RunCommand
    MsgBox, Written to INI:`n%runCommand%
}

return


;===============
GetGameCount(jsonFile) {
FileRead, jsonContent,  %A_ScriptDir%\rpcl3_games_db.json
    if (ErrorLevel) {
        ; CustomTrayTip("Failed to read " . jsonPath, 3)
        return 0
    }

    ; strip UTF-8 BOM
    if (SubStr(json,1,3) = Chr(0xEF) Chr(0xBB) Chr(0xBF))
        json := SubStr(json,4)

    try {
        parsed := JSON.Load(json)
        c := 0
        for k in parsed
            c++
        return c
    } catch e {
        ; CustomTrayTip("JSON parse error:`n" . e.Message, 3)
        return 0
    }
}


;============================================================================
RefreshGameCount:
ToolTip, Writing to INI: %iniFile%
Sleep, 1500
ToolTip

    ;────────────────────────────────────────────────────────
    ;  1.  Read rpcl3_games_db.json safely
    ;────────────────────────────────────────────────────────
    jsonFile  := A_ScriptDir . "\rpcl3_games_db.json"          ; keep the path in a var
    FileRead, jsonText, %jsonFile%
    if (ErrorLevel) {
        ; CustomTrayTip("Failed to read JSON file:`n" . jsonFile, 3)
        return
    }

    ; Strip UTF-8 BOM if present
    if (SubStr(jsonText, 1, 3) = Chr(0xEF) Chr(0xBB) Chr(0xBF))
        jsonText := SubStr(jsonText, 4)

    ;────────────────────────────────────────────────────────
    ;  2.  Parse JSON  (JSON.Load is what your script uses)
    ;────────────────────────────────────────────────────────
    try {
        gamesDB := LoadGamesDB(jsonFile)
        if (!gamesDB) {
            MsgBox, 16, Error, Failed to load games database.
            return
        }

        if !IsObject(parsed)
            throw Exception("parsed value is not an object")

        ;────────────────────────────────────────────────────
        ;  3.  Count games  –  each top-level key = one game
        ;────────────────────────────────────────────────────
        count := 0
        for k in parsed
            count++

        ;────────────────────────────────────────────────────
        ;  4.  Persist & update GUI
        ;────────────────────────────────────────────────────
        ; Save to INI
        IniWrite, %count%, %iniFile%, GAMES_FOUND, Count
        if ErrorLevel {
            MsgBox, 16, Error, Failed to write Count to INI: %iniFile%
        }

        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        IniWrite, %timestamp%, %iniFile%, GAMES_FOUND, LastUpdated
        if ErrorLevel {
            MsgBox, 16, Error, Failed to write LastUpdated to INI.
        } else {
            Log("DEBUG", "Wrote Count=" . count . " to section [GAMES_FOUND]")
        }

        GuiControl,, GameCount, % Chr(0x1F3AE) . " Games Found (Click to Refresh): " . count
        ; CustomTrayTip("Game count refreshed: " . count, 1)

    } catch e {
        ; CustomTrayTip("JSON parse error:`n" . e.Message, 3)
    }
return


;=============== SET WINDOW SIZE HANDLER.
SetSizeChoice:
global iniFile
clicked := A_GuiControl
global SizeChoice

; MAP CONTROL NAMES TO SIZE VALUES
sizes := { "Size800":       "800x600"
         , "Size1024":      "1024x768"L
         , "Size1280":      "1280x720"
         , "Size1920":      "1920x1080"
         , "Size2560":      "2560x1440"
         , "SizeFull":      "FullScreen"
         , "SizeWindowed":  "Windowed"
         , "SizeHidden":    "Hidden" }

; SAVE SELECTED SIZE
SizeChoice := sizes[clicked]
IniWrite, %SizeChoice%, %iniFile%, SIZE_SETTINGS, SizeChoice

; UPDATE VISUALS (BRACKET THE SELECTED ONE)
for key, val in sizes {
    label := (key = clicked) ? "[" . val . "]" : val
    GuiControl,, %key%, %label%
}
; === NEW: immediately apply the size ===
GoSub, ResizeWindow
return


ResizeWindow:
    global iniFile
    Gui, Submit, NoHide
    ;MsgBox, Current SizeChoice = %SizeChoice%  ; <-- DEBUG
    ; CustomTrayTip("Current SizeChoice: " . SizeChoice, 1)
    SB_SetText("Current SizeChoice: " . SizeChoice, 2)
    Log("DEBUG", "Current SizeChoice: " . SizeChoice)

    ;-----------------------------------------------------------------
    ;  1. make sure RPCS3 is running, get HWND
    ;-----------------------------------------------------------------
    WinGet, hwnd, ID, ahk_exe rpcs3.exe
    if !hwnd {
        MsgBox, rpcs3.exe is not running.
        return
    }
    WinID := "ahk_id " hwnd

    ;-----------------------------------------------------------------
    ; 2. helper to turn any fixed-size choice into “fake-fullscreen”
    ;-----------------------------------------------------------------
    FakeFullscreen(width, height)
    {
        ; remove borders / title bar
        global WinID
        WinSet, Style, -0xC00000, %WinID%  ; WS_CAPTION
        WinSet, Style, -0x800000, %WinID%  ; WS_BORDER
        WinSet, ExStyle, -0x00040000, %WinID%  ; WS_EX_DLGMODALFRAME
        WinShow, %WinID%

        ; which monitor is the window on?
        WinGetPos, winX, winY, , , %WinID%
        SysGet, MonitorCount, MonitorCount
        Loop, %MonitorCount% {
            SysGet, Mon, Monitor, %A_Index%
            if (winX >= MonLeft && winX < MonRight
             && winY >= MonTop  && winY < MonBottom) {
                monLeft   := MonLeft
                monTop    := MonTop
                monWidth  := MonRight  - MonLeft
                monHeight := MonBottom - MonTop
                break
            }
        }

        ; centre the custom-sized window
        newX := monLeft + (monWidth  - width)  // 2
        newY := monTop  + (monHeight - height) // 2
        WinMove, %WinID%, , %newX%, %newY%, %width%, %height%
    }

    ;-----------------------------------------------------------------
    ; 3. act on the user’s SizeChoice
    ;-----------------------------------------------------------------
    if (SizeChoice = "800x600")
        FakeFullscreen(800, 600)
    else if (SizeChoice = "1024x768")
        FakeFullscreen(1024, 768)
    else if (SizeChoice = "1280x720")
        FakeFullscreen(1280, 720)
    else if (SizeChoice = "1920x1080")
        FakeFullscreen(1920, 1080)
    else if (SizeChoice = "2560x1440")
        FakeFullscreen(2560, 1440)
    ; native maximised / true fullscreen
    else if (SizeChoice = "FullScreen") {
        WinRestore, %WinID%
        WinMaximize, %WinID%
    }
    ; windowed mode you already had (keeps borders, uses INI size)
    else if (SizeChoice = "Windowed") {
    ; Restore normal window styles
    WinSet, Style, +0xC00000, %WinID%       ; WS_CAPTION (title bar)
    WinSet, Style, +0x800000, %WinID%       ; WS_BORDER
    WinSet, Style, +0x20000,  %WinID%       ; WS_MINIMIZEBOX
    WinSet, Style, +0x10000,  %WinID%       ; WS_MAXIMIZEBOX
    WinSet, Style, +0x40000,  %WinID%       ; WS_SYSMENU (close button)
    WinSet, ExStyle, +0x00040000, %WinID%   ; WS_EX_DLGMODALFRAME

    WinShow, %WinID%
    WinRestore, %WinID%
    WinMaximize, %WinID%
    }
    else if (SizeChoice = "Hidden")
        WinHide, %WinID%
return


;=============== SWITCH BETWEEN MONITORS HANDLER.
Run, rpcs3.exe,,, pid
WinWait, ahk_exe rpcs3.exe


;=============== MONITOR SWITCH LOGIC
MoveToMonitor:
    MoveWindowToOtherMonitor("rpcs3.exe")
return


;=============== NUDGE BUTTON HANDLER.
NudgeLeft:
    Gui, Submit, NoHide
    NudgeWindow("rpcs3.exe", -NudgeStep, 0)
return

NudgeRight:
    Gui, Submit, NoHide
    NudgeWindow("rpcs3.exe", NudgeStep, 0)
return

NudgeUp:
    Gui, Submit, NoHide
    NudgeWindow("rpcs3.exe", 0, -NudgeStep)
return

NudgeDown:
    Gui, Submit, NoHide
    NudgeWindow("rpcs3.exe", 0, NudgeStep)
return


;=============== WINDOW FUNCTIONS
MoveWindowToOtherMonitor(exeName) {
    WinGet, hwnd, ID, ahk_exe %exeName%
    if !hwnd {
        MsgBox, %exeName% is not running.
        return
    }

    WinGetPos, winX, winY,,, ahk_id %hwnd%
    SysGet, Mon1, Monitor, 1
    SysGet, Mon2, Monitor, 2

    if (winX >= Mon1Left && winX < Mon1Right)
        currentMon := 1
    else
        currentMon := 2

    if (currentMon = 1) {
        targetLeft := Mon2Left
        targetTop := Mon2Top
        targetW := Mon2Right - Mon2Left
        targetH := Mon2Bottom - Mon2Top
    } else {
        targetLeft := Mon1Left
        targetTop := Mon1Top
        targetW := Mon1Right - Mon1Left
        targetH := Mon1Bottom - Mon1Top
    }

    WinRestore, ahk_id %hwnd%
    WinSet, Style, -0xC00000, ahk_id %hwnd%
    WinSet, Style, -0x800000, ahk_id %hwnd%
    WinMove, ahk_id %hwnd%, , targetLeft, targetTop, targetW, targetH
}

SetNudge:
global iniFile
    clickedText := A_GuiControl
    value := SubStr(clickedText, 4)

    ; Set the Edit field
    GuiControl,, NudgeStep, %value%
    IniWrite, %value%, %iniFile%, NUDGE_SETTINGS, NudgeStep

    ; Update the visual labels
    for _, n in ["5", "10", "15", "20", "25", "30", "35", "40"] {
        label := (clickedText = "Btn" . n) ? "[" . n . "]" : n
        GuiControl,, Btn%n%, %label%
    }
return

NudgeWindow(exeName, dx, dy) {
    WinGet, hwnd, ID, ahk_exe %exeName%
    if !hwnd
        return
    WinGetPos, x, y, w, h, ahk_id %hwnd%
    WinMove, ahk_id %hwnd%, , x + dx, y + dy
}


;=============== RESET TO DEFAULTS FOR WINDOW POSITIONS. -----------------------------------------------------------
ResetDefaults:
global SizeChoice, NudgeStep, DefaultSize, DefaultNudge, iniFile

; Restore defaults
SizeChoice := DefaultSize
NudgeStep := DefaultNudge

; Update GUI
GuiControl,, NudgeStep, %NudgeStep%
IniWrite, %NudgeStep%, %iniFile%, NUDGE_SETTINGS, NudgeStep

; Update size buttons
sizeToControl := { "800x600":       "Size800"
                 , "1024x768":      "Size1024"
                 , "1280x720":      "Size1280"
                 , "1920x1080":     "Size1920"
                 , "2560x1440":     "Size2560"
                 , "FullScreen":    "SizeFull"
                 , "Windowed":      "SizeWindowed"
                 , "Hidden": "SizeHidden" }

for key, val in sizeToControl {
    label := (key = SizeChoice) ? "[" . key . "]" : key
    GuiControl,, %val%, %label%
}
IniWrite, %SizeChoice%, %iniFile%, SIZE_SETTINGS, SizeChoice

; Update nudge buttons
Loop, 6 {
    step := 10 + (A_Index * 5)
    name := "Btn" . step
    label := (step = NudgeStep) ? "[" . step . "]" : step
    GuiControl,, %name%, %label%
}
return


;===============
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


; ─── refresh path to gameloader pcs3.exe. ────────────────────────────────────────────────────────────
RefreshPath:
    RefreshRPCS3Path()
    CustomTrayTip("Path refreshed: " rpcs3Path, 1)
    SB_SetText("PATH: " . rpcs3Path, 2)
    Log("DEBUG", "Path refreshed: " . rpcs3Path)
return


;=============== WEB LINKS.
Rpcs3Web:
    ;WARNING WITH EXCLAMATION ICON (48) AND 10-SECOND TIMEOUT
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;HANDLE ALL POSSIBLE RESPONSES
    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %rpcs3URL% timed out.")
    }
    else IfMsgBox Yes
    {
        Run, %rpcs3URL%
        Log("INFO", "Web action to %rpcs3URL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        Log("INFO", "Web action to %rpcs3URL% cancelled.")
        SetTimer, RemoveToolTip, -2000
    }
return

;===============
Rpcs3Forum:
    ;WARNING WITH EXCLAMATION ICON (48) AND 10-SECOND TIMEOUT
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;HANDLE ALL POSSIBLE RESPONSES
    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %rpcs3ForumURL% timed out.")
    }
    else IfMsgBox Yes
    {
        Run, %rpcs3ForumURL%
        Log("INFO", "Web action to %rpcs3FormURL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        Log("INFO", "Web action to %rpcs3ForumURL% cancelled.")
        SetTimer, RemoveToolTip, -2000
    }
return

;===============
rpcs3Wiki:
    ;WARNING WITH EXCLAMATION ICON (48) AND 10-SECOND TIMEOUT
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;HANDLE ALL POSSIBLE RESPONSES
    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %rpcs3WiKiURL% timed out.")
    }
    else IfMsgBox Yes
    {
        Run, %rpcs3WiKiURL%
        Log("INFO", "Web action to %rpcs3FormURL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        Log("INFO", "Web action to %rpcs3WiKiURL% cancelled.")
        SetTimer, RemoveToolTip, -2000
    }
return

RemoveToolTip:
    ToolTip
return

;===============
Downloadfirmware:
    ;WARNING WITH EXCLAMATION ICON (48) AND 10-SECOND TIMEOUT
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;HANDLE ALL POSSIBLE RESPONSES
    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %updateURL% timed out.")
    }
    else IfMsgBox Yes
    {
        Run, %updateURL%
        Log("INFO", "Web action to %updateURL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        Log("INFO", "Web action to %updateURL% cancelled.")
        SetTimer, RemoveToolTip, -2000
    }
return

;===============
Rpcs3Discord:
    ;WARNING WITH EXCLAMATION ICON (48) AND 10-SECOND TIMEOUT
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;HANDLE ALL POSSIBLE RESPONSES
    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %discordURL% timed out.")
    }
    else IfMsgBox Yes
    {
    Run, %discordURL%
    Log("INFO", "Web action to %discordURL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        SetTimer, RemoveToolTip, -2000
        Log("INFO", "Web action to %discordURL% cancelled.")
    }
return

;===============
PsHomeWeb:
    ;WARNING WITH EXCLAMATION ICON (48) AND 10-SECOND TIMEOUT
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;HANDLE ALL POSSIBLE RESPONSES
    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %RPCS3_DestinationHomeURL% timed out.")
    }
    else IfMsgBox Yes
    {
    Run, %RPCS3_DestinationHomeURL%
    Log("INFO", "Web action to %RPCS3_DestinationHomeURL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        SetTimer, RemoveToolTip, -2000
        Log("INFO", "Web action to %RPCS3_DestinationHomeURL% cancelled.")
    }
return

; ─── Open linlk to RPCS3 YouTube page. ────────────────────────────────────────────────────────────────────
RPCS3YouTubeLabel:
    ;warning with exclamation icon (48) and 10-second timeout
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;handle all possible responses
    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %RPCS3_YouTubeURL% timed out.")
    }
    else IfMsgBox Yes
    {
    Run, %RPCS3_YouTubeURL%
    Log("INFO", "Web action to %RPCS3_YouTubeURL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        SetTimer, RemoveToolTip, -2000
        Log("INFO", "Web action to %RPCS3_YouTubeURL% cancelled.")
    }
return

; ─── Open linlk to RPCS3 YouTube page. ────────────────────────────────────────────────────────────────────
RPCL3YouTubeLabel:
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    IfMsgBox Timeout
    {
        MsgBox, You didn't respond in time. Action cancelled.
        Log("INFO", "Web action to %RPCL3_YouTubeURL% timed out.")
    }
    else IfMsgBox Yes
    {
    Run, %RPCL3_YouTubeURL%
    Log("INFO", "Web action to %RPCL3_YouTubeURL% succesful.")
    }
    else IfMsgBox No
    {
        ToolTip, Action cancelled
        SetTimer, RemoveToolTip, -2000
        Log("INFO", "Web action to %RPCL3_YouTubeURL% cancelled.")
    }
return

; ─── Show RPCS3 version function. ────────────────────────────────────────────────────────────────────
About:
    ShowAboutDialog()
    Log("DEBUG", "RPCL3: About dialog window was opened.")
return


; ─── Show RPCS3 help function. ────────────────────────────────────────────────────────────────────
ShowHelpLabel:
    ShowHelp()
return

Help:
   ShowHelp()
Return

ShowHelp() {
Log("DEBUG", "The rpcs3Path = " . rpcs3Path)
    rpcs3Path := GetRPCS3Path()
    if (rpcs3Path = "") {
        MsgBox, 0, Error, RPCS3 path not selected or invalid.
        return
    }

    ; Check if rpcs3.exe is running
    Process, Exist, rpcs3.exe
    if (ErrorLevel != 0) {
        MsgBox, 0, RPCS3 is running, RPCS3 is currently running. Kill it to show Help?
        IfMsgBox, No
            return
        Process, Close, rpcs3.exe
        Sleep, 500
    }

    ; Run the --help command
	helpOutput := GetCommandOutput(rpcs3Path . " --help")
    Log("DEBUG", "HelpOutput = : " . helpOutput)
    if (helpOutput = "") {
		return
    }

    Gui, HelpGui:Destroy
    Gui, HelpGui:+Resize +MinSize
    Gui, HelpGui:Font, s9, Consolas
    Gui, HelpGui:Add, Edit, w600 h400 ReadOnly -Wrap, %helpOutput%
    Gui, HelpGui:Show,, RPCS3 Help
    Return
}


; ─── RPCSe3 show version function. ────────────────────────────────────────────────────────────────────
ShowVersionLabel:
    ShowVersion()
return

Version:
   ShowVersion()
Return

ShowVersion() {

    if (rpcs3Path = "") {
        MsgBox, 0, Error, RPCS3 path not selected or invalid.
        return
    }

    ;Check if rpcs3.exe is running
    Process, Exist, rpcs3.exe
    if (ErrorLevel != 0) {
        MsgBox, 0, RPCS3 is running, RPCS3 is currently running. Kill it to show version info?
        IfMsgBox, No
            return
        Process, Close, rpcs3.exe
        Sleep, 500
    }

    ; Run the --version command
    versionOutput := GetCommandOutput(rpcs3Path . " --version")
	Log("DEBUG", "VersionOutput = : " . versionOutput)
    if (versionOutput = "") {
		return
    }

    Gui, VersionGui:Destroy
    Gui, VersionGui:+Resize +MinSize
    Gui, VersionGui:Font, s9, Consolas
    Gui, VersionGui:Add, Edit, w600 h200 ReadOnly -Wrap, %versionOutput%
    Gui, VersionGui:Show,, RPCS3 Version Info
    Return
}


; ─── Set user agent function. ────────────────────────────────────────────────────────────────────
GetUrl(url)  ; returns response text or ""
{
    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", url, false)
    whr.SetRequestHeader("User-Agent", "AHK-RPCS3-Updater") ; GitHub blocks requests without UA
    whr.Send()
    return (whr.Status = 200) ? whr.ResponseText : ""
}

; ─── Download RPCS3 function. ────────────────────────────────────────────────────────────────────
DownloadRPCS3Label:
{
    MsgBox, 52, External Link Warning, Attention. This will download the latest RPCS3 archive from GitHub.`n`nAre you sure you want to continue?
    IfMsgBox, No
        return
    ; --- Ask where to save ---------------------------------------------------
    FileSelectFolder, userFolder,, 3, Select folder to save RPCS3 update
    if (userFolder = "")
        MsgBox, You cancelled folder selection.
        return

    ; --- Step 1: query GitHub API -------------------------------------------
    json := GetUrl("https://api.github.com/repos/RPCS3/rpcs3-binaries-win/releases/latest")
    if (!json)
        MsgBox, Couldn’t reach GitHub (rate-limit or offline).
        return

    ; --- Step 2: pull out the asset we want ---------------------------------
    RegExMatch(json, """browser_download_url"":\s*""([^""]+win64\.7z)""", m)
    latestUrl := m1
    if (latestUrl = "")
        MsgBox, No *.win64.7z asset found in the latest release.
        return

    SplitPath, latestUrl, fileName
    savePath := userFolder "\" fileName

    ; --- Step 3: build a one-shot PowerShell script & run it ----------------
    psFile := A_Temp "\rpcs3_download.ps1"
    FileDelete, %psFile%
    FileAppend,
    (
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient
try {
    $wc.DownloadFile("%latestUrl%", "%savePath%")
    Write-Output "Success"
} catch {
    Write-Output $_.Exception.Message
}
    ), %psFile%

    RunWait, %ComSpec% /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%psFile%" > "%A_Temp%\rpcs3_output.txt" 2>&1,, Hide
    FileRead, output, %A_Temp%\rpcs3_output.txt

if !InStr(output, "Success")
    {
        MsgBox, 16, Download Failed, % "Error:`n" . output
        return
    }
    if Extract7z(savePath, userFolder) {
        version := info["version"]
        MsgBox, 64, Success, RPCS3 v%version% downloaded and extracted.`nArchive deleted.
        return
    } else {
        version := info["version"]
        MsgBox, 48,Partial Success, RPCS3 v%version% downloaded, but failed to extract.`n`nArchive left at:`n%savePath%
        return
    }
}


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

    path := Trim(path, "`" " ")  ;TRIM SURROUNDING QUOTES AND SPACES

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


;;TODO
;;--- optional help gui ---
;Gui, HelpGui:Destroy
;Gui, HelpGui:+Resize +MinSize
;Gui, HelpGui:Font, s9, Consolas
;Gui, HelpGui:Add, Edit, w600 h400 ReadOnly -Wrap, %helpOutput%
;Gui, HelpGui:Show,, RPCS3 Help
;return


; ─── Show system info function. ────────────────────────────────────────────────────────────────────
SystemInfoLabel:
    ;Create and show a small loading GUI
    Gui, LoadingGui:Destroy
    Gui, LoadingGui:Add, Text, w200 h50 Center, Loading system info, please wait...
    Gui, LoadingGui:Show,, Please Wait

    ;Force GUI to update so user sees it immediately
    Gui, LoadingGui:Default
    Sleep, 50
    ;Allow GUI message queue to process (optional)
    Sleep, 10

    ;Now fetch the system info (potentially slow)
    sysInfo := GetSystemInfo()

    ;Close the loading GUI
    Gui, LoadingGui:Destroy

    ;Create and show the full system info GUI
    Gui, SysInfoGui:Destroy
    Gui, SysInfoGui:+Resize +MinSize
    Gui, SysInfoGui:Font, s10, Consolas
    Gui, SysInfoGui:Add, Edit, w600 h300 ReadOnly -Wrap +HScroll +VScroll, % sysInfo
    Gui, SysInfoGui:Show,, RPCS3 System Information
Return

; ─── SRPCS3 path function. ────────────────────────────────────────────────────────────────────
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

; ─── Install firmware function. ────────────────────────────────────────────────────────────────────
Installfirmware:
    Gui -AlwaysOnTop
    rpcs3Path := GetRPCS3Path()
    if (rpcs3Path = "") {
        MsgBox, 3, Error, Path not selected or invalid.
        Gui, +AlwaysOnTop
        return
    }

    ;Check if rpcs3.exe is running
    Process, Exist, rpcs3.exe
    if (ErrorLevel != 0) {
        Gui -AlwaysOnTop
        MsgBox, 3, RPCS3 is running, RPCS3 is currently running. Kill it to install firmware?
        IfMsgBox, No
            return
        Process, Close, %rpcs3Exe%
        Sleep, 500
    }

Gui, New, +AlwaysOnTop +OwnDialogs +HwndhWnd
Gui, Show, Hide

FileSelectFile, firmwarePath, 3,, Select PS3 Firmware File (*.PUP), *.PUP

Gui, Destroy

if (firmwarePath = "") {
    MsgBox, 48, Warning, No firmware file selected.
    return
}
MsgBox, 64, Info, You selected:`n%firmwarePath%
RunWait, "%rpcs3Path%" --installfw "%firmwarePath%", , Hide
MsgBox, 0, Done, Firmware installed successfully.
Gui +AlwaysOnTop
return

; ─── Install .pkg function. ────────────────────────────────────────────────────────────────────
InstallPkg:
    rpcs3Path := GetRPCS3Path()
    if (rpcs3Path = "") {
        MsgBox, 0, Error, Path not selected or invalid.
        return
    }

    ;Check if rpcs3.exe is running
    Process, Exist, rpcs3.exe
    if (ErrorLevel != 0) {
        MsgBox, 4, RPCS3 is running, RPCS3 is currently running. Kill it to install package?
        ;4 = Yes/No buttons
        IfMsgBox, No
            return
        Process, Close, rpcs3.exe
        Sleep, 500
    }

    MsgBox, 1, PKG Installer, Please select a .pkg, .rap, or .edat file.`nClick Cancel to abort.
    ;1 = OK/Cancel buttons
    IfMsgBox, Cancel
        return

    FileSelectFile, pkgPath,, 3, Select PKG file for --installpkg, *.pkg;*.rap;*.edat
    if (pkgPath = "") {
        MsgBox, 0, Warning, No package file selected.
        return
    }

    RunWait, "%rpcs3Path%" --installpkg "%pkgPath%", , Hide
    ; CustomTrayTip("Package installed successfully.", 1)
return


; ─── Set process priority function. ────────────────────────────────────────────────────────────────────
SetPriority:
    Gui, Submit, NoHide
    if PriorityChoice =  ;empty or not selected
    {
        ; CustomTrayTip("Please select a priority before setting.", 2)
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
        ; CustomTrayTip("Set to: " PriorityChoice, 1)
        Log("INFO", "Set RPCS3 priority to " . PriorityChoice)
        SB_SetText("Priority set to " . PriorityChoice, 2)
    } else {
        ; CustomTrayTip("RPCS3 not running.", 1)
        Log("WARN", "Attempted to set priority, but RPCS3 is not running.")
        SB_SetText("RPCS3 must be running when trying to set priority.", 2)
    }
return

; ─── Update process priority function. ────────────────────────────────────────────────────────────────────
UpdatePriority:
    Process, Exist, rpcs3.exe
    if (!ErrorLevel) {
        GuiControl,, CurrentPriority, RPCS3 Not Running.
        GuiControl, Disable, PriorityChoice
        GuiControl, Disable, Set Priority
        UpdateCPUMem()
        return
    }

    pid := ErrorLevel
    current := GetPriority(pid)
    SetPriorityColor(current)

    GuiControl,, CurrentPriority, Priority: %current%

    global lastPriority
    if (current != lastPriority) {
        GuiControl,, PriorityChoice, %current%
        lastPriority := current
        SB_SetText("Priority updated to " . current, 2)
    }

    GuiControl, Enable, PriorityChoice
    GuiControl, Enable, Set Priority
    UpdateCPUMem()
return

; ─── Get currrent process priority function. ────────────────────────────────────────────────────────────────────
GetPriority(pid) {
    try {
        wmi := ComObjGet("winmgmts:")
        query := "Select Priority from Win32_Process where ProcessId=" pid
        for proc in wmi.ExecQuery(query)
            return MapPriority(proc.Priority)
        return "Unknown"
    } catch e {
        ; CustomTrayTip("Failed to get priority.", 3)
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

KillAllProcesses(pid := "") {
    if (pid) {
        Run, "%A_ScriptFullPath%" activate
        RunWait, taskkill /im %rpcs3Exe% /F,, Hide
        RunWait, taskkill /im powershell.exe /F,, Hide
        RunWait, %ComSpec% /c taskkill /PID %pid% /F, , Hide
        ;Optional: Kill any potential child processes
        RunWait, %ComSpec% /c taskkill /im powershell.exe /F, , Hide
        Log("INFO", "KillAllProcesses: Killed PID " . pid)
    } else {
        Log("WARN", "KillAllProcesses: No PID provided.")
    }
}

; ─── Load settings function. ────────────────────────────────────────────────────────────────────
LoadSettings() {
    global PriorityChoice, iniFile, rpcs3Exe

    Process, Exist, %rpcs3Exe%
    if (!ErrorLevel) {
        defaultPriority := "Normal"
        ; IniWrite, %defaultPriority%, %iniFile%, PRIORITY, Priority

        ;Extract just the filename for display
        SplitPath, iniFile, iniFileName

        ;Status bar message with clean formatting
        SB_SetText("Process Not Found. Priority [" defaultPriority "] Saved to " iniFileName ".", 2)
        ; CustomTrayTip("Initial Priority Set to " defaultPriority, 1)

        ;Update GUI
        GuiControl, ChooseString, PriorityChoice, %defaultPriority%
        PriorityChoice := defaultPriority

        Log("INFO", "Set default priority to " defaultPriority " in " iniFile)
    }
    else {
        ;Load saved priority if process exists
        IniRead, savedPriority, %iniFile%, PRIORITY, Priority, Normal
        GuiControl, ChooseString, PriorityChoice, %savedPriority%
        PriorityChoice := savedPriority
    }
}

; ─── Save current settings function. ────────────────────────────────────────────────────────────────────
SaveSettings() {
    global PriorityChoice, iniFile

    ;Get current selection from GUI (important!)
    GuiControlGet, currentPriority,, PriorityChoice
    Log("DEBUG", "Attempting to save priority: " currentPriority)

    ;Save to INI
    ; IniWrite, %currentPriority%, %iniFile%, PRIORITY, Priority
    Log("INFO", "TrayTip shown: Priority set to " currentPriority)
}


; ─── Kill RPCS3 with button function. ────────────────────────────────────────────────────────────────────
CloseRpcs3Label:
    SoundPlay, %A_ScriptDir%\media\rpcl3_game_over.wav  ; ← plays the sound once
    ;Confirm what we're checking for
    Log("DEBUG", "Checking for process: " . rpcs3Exe)
    Process, Exist, %rpcs3Exe%

    pid := ErrorLevel
    if (pid) {
        KillAllProcesses(pid)  ;Pass PID to function
        ; CustomTrayTip("Killed all RPCS3 processes.", 2)
        Log("INFO", "Killed all RPCS3 processes (PID: " . pid . ")")
        SB_SetText("Killed all RPCS3 processes.", 2)
    } else {
        ; CustomTrayTip("No RPCS3 processes running.", 2)
        Log("INFO", "No RPCS3 processes running.")
        SB_SetText("No RPCS3 processes running", 2)
    }

    Gui, Show ;Show or hide GUI but keep script alive
    Menu, Tray, Show  ;Ensure tray icon stays visible
return

; ─── Close RPCL3. ────────────────────────────────────────────────────────────────────
ExitRPCL3Label:
    Log("INFO", "Exiting AHK using the Exit button.")
    ExitApp
return

;; ─── Set EBOOT.BIN path function. ────────────────────────────────────────────────────────────────────
;SetEbootBinPathLabel:
;global iniFile
;; 1  Ask user for an EBOOT.BIN
;FileSelectFile, selectedEboot, 3,, Select EBOOT.BIN, EBOOT.BIN
;if (ErrorLevel || !selectedEboot)
;    return                                        ; user cancelled
;; 2  Verify the filename is literally EBOOT.BIN
;SplitPath, selectedEboot, fileName
;if (fileName != "EBOOT.BIN") {
;    MsgBox, 48, Invalid, Please select a valid EBOOT.BIN file.
;    return
;}
;; 3  Extract Game ID (handles both [BLUS30001] and dev_hdd0 style)
;gameID := ExtractGameID(selectedEboot)
;if (gameID = "") {
;    MsgBox, 16, Error, Could not extract Game ID from:`n%selectedEboot%
;    Log("ERROR", "Could not extract GameID from path: " . selectedEboot)
;    return
;}
;Log("DEBUG", "Extracted GameID: " . gameID)
;; 4  Load games database (cached after first call)
;gamesDB := LoadGamesDB(A_ScriptDir . "\rpcl3_games_db.json")
;if (!gamesDB) {
;    MsgBox, 16, Error, Could not load rpcl3_games_db.json
;    return
;}
;; 5  Determine game title
;if (gamesDB.HasKey(gameID))
;    gameTitle := gamesDB[gameID].Properties.GameTitle
;else
;    gameTitle := "Unknown Title"
;; 6  Ask user only if we still don’t know ID or title
;if (gameID = "UnknownID" || gameTitle = "Unknown Title") {
;    InputBox, userGameID, Enter Game ID (9 chars),\nExample: BLUS30001
;    if (ErrorLevel || StrLen(userGameID) != 9)
;        return
;    InputBox, userGameTitle, Enter Game Title
;    if (ErrorLevel)
;        return
;    gameID    := userGameID
;    gameTitle := userGameTitle
;    ; Save into NEW_GAMES for later curation
;    IniWrite, %gameID%,    %iniFile%, NEW_GAMES, GameID
;    IniWrite, %gameTitle%, %iniFile%, NEW_GAMES, GameTitle
;}
;; 7  Persist selected EBOOT and basic info
;IniWrite, %selectedEboot%, %iniFile%, RUN_GAME, EbootBinPath
;IniWrite, %gameID%,       %iniFile%, LAST_PLAYED, GameID
;IniWrite, %gameTitle%,    %iniFile%, LAST_PLAYED, GameTitle
;Log("INFO", "Saved EBOOT & game info: " . gameID . " - " . gameTitle)
;
;; 8  Show the cover art & update LAST_PLAYED.IconPath
;ShowIconAndRemember(selectedEboot)
;return
;
;; after user picks an EBOOT.BIN and you’ve validated the file exists:
;FileSelectFile, selectedEboot, 3,, Select EBOOT.BIN, EBOOT.BIN
;    if (ErrorLevel || !selectedEboot)
;return

; ─── Show icon and remember selected EBOOT.BIN function. ──────────────────────────────────────────────────────────────
;  • Extracts the 9-char GameID from the chosen EBOOT.BIN
;  • Looks up game title & ICON0.PNG in rpcl3_games_db.json (cached)
;  • Falls back to rpcl3_no_image_found.png if missing
;  • Updates the GUI picture, status bar & LAST_PLAYED section in INI
;  • Saves the absolute EbootBinPath in [EBOOT_BIN]
; ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
ShowIconAndRemember(selectedEboot) {
    ; ── Static caches ─────────────────────────────────────────
    static gamesDB := ""          ; JSON DB loaded once
    static hbmPrev := 0           ; last GDI+ bitmap for cleanup

    ;baseDir := A_ScriptDir . "\"
    iniFile := A_ScriptDir . "\rpcl3.ini"

    ; ── 1. Extract GameID ─────────────────────────────────────
    gameID := ExtractGameID(selectedEboot)
    if (gameID = "") {
        MsgBox, 16, Error, Could not extract GameID from:`n%selectedEboot%
        Log("ERROR", "Could not extract GameID from: " . selectedEboot)
        return
    }

    ; ── 2. Load / cache JSON DB ───────────────────────────────
    if (!IsObject(gamesDB)) {
        jsonFile := baseDir . "rpcl3_games_db.json"
        if !FileExist(jsonFile) {
            MsgBox, 16, Error, rpcl3_games_db.json not found!
            return
        }
        FileRead, txt, %jsonFile%
        if (SubStr(txt,1,3)=Chr(0xEF) Chr(0xBB) Chr(0xBF))
            txt := SubStr(txt,4)
        try gamesDB := JSON.Load(txt)
        catch e {
            MsgBox % "JSON parse error: " . e.Message
            return
        }
    }

    ; ── 3. Resolve title & icon path ──────────────────────────
    noImage := baseDir . "rpcl3_no_image_found.png"
    iconPath := noImage
    gameTitle := "Unknown Title"

    if (gamesDB.HasKey(gameID)) {
        props := gamesDB[gameID].Properties
        if (props.HasKey("GameTitle"))
            gameTitle := props.GameTitle
        if (props.HasKey("Icon0")) {
            iconRel := props.Icon0
            if (SubStr(iconRel,1,1) = "/")
                iconRel := SubStr(iconRel,2)
            iconTry := baseDir . StrReplace(iconRel,"/","\")
            if FileExist(iconTry)
                iconPath := iconTry
        }
    } else {
        Log("WARN", "GameID '" . gameID . "' not found in DB.")
    }

    ; ── 4. Update GUI image safely ────────────────────────────
    if (hbmPrev)
        DeleteObject(hbmPrev), hbmPrev := 0
    hbmPrev := LoadPicture(iconPath, "GDI+ h208")
    if (hbmPrev)
        GuiControl,, GameIcon, HBITMAP:%hbmPrev%
    else
        MsgBox, 48, Warning, Failed to load image:`n%iconPath%

    ; ── 5. Persist INI fields ─────────────────────────────────
    ;IniWrite, %selectedEboot%, %iniFile%, RUN_GAME, EbootBinPath
    IniWrite, %selectedEboot%, %iniFile%, LAST_PLAYED, EbootPath
    IniWrite, %gameID%,       %iniFile%, LAST_PLAYED, GameID
    IniWrite, %gameTitle%,    %iniFile%, LAST_PLAYED, GameTitle
    IniWrite, %iconPath%,     %iniFile%, LAST_PLAYED, IconPath

    ; ── 6. UI / log feedback ─────────────────────────────────
    UpdateStatusBar("Path saved: " . selectedEboot, 2)
    ; CustomTrayTip("Game Set: " . gameID . " - " . gameTitle, 1)
    Log("INFO", "Last played updated: " . gameID . " - " . gameTitle)
}

; ─── Run RPCS3 standalone function. ────────────────────────────────────────────────────────────────────
;RunRPCS3Label:
;    global iniFile
;    if (!FileExist(iniFile)) {
;        SplitPath, iniFile, iniFileName
;        ; CustomTrayTip("Missing " . iniFile . " Set RPCS3 path first.", 3)
;        SB_SetText("Missing " . iniFile . " Set RPCS3 path first.", 2)
;        Return
;    }
;
;    SB_SetText("Reading from: " . iniFile, 2)
;
;    IniRead, rpcs3Path, %iniFile%, RPCS3, Path
;    SB_SetText("Path read: " . rpcs3Path, 2)
;
;    if (ErrorLevel) {
;        ; CustomTrayTip("Could not read path from " . iniFile, 3)
;        SB_SetText("Could not read the path from " . iniFile, 2)
;        Log("ERROR", "Could not read the path from section [RPCS3] in`n" . iniFile)
;        Return
;    }
;
;    if !FileExist(rpcs3Path) {
;        ; CustomTrayTip("File not found: " . rpcs3Path, 3)
;        SB_SetText("File not found: " . rpcs3Path, 2)
;        Log("ERROR", "The file does not exist:`n" . rpcs3Path)
;        Return
;    }
;
;    ;Extract the EXE name only
;    SplitPath, rpcs3Path, rpcs3Exe
;
;    ;Kill any existing RPCS3 process by exe name
;    RunWait, taskkill /im %rpcs3Exe% /F,, Hide
;    Sleep, 1000
;
;; Launch RPCS3
;Run, %rpcs3Path%
;Sleep, 2000  ; Give it time to initialize
;
;Sleep, 2000
;Process, Exist, %rpcs3Exe%
;if (!ErrorLevel)
;{
;    MsgBox, 16, Error, Failed to launch RPCS3:`n%rpcs3Path%
;    Log("ERROR", "RPCS3 failed to launch.")
;    SB_SetText("ERROR: RPCS3 did not launch.", 2)
;    ; CustomTrayTip("ERROR: RPCS3 did not launch!", 3)
;    return
;}
;
;SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav
;Log("INFO", "Game Started.")
;SB_SetText("Good Morning! Game Started.", 2)
;; CustomTrayTip("Good Morning! Game Started.", 1)
;UpdateStatusBar("Good Morning! Game Started.", 2)


; ─── Run RPCS3 standalone function. ────────────────────────────────────────────────────────────────────
RunRPCS3Label:
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

    SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav
    Log("INFO", "Game Started.")
    SB_SetText("Good Morning! Game Started.", 2)
    CustomTrayTip("Good Morning! Game Started.", 1)
    UpdateStatusBar("Good Morning! Game Started.", 3)
Return


;; ─── Start RPCS3 game function. ────────────────────────────────────────────────────────────────────
;RunRPCS3GameLabel:
;global iniFile, rpcs3Exe
;rpcs3Path := GetRPCS3Path()
;
;; Kill existing RPCS3 processes forcefully
;RunWait, taskkill /im %rpcs3Exe% /F,, Hide
;Sleep, 1000
;
;;Read RPCS3 path and extract executable name if found
;IniRead, rpcs3Path, %IniFile%, RPCS3, Path
;if (rpcs3Path != "") {
;    global rpcs3Exe
;    SplitPath, rpcs3Path, rpcs3Exe
;}
;IniRead, fullEbootPath, %iniFile%, RUN_GAME, EbootBinPath
;
;; Validate paths
;if (!FileExist(rpcs3Path)) {
;    CustomTrayTip("RPCS3 executable not found!", 3)
;    SB_SetText("ERROR: RPCS3 executable not found.", 2)
;    Log("ERROR", "RPCS3 executable not found: " . rpcs3Path)
;    return
;}
;
;if (!FileExist(fullEbootPath)) {
;    CustomTrayTip("EBOOT.BIN not found.", 3)
;    SB_SetText("ERROR: EBOOT.BIN not found.", 2)
;    Log("ERROR", "EBOOT.BIN not found: " . fullEbootPath)
;    return
;}
;
;; Extract GameID for logging or later use
;gameID := ExtractGameID(fullEbootPath)
;if (gameID = "") {
;    Log("WARN", "Failed to extract GameID from path: " . fullEbootPath)
;} else {
;    Log("DEBUG", "Extracted GameID: " . gameID)
;}
;; Extract executable filename from full path
;SplitPath, rpcs3Path, rpcs3Exe
;
;; Convert EBOOT.BIN path to relative if inside script folder
;if (InStr(fullEbootPath, A_ScriptDir . "\") = 1) {
;    ebootRelativePath := SubStr(fullEbootPath, StrLen(A_ScriptDir) + 2)  ; Remove script dir + backslash
;} else {
;    ebootRelativePath := fullEbootPath
;}
;
;; Normalize slashes to backslashes
;StringReplace, ebootRelativePath, ebootRelativePath, /, \, All
;
;; Build command string (ensure proper quoting)
;runGameCommand := GetCommandOutput(rpcs3Path . --no-gui --fullscreen . ebootRelativePath)
;Log("DEBUG", "Full command: " . runGameCommand)
;; Full command: "rpcs3.exe" --no-gui --fullscreen "games\Ridge Racer 7 [BLUS30001]\PS3_GAME\USRDIR\EBOOT.BIN"
;; Save last run command to INI (optional)
;IniWrite, %runGameCommand%, %iniFile%, RUN_GAME, RunCommand
;
;; Run RPCS3 with the constructed command line, start in the RPCS3 directory
;SplitPath, rpcs3Path, , rpcs3Dir
;Run, %ComSpec% /c %runGameCommand%, %rpcs3Dir%, , newPID
;
;Sleep, 2000
;Process, Exist, %rpcs3Exe%
;if (!ErrorLevel)
;{
;    MsgBox, 16, Error, Failed to launch RPCS3:`n%rpcs3Path%
;    Log("ERROR", "RPCS3 failed to launch.")
;    SB_SetText("ERROR: RPCS3 did not launch.", 2)
;    ; CustomTrayTip("ERROR: RPCS3 did not launch!", 3)
;    return
;}
;
;SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav
;Log("DEBUG", "Started RPCS3 with GameID: " . gameID)
;SB_SetText("Good Morning! Your Game Started.", 2)
;; CustomTrayTip("Good Morning! Your Game Started.", 1)
;UpdateStatusBar("Good Morning! Your Game Started. ", 3)

; ─── Start RPCS3 game function using full RunCommand from INI ──────────────
;RunRPCS3GameLabel:
;global iniFile, rpcs3Exe
;runCommand := rpcs3Path " --no-gui --fullscreen " . Chr(34) . ebootPath . Chr(34)
;; Kill any existing RPCS3 processes
;RunWait, taskkill /im %rpcs3Exe% /F,, Hide
;Sleep, 1000
;
;; Get RunCommand from INI
;IniRead, runCommand, %iniFile%, RUN_GAME, RunCommand
;if (runCommand = "ERROR" or runCommand = "") {
;    MsgBox, 16, Error, Failed to read RunCommand from INI.
;    return
;}
;Log("DEBUG", "Read from INI: " . runCommand)
;
;if (runCommand = "" || runCommand = "ERROR") {
;    MsgBox, 16, Error, RunCommand is empty or not found in INI file!
;    return
;}
;
;Log("DEBUG", "Running command: " . runCommand)
;
;fullRunCmd := ComSpec . " /c " . runCommand
;
;Log("DEBUG", "Running command: " . fullRunCmd)
;
;; Post-run check
;Sleep, 2000
;Process, Exist, %rpcs3Exe%
;if (!ErrorLevel) {
;    MsgBox, 16, Error, Failed to launch RPCS3:`n%rpcs3Path%
;    Log("ERROR", "RPCS3 failed to launch.")
;    SB_SetText("ERROR: RPCS3 did not launch.", 2)
;    return
;}
;
;; Success feedback
;SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav
;Log("DEBUG", "Started RPCS3 with command from INI.")
;SB_SetText("Good Morning! Your Game Started.", 2)
;UpdateStatusBar("Good Morning! Your Game Started. ", 3)
;return

RunRPCS3GameLabel:
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

SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav
Log("DEBUG", "Started RPCS3 with command from INI.")
SB_SetText("Good Morning! Your Game Started.", 2)
UpdateStatusBar("Good Morning! Your Game Started.", 3)
return



; ─── View logs function. ────────────────────────────────────────────────────────────────────
ViewLog:
global logFile
    Run, notepad.exe "%A_ScriptDir%\rpcl3.log"
    Log("DEBUG", "Opened " . logFile . " in Notepad.")
    SB_SetText(logFile . " opened.", 2)
return


; ─── Clear logs function. ────────────────────────────────────────────────────────────────────
ClearLog:
global logFile
FileDelete, %logFile%
CustomTrayTip(logFile . " cleared successfully", 1)
return


; ─── View configuration function. ────────────────────────────────────────────────────────────────────
ViewConfigLabel:
    global iniFile
    Run, notepad.exe "%iniFile%"
    SplitPath, iniFile, iniFileName
    Log("DEBUG", "Opened: " iniFile)
    UpdateStatusBar(iniFile . " opened.",2)
return

; ─── Show "about" dialog function. ────────────────────────────────────────────────────────────────────
ShowAboutDialog() {
    ;Extract embedded version.dat resource to temp file
    tempFile := A_Temp "\version.dat"
    hRes := DllCall("FindResource", "Ptr", 0, "VERSION_FILE", "Ptr", 10) ;RT_RCDATA = 10
    if (hRes) {
        hData := DllCall("LoadResource", "Ptr", 0, "Ptr", hRes)
        pData := DllCall("LockResource", "Ptr", hData)
        size := DllCall("SizeofResource", "Ptr", 0, "Ptr", hRes)
        if (pData && size) {
            File := FileOpen(tempFile, "w")
            if IsObject(File) {
                File.RawWrite(pData + 0, size)
                File.Close()
            }
        }
    }

    ;Read version string
    FileRead, verContent, %tempFile%
    version := "Unknown"
    if (verContent != "") {
        version := verContent
    }

aboutText := "RPCS3 Priority Control Launcher 3 RPCL3`n"
           . "Realtime Process Priority Management for RPCS3`n"
           . "Version: " . version . "`n"
           . Chr(169) . " " . A_YYYY . " Philip" . "`n"
           . "YouTube: @game_play267" . "`n"
           . "Twitch: RR_357000" . "`n"
           . "X: @relliK_2048" . "`n"
           . "Discord:"

MsgBox, 64, About RPCL3, %aboutText%
}

; ─── Log system usage with time interval function. ────────────────────────────────────────────────────────────────────
LogSystemUsageIfDue(cpuLoad, freeMem, totalMem) {
    global lastResourceLog, logInterval
    timeNow := A_TickCount
    if (timeNow - lastResourceLog >= logInterval) {
        lastResourceLog := timeNow
        Log("DEBUG", "CPU: " . cpuLoad . "% | Free RAM: " . freeMem . " MB / " . totalMem . " MB")
    }
}

; ─── Update CPU status function. ────────────────────────────────────────────────────────────────────
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

        global lastResourceLog := 0  ; Global variable to track last log time
        global logInterval := logInterval   ; 5 seconds in milliseconds

        LogSystemUsageIfDue(cpuLoad, freeMem, totalMem)

    } catch e {
        SB_SetText("Error fetching CPU/memory: " . e.Message, 2)
    }
}

; ─── Kill RPCS3 process with escape button function. ────────────────────────────────────────────────────────────────────
Esc::
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

; ─── Find game title in .ini function. ────────────────────────────────────────────────────────────────────
FindGameTitle(gameID) {
    global iniFile
    StringUpper, lookupID, gameID

    FileRead, content, %iniFile%
    inGamesSection := false

    Loop, Parse, content, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue

        if (SubStr(line, 1, 1) = "[") {
            StringLower, section, line
            if (section = "[games]") {
                inGamesSection := true
            } else {
                inGamesSection := false
            }
            continue
        }

        if (!inGamesSection)
            continue

        equalPos := InStr(line, "=")
        if (!equalPos)
            continue

        id := Trim(SubStr(line, 1, equalPos - 1))
        StringUpper, idUpper, id

        title := Trim(SubStr(line, equalPos + 1))

        if (idUpper = lookupID)
            return title
    }
    return "Unknown Title"
}

; ─── Custom tray tip function ────────────────────────────────────────────────────────────────────
CustomTrayTip(Text, Icon := 1) {
    ;Parameters:
    ;Text  - Message to display
    ;Icon  - 0=None, 1=Info, 2=Warning, 3=Error (default=1)
    static Title := "RPCL3 Launcher"
    ;Validate icon input (clamp to 0-3 range)
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    ;16 = No sound (bitwise OR with icon value)
    TrayTip, %Title%, %Text%, , % Icon|16
}

; ─── Set process priority function. ────────────────────────────────────────────────────────────────────
SetPriorityColor(priorityText) {
    color := "FFFFFF" ;Default color (black)

    switch priorityText {
        case "Idle":
            color := "808080" ;Gray
        case "Below Normal":
            color := "CCCCCC" ;Silver
        case "Normal":
            color := "00FF00" ;Green
        case "Above Normal":
            color := "FFFF00" ;Yellow
        case "High":
            color := "FFCC66" ;goldenrod
        case "Realtime", "Realtime":
            color := "FF0000" ;Red
    }

    GuiControl, +c%color%, CurrentPriority  ;Apply color to the control
}

; ─── Add game title to database function. ────────────────────────────────────────────────────────────────────
AddOrUpdateGameTitle(gameID, gameTitle) {
    global iniFile
    IniWrite, %gameTitle%, %iniFile%, GAMES, %gameID%
}

gameTitle := FindGameTitle(gameID)
if (gameTitle = "Unknown Title") {
    ;Try to parse PARAM.SFO if possible, else empty default


    InputBox, userInput, Enter Game Title, Game ID: %gameID%`nEnter the correct game title:, , 300, 120, , , , %suggestedTitle%
    if (ErrorLevel = 0 && userInput != "") {
        AddOrUpdateGameTitle(gameID, userInput)
        gameTitle := userInput
        ;GuiControl,, VariableText3, %gameTitle%
        MsgBox, Game title saved.
    } else {
        MsgBox, No title entered, using Unknown Title.
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

; ─── RPCS3 running check function. ────────────────────────────────────────────────────────────────────
GetRPCS3WindowID(ByRef hwnd) {
    WinGet, hwnd, ID, ahk_exe rpcs3.exe
    if !hwnd {
        MsgBox, rpcs3.exe is not running.
        return false
    }
    return true
}

; ─── Install 7-zip function. ────────────────────────────────────────────────────────────────────
Extract7z(filePath, extractTo) {
    sevenZipPath := A_ScriptDir "\tools\7z.exe"

    if !FileExist(sevenZipPath) {
        MsgBox, 16, Error, Missing 7z.exe in script folder.`n%sevenZipPath%
        return false
    }

    ; Run 7-Zip to extract the file
    RunWait, %ComSpec% /c ""%sevenZipPath%" x "%filePath%" -o"%extractTo%" -y",, Hide

    if ErrorLevel {
        MsgBox, 16, Error, Extraction failed.
        return false
    }

    return true
}

; ─── Take screenshot function. ────────────────────────────────────────────────────────────────────
TakeScreenshotLabel:
{
    global iniFile

    ; 1 Load GameID
    IniRead, GameID, %iniFile%, LAST_PLAYED, GameID, UNKNOWN
    if (GameID = "UNKNOWN") {
        ; CustomTrayTip("GameID not found in INI.",2)
        Log("ERROR", "GameID not found in INI file.")
        SB_SetText("GameID not found in INI.", 2)
        return
    }

    ; 2 Ensure RPCS3 exists
    if !WinExist("ahk_exe rpcs3.exe") {
        ; CustomTrayTip("RPCS3 Window Not Found.",2)
        Log("ERROR", "RPCS3 Window Not Found.")
        SB_SetText("RPCS3 Window Not Found.", 2)
        return
    }

    ; 3 Get HWND, bring to front (optional)
    WinGet, hwnd, ID, ahk_exe rpcs3.exe
    WinActivate, ahk_id %hwnd%
    WinWaitActive, ahk_id %hwnd%,, 2

    ; 4 Window metrics
    WinGetPos, X, Y, W, H, ahk_id %hwnd%
    WinGet, winStyle, Style, ahk_id %hwnd%
    WinGet, winExStyle, ExStyle, ahk_id %hwnd%

    ; ── log Debug Info exactly as requested ──
    info := "Debug Info:`n`n"
    info .= "Window Handle: " hwnd "`n`n"
    info .= "Position: X" X " Y" Y "`n`n"
    info .= "Size: " W "x" H "`n`n"
    info .= "Style: " winStyle "`n`n"
    info .= "ExStyle: " winExStyle "`n`n"
    Log("DEBUG", info)

    ; 5 Adjust for negatives (multi-monitor)
    if (X < 0 || Y < 0) {
        SysGet, mCount, MonitorCount
        Loop, %mCount% {
            SysGet, Mon, Monitor, %A_Index%
            if (X >= MonLeft && X < MonRight && Y >= MonTop && Y < MonBottom) {
                ; nothing to fix – coords already absolute
                break
            }
        }
    }

    ; 6 Start GDI+
    if !(pToken := Gdip_Startup()) {
        ; CustomTrayTip("GDI+ init failed.",2)
        Log("ERROR", "GDI+ failed to initialise.")
        SB_SetText("GDI+ init failed.", 2)
        return
    }

    ; 7 Capture RPCS3 window
    pBitmap := Gdip_BitmapFromScreen(X "|" Y "|" W "|" H)
    if !pBitmap {
        Log("ERROR", "Screen capture failed. hwnd=" . hwnd)
        ; CustomTrayTip("Screen capture failed (see log).",2)
        SB_SetText("Screen capture failed.", 2)
        Gdip_Shutdown(pToken)
        return
    }

    ; 8 Screenshot format from INI
    IniRead, ShotFormat, %iniFile%, Settings, ScreenshotFormat, png
    ShotFormat := (ShotFormat = "jpg") ? "jpg" : "png"

    ; 9 Ensure screenshots folder exists
    ScreenshotDir := A_ScriptDir "\rpcl3_screenshots"
    FileCreateDir, %ScreenshotDir%

    ; 10 File name  GameID_YYYY-MM-DD_HH-MM-SS.ext
    FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
    filePath := ScreenshotDir "\" GameID "_" ts "." ShotFormat

    ; 11 Save bitmap
    result := Gdip_SaveBitmapToFile(pBitmap, filePath)
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)

    if (result) {                     ; non-zero = error
        Log("ERROR", "Save failed. Code=" . result . " Path=" . filePath)
        ; CustomTrayTip("Failed to save screenshot! Code " . result,2)
        SB_SetText("Screenshot save failed.", 2)
    } else {
        Log("DEBUG", "Screenshot taken: " . filePath)
        SB_SetText("Screenshot saved: " . filePath, 2)
        Run, %ScreenshotDir%
    }
    return
}

; ─── Video capture. ────────────────────────────────────────────────────────────────────
VideoCaptureLabel:
if !ProcessExist("rpcs3.exe") {
    ; CustomTrayTip("Cannot Record, RPCS3 is not running.", 3)
    return
}

if !recording
{
    ;── output paths & audio device ────────────────────────────
    FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
    FileCreateDir, %A_ScriptDir%\rpcl3_captures
    outFile  := A_ScriptDir "\rpcl3_captures\rpcs3_video_" ts ".mp4"
    audioDev := "CABLE Output (VB-Audio Virtual Cable)"

    ;── FIX: set default FPS ──────────────────────────────────
    if (fps = "")
    {
        ; CustomTrayTip("Missing Framerate, Framerate (fps) is not defined. Defaulting to 30.", 2)
        Log("WARNING", "Missing Framerate, Framerate (fps) is not defined. Defaulting to 30.")
        SB_SetText("Missing Framerate, Framerate (fps) is not defined. Defaulting to 30.", 2)
        fps := 30
    }

monLeft := 0
monTop := 0
monWidth := 1920
monHeight := 1080

RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Input" 1, , Hide
RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Output" 1, , Hide
; CustomTrayTip("Audio output set to CABLE Input, audio input set to CABLE Output.", 1)
Sleep, 1500

audioDev := "CABLE Output (VB-Audio Virtual Cable)"

RotateFfmpegLog(5, 1024*1024)  ; Keep 5 logs, max 1 MB per log
logfile := A_ScriptDir . "\rpcl3_ffmpeg.log"

ffArgs := " -f gdigrab -framerate " fps
         . " -offset_x " monLeft
         . " -offset_y " monTop
         . " -video_size " monWidth "x" monHeight
         . " -i desktop"
         . " -f dshow -i audio=""" audioDev """"
         . " -c:v libx264 -preset ultrafast -crf 18"
         . " -c:a aac -b:a 192k"
         . " -pix_fmt yuv420p"
         . " -async 1 -bufsize 512k"
         . " -movflags +faststart"
         . " """ . outFile . """"

fullCmd := ffmpegExe . ffArgs . " >> """ . logfile . """ 2>&1"

Run, %ComSpec% /c "%fullCmd%", , Hide, ffmpegPID


ffArgs := " -f gdigrab -framerate " fps
         . " -offset_x " monLeft
         . " -offset_y " monTop
         . " -video_size " monWidth "x" monHeight
         . " -i desktop"
         . " -f dshow -i audio=""" audioDev """"
         . " -c:v libx264 -preset ultrafast -crf 18"
         . " -c:a aac -b:a 192k"
         . " -pix_fmt yuv420p"
         . " -async 1 -bufsize 512k"
         . " -movflags +faststart"
         . " """ . outFile . """"

    Run, % ffmpegExe . ffArgs, , Hide, ffmpegPID
    ;Run, % fullCmd, , , ffmpegPID
    fullCmd := ffmpegExe " " ffArgs
    Log("DEBUG", "FFmpeg command: " . fullCmd)
    ; CustomTrayTip("Debug FFmpeg Args: " fullCmd, 1)
    Log("DEBUG", "FFmpeg capture area: " W "x" H " at (" X "," Y ")")

    if ffmpegPID {
        recording := true
        GuiControl, +cFFCC66, VideoCaptureLabel
    } else {
        MsgBox, 48, Error, Could not start FFmpeg.
        return
    }
}
else
{
    if ffmpegPID
        ;Process, Close, %ffmpegPID%
        ControlSend,, q, ahk_pid %ffmpegPID%.

    recording := false
    GuiControl, +c808080, VideoCaptureLabel
    ; CustomTrayTip("Recording Stopped, Saved to: " outFile, 1)
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    ; CustomTrayTip("Audio output set to default", 1)
}
return

; ─── Audio capture function. ────────────────────────────────────────────────────────────────────
AudioCaptureLabel:

; Prompt the user to confirm audio device setup
MsgBox, 52, Warning, Did you set the audio devices (CABLE Input/Output)?
IfMsgBox No
{
    ; Kill RPCS3 and exit
    Process, Close, rpcs3.exe
    MsgBox, 48, Info, RPCS3 was closed because it must use the correct audio devices.
    return
}
; If user clicks Yes, continue recording setup

if !ProcessExist("rpcs3.exe") {
    CustomTrayTip("Cannot Record, RPCS3 is not running.", 1)
    return
}

    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Input" 1, , Hide
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Output" 1, , Hide

    CustomTrayTip("Audio output set to CABLE Input, audio input set to CABLE Output.", 1)
    Sleep, 1500

    if !recording
    {
        FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
        FileCreateDir, %A_ScriptDir%\rpcl3_recordings
        outFile := A_ScriptDir "\rpcl3_recordings\rpcs3_audio_" ts ".wav"
        audioDevice := "CABLE Output (VB-Audio Virtual Cable)"

        ffArgs := "-f dshow -i audio=""" audioDevice """ -acodec pcm_s16le -ar 48000 -ac 2 """ outFile """"
        Run, % ffmpegExe " " ffArgs, , , ffmpegPID

    if ffmpegPID {
        recording := true
        GuiControl, +cFFCC66, AudioCaptureLabel
    } else {
        MsgBox, 48, Error, Could not start FFmpeg.
        return
    }
}
else
{
    if ffmpegPID
        Process, Close, %ffmpegPID%
        ControlSend,, q, ahk_pid %ffmpegPID%.

    recording := false
    GuiControl, +c808080, AudioCaptureLabel
    CustomTrayTip("Recording Stopped, Saved to: " . outFile, 1)
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    CustomTrayTip("Audio output set to default", 1)

    ; Get bitrate
    ; Get file size (in bytes)
    FileGetSize, fileSizeBytes, %outFile%

    ; Use FFmpeg to get duration
    ffmpegOutput := A_ScriptDir . "\ffmpeg_output.txt"
    RunWait, %ComSpec% /c ""%ffmpegExe%" -i "%outFile%" 2> "%ffmpegOutput%"", , Hide

    ; Read duration from FFmpeg output
    FileRead, ffOut, %ffmpegOutput%
    RegExMatch(ffOut, "Duration: (\d+):(\d+):(\d+)", d)
    if (d1 != "" && d2 != "" && d3 != "") {
        totalSeconds := d1 * 3600 + d2 * 60 + d3
        bitrate := Round((fileSizeBytes * 8) / (totalSeconds * 1000)) . " kbps"
    } else {
        bitrate := "Unknown"
    }

    ; Optional: delete temporary ffmpeg output file
    FileDelete, %ffmpegOutput%

    Run, %FileCreateDir%
}
return


PrepareRecordingLabel:
if !FileExist("nircmd.exe") {
    MsgBox, 16, Error, nircmd.exe not found!
    return
}

if (!audioPrepared) {
    ; Prepare for recording
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Input" 1, , Hide
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Output" 2, , Hide
    ShowCustomMsgBox("Ready", "Recording devices set.`nLaunch RPCS3 and hit record.", 500, 300)
    Log("INFO", "Audio devices switched: Output = CABLE Input, Input = CABLE Output")
    audioPrepared := true
} else {
    ; Revert to default
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Microphone" 2, , Hide
    CustomTrayTip("Audio output/input set to default.", 1)
    Log("INFO", "Audio devices reverted to default.")
    audioPrepared := false
}
return


; ─── Rotate logs function. ────────────────────────────────────────────────────────────────────
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


; ─── Process exists. ────────────────────────────────────────────────────────────────────
ProcessExist(name) {
    Process, Exist, %name%
    return ErrorLevel
}


; ─── Download to file. ────────────────────────────────────────────────────────────────────
URLDownloadToFile(url, filePath) {
    return DllCall("URLMon.dll\URLDownloadToFile", "Ptr", 0, "Str", url, "Str", filePath, "UInt", 0, "Ptr", 0)
}


; ─── Download FFMPEG. ────────────────────────────────────────────────────────────────────
DownloadFFMPEGLabel:
{
    FFmpegZip := A_ScriptDir "\ffmpeg-release-essentials.zip"
    FFmpegFolder := A_ScriptDir "\tools"
    FFMPEG_EXE_FOLDER := FFmpegFolder "\tools\ffmpeg.exe"

    if FileExist(FFMPEG_EXE_FOLDER) {
        MsgBox, 64, Info, FFMPEG is already installed at:`n%FFMPEG_EXE_FOLDER%
        return
    }
    MsgBox, 64, Info, Download will start now. Wait until confirmation dialog for installation to be finished.

    url := "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z"
    res := URLDownloadToFile(url, FFmpegZip)
    if (res != 0) {
        MsgBox, 16, Error, Failed to download FFMPEG. Error code: %res%
        return
    }

    ; Clean old install
    if FileExist(FFmpegFolder)
        FileRemoveDir, %FFmpegFolder%, 1
    FileCreateDir, %FFmpegFolder%

    ; Extract to temp
    tempExtract := FFmpegFolder "\temp"
    FileCreateDir, %tempExtract%
    RunWait, %ComSpec% /c tar -xf "%FFmpegZip%" -C "%tempExtract%",, Hide

    ; Find the extracted version folder (e.g., ffmpeg-7.1.1-essentials_build)
    Loop, Files, %tempExtract%\*, D
    {
        extractedDir := A_LoopFileFullPath
        break
    }

    ; Move files from bin to ffmpeg\
    Loop, Files, %extractedDir%\bin\*.*, F
    {
        FileMove, %A_LoopFileFullPath%, %FFmpegFolder%
    }

    ; Clean up
    FileRemoveDir, %tempExtract%, 1
    FileDelete, %FFmpegZip%
    MsgBox, 64, Success, FFMPEG installed to:`n%FFMPEG_EXE_FOLDER%
}
return


; ─── Add FFMPEG to path. ────────────────────────────────────────────────────────────────────
AddFFMPEGToPathLabel:
    ffmpeg := A_ScriptDir . "\tools\ffmpeg"

    ; Read current user PATH
    RegRead, currPath, HKEY_CURRENT_USER, Environment, PATH

    if InStr(currPath, ffmpeg) {
        MsgBox, 64, Info, ffmpeg path is already in your user PATH.
        return
    }

    ; Append new path safely
    if (currPath != "")
        newPath := currPath . ";" . ffmpeg
    else
        newPath := ffmpeg

    ; Write new PATH
    RegWrite, REG_SZ, HKEY_CURRENT_USER, Environment, PATH, %newPath%
    MsgBox, 64, Success, Added ffmpeg path to user PATH.`nYou may need to restart your shell or log off/on for changes to take effect.
return


; ─── Uninstall FFMPEG. ────────────────────────────────────────────────────────────────────
RemoveFFMPEGLabel:
{
    if FileExist(FFmpegFolder) {
        FileRemoveDir, %FFmpegFolder%, 1
        MsgBox, 64, Success, FFMPEG folder deleted.
    } else {
        MsgBox, 48, Info, FFMPEG not found to remove.
    }
}
return


; ─── Load Games database function call. ────────────────────────────────────────────────────────────────────
LoadGamesDB(jsonFile) {        ; returns cached object or ""
    static cache := ""
    if IsObject(cache)
        return cache
    FileRead, txt, %jsonFile%
    if (SubStr(txt,1,3) = Chr(0xEF) Chr(0xBB) Chr(0xBF))
        txt := SubStr(txt,4)
    try cache := JSON.Load(txt)
    catch
        cache := ""
    return cache
}

; ─── Load Games function ────────────────────────────────────────────────────────────────────
;LoadGamesDB(jsonFile) {
;    FileRead, jsonContent, %jsonFile%
;    if (ErrorLevel) {
;        Log("ERROR", "Failed to read: " . jsonFile)
;        return ""
;    }
;
;    if (SubStr(jsonContent, 1, 3) = Chr(0xEF) Chr(0xBB) Chr(0xBF)) {
;        jsonContent := SubStr(jsonContent, 4)
;        Log("DEBUG", "Stripped BOM from JSON.")
;    }
;
;    try {
;        db := JSON.Load(jsonContent)
;        if (!IsObject(db)) {
;            Log("ERROR", "rpcl3_games_db.json is not a valid object.")
;            return ""
;        }
;        Log("DEBUG", "rpcl3_games_db.json successfully loaded.")
;        return db
;    } catch e {
;        Log("ERROR", "rpcl3_games_db.json parsing failed: " . e.Message)
;        return ""
;    }
;}


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


; ─── Video player. ────────────────────────────────────────────────────────────────────
ShowVideoPlayer:
    Gui, VideoPlayer:New
    Gui, VideoPlayer:+AlwaysOnTop +LabelVideoPlayer
    Gui, VideoPlayer:Color, 24292F
    Gui, VideoPlayer:Font, s10 q5 Bold, Segoe UI Emoji

    videoFolder := A_ScriptDir . "\rpcl3_captures"
    playerWidth := 515
    playerHeight := 355
    title := "RPCL3 Video Player - " . Chr(169) . " " . A_YYYY . " - Philip"

    Gui, VideoPlayer:Add, Progress, x0 y0 w515 h4 0x10 BackgroundFFCC66 Disabled
    Gui, VideoPlayer:Add, ListView, vVideoList gVideoPlayerVideoListClick BackgroundTrans cCCCCCC x0 y1 w515 h100 AltSubmit, Filename|Date Modified
    Gui, VideoPlayer:Font, cCCCCCC s9 q5 bold, Segoe UI Emoji
    Gui, VideoPlayer:Add, Progress,  x0 y99 w515 h1 0x10 BackgroundFFCC66 Disabled
    Gui, VideoPlayer:Add, Text, x0 y100 w95 h23 gVideoPlayerRefreshList BackgroundTrans cCCCCCC +Center +0x200 Border, Refresh
    Gui, VideoPlayer:Add, Text, x95 y100 w95 h23 gVideoPlayerDeleteVideo BackgroundTrans cCCCCCC +Center +0x200 Border, Delete
    Gui, VideoPlayer:Add, Text, x190 y100 w95 h23 gVideoPlayerCopyVideo BackgroundTrans cCCCCCC +Center +0x200 Border, Copy
    Gui, VideoPlayer:Add, Progress, x0 y124 w515 h1 0x10 BackgroundFFCC66 Disabled

    LV_ModifyCol(1, 310)
    LV_ModifyCol(2, 200)

    Gui, VideoPlayer:Add, Progress, x0 y479 w515 h4 0x10 BackgroundFFCC66 Disabled
    Gui, VideoPlayer:Add, ActiveX, x0 y125 w%playerWidth% h%playerHeight% vWMP, WMPlayer.OCX
    WMP.uiMode := "full"
    WMP.stretchToFit := true
    WMP.Enabled := true

    Gosub, VideoPlayerRefreshList
    Gui, VideoPlayer:Show, w515 h482, %title%
return


VideoPlayerRefreshList:
    Gui, VideoPlayer:Default
    LV_Delete()
    Loop, Files, %videoFolder%\*.mp4
    {
        FileGetTime, modified, %A_LoopFileFullPath%, M
        FormatTime, modStr, %modified%, yyyy-MM-dd HH:mm:ss
        LV_Add("", A_LoopFileName, modStr)
    }
return


VideoPlayerVideoListClick:
    if (A_GuiEvent = "DoubleClick") {
        Gui, VideoPlayer:Default
        LV_GetText(selectedFile, A_EventInfo, 1)
        videoPath := videoFolder "\" selectedFile
        if FileExist(videoPath) {
            WMP.URL := videoPath
            WMP.Controls.play()
        } else {
            MsgBox, 48, File Not Found, Could not find:`n%videoPath%
        }
    }
return


VideoPlayerDeleteVideo:
    Gui, VideoPlayer:Submit, NoHide
    Gui, VideoPlayer:ListView, VideoList
    LV_GetText(toDelete, LV_GetNext(), 1)
    if toDelete {
        full := videoFolder "\" toDelete

        ; Get main window position
        WinGetPos, mainX, mainY, mainWidth,, A

        ; Create custom dialog
        Gui, ConfirmDelete:New
        Gui, ConfirmDelete:Add, Text,, Are you sure you want to delete "%toDelete%"?
        Gui, ConfirmDelete:Add, Button, w80 gConfirmDeleteYes Default, &Yes
        Gui, ConfirmDelete:Add, Button, x+10 w80 gConfirmDeleteNo, &No

        ; Position to the right of main window
        dialogX := mainX + mainWidth + 20
        Gui, ConfirmDelete:Show, x%dialogX% y%mainY% Autosize, Confirm Delete
    }
return


ConfirmDeleteYes:
    FileRecycle, %full%
    Gosub, VideoPlayerRefreshList
    Gui, ConfirmDelete:Destroy
return

ConfirmDeleteNo:
    Gui, ConfirmDelete:Destroy
return


VideoPlayerCopyVideo:
    Gui, Submit, NoHide
    Gui, ListView, VideoList
    LV_GetText(toCopy, LV_GetNext(), 1)
    if toCopy {
        global full := videoFolder "\" toCopy

        ; Get main window position
        WinGetPos, mainX, mainY, mainWidth,, A

        ; Calculate dialog position (right of main window)
        dialogX := mainX + mainWidth + 20

        ; Create and show custom dialog
        Gui, CopyDialog:New
        Gui, CopyDialog:Add, Text,, Select target folder to copy to:
        Gui, CopyDialog:Add, Edit, w300 vTargetFolder
        Gui, CopyDialog:Add, Button, w80 gBrowseFolder, &Browse...
        Gui, CopyDialog:Add, Button, w80 x+10 gConfirmCopy Default, &Copy
        Gui, CopyDialog:Add, Button, w80 x+10 gCancelCopy, &Cancel
        Gui, CopyDialog:Show, x%dialogX% y%mainY%, Copy Video
    }
return


BrowseFolder:
    ; Minimize main window temporarily
    WinMinimize, ahk_id %CopyVideoHwnd%

    ; Show browse dialog
    FileSelectFolder, selectedFolder,, 3, Select target folder

    ; Restore main window
    WinRestore, ahk_id %CopyVideoHwnd%
    WinActivate, ahk_id %CopyVideoHwnd%

    if selectedFolder
    {
        GuiControl,, TargetFolder, %selectedFolder%
    }
return


ConfirmCopy:
    Gui, Submit
    if (TargetFolder != "")
    {
        FileCopy, %full%, %TargetFolder%\%toCopy%
    }
    Gui, CopyDialog:Destroy
return


CancelCopy:
    Gui, CopyDialog:Destroy
return


ShowCustomMsgBox(title, text, x := "", y := "") {
    Gui, MsgBoxGui:New, +AlwaysOnTop +ToolWindow, %title%
    Gui, MsgBoxGui:Add, Text,, %text%
    Gui, MsgBoxGui:Add, Button, gCloseCustomMsgBox Default, OK

    ; Auto-position if x/y provided
    if (x != "" && y != "")
        Gui, MsgBoxGui:Show, x%x% y%y% AutoSize
    else
        Gui, MsgBoxGui:Show, AutoSize Center
}


CloseCustomMsgBox:
    Gui, MsgBoxGui:Destroy
return


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

GuiClose:
    Gui, VideoPlayer:Destroy
    SoundPlay, *-1
    ExitApp
return