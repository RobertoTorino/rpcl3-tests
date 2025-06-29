;YouTube: @game_play267
;Twitch: RR_357000
;X:@relliK_2048
;Discord:
;Launcher for RPCS3

#Include %A_ScriptDir%\tools\JSON.ahk
#Include, %A_ScriptDir%\tools\Gdip.ahk
#SingleInstance off
#Persistent
#NoEnv
DetectHiddenWindows On
SendMode Input
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
SetTitleMatchMode, 2

; =============== CALL THIS ONCE RIGHT AFTER THE #INCLUDE SECTION.
EnsureRPCS3Path()

; =============== REFRESH PATH.
RefreshRPCS3Path()

;===============
;Setup OnExit handler for saving settings
OnExit("SaveSettings")

;=====================================
logInterval := 120000   ; Set logging interval to 5 seconds
lastResourceLog := 0  ; Initialize first log immediately

;=============== NEEDED FOR RPCS3 PATH. ======================================================
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

;=============== TRY TO DISCOVER RPCS3.EXE IN RPCL3_GAMES_DB.JSON (ONE PASS, FIST MATCH) RETURNS "" ON FAILURE
DiscoverRPCS3FromJSON()
{
    local jsonFile := A_ScriptDir "\rpcl3_games_db.json"

    if !FileExist(jsonFile)
        return ""

    FileRead, raw, %jsonFile%
    if ErrorLevel
        return ""

    db := JSON.Load(raw)
    for _, game in db
    {
        loader := TrimQuotesAndSpaces(game.Properties.Loader)
        if (loader = "")
            continue

        ; If Loader is just "rpcs3.exe", make it absolute (= script dir)
        if !RegExMatch(loader, "^[A-Z]:\\|^\\\\")
            loader := A_ScriptDir "\" loader

        if FileExist(loader)
            return loader
    }
    return ""
}

; ─── GLOBALS. ────────────────────────────────────────────────────────────────────
global RPCS3_UpdateAPI := "https://update.rpcs3.net/?api=v2"
global RPCS3_LatestAPI := "https://api.github.com/repos/RPCS3/rpcs3-binaries-win/releases/latest"
gDestinationHomeDiscordURL := "https://discord.com/channels/621722473695805450/@home"
RPCS3_YouTubeURL := "https://www.youtube.com/c/RPCS3_emu/videos"
RPCS3_DestinationHomeURL := "https://web.destinationhome.live/"
updateURL := "https://www.playstation.com/en-us/support/hardware/ps3/system-software/#:~:text=Do%20not%20perform%20updates%20using,install%20the%20official%20update%20data."
rpcs3URL := "https://rpcs3.net/download"
grpcs3ForumURL := "https://forums.rpcs3.net/"
rpcs3WiKiURL := "https://wiki.rpcs3.net/index.php?title=Main_Page"
discordURL := "https://discord.com/invite/RPCS3"
vbCableDownloadURL = "https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip"
downloadNircmdURL := "https://www.nirsoft.net/utils/nircmd.zip"

; ─── CONFIG ────────────────────────────────────────────────────────────────────

baseDir         := A_ScriptDir
rpcs3Path       := GetRPCS3Path()
iniFile         := A_ScriptDir  . "\rpcl3.ini"
logFile         := A_ScriptDir  . "\rpcl3.log"
fallbackLog     := A_ScriptDir  . "\rpcl3_fallback.log"
noImage         := A_ScriptDir  . "\rpcl3_no_image_found.png"
FFmpegFolder    := A_ScriptDir  . "\ffmpeg\"
FFMPEG_EXE      := FFmpegFolder . "ffmpeg.exe"
FFmpegZip       := A_ScriptDir  . "\ffmpeg-release-essentials.zip"
FFmpegBin       := FFmpegFolder . "\bin"
jsonFile        := A_ScriptDir  . "\rpcl3_games_db.json"
ffmpegExe       := "ffmpeg\ffmpeg.exe"
recording       := false
ffmpegPID       := 0
lastPlayed      := ""
ffplayPID       := 0

;=============== SAVE SCREEN SIZE.
IniRead, SavedSize, %iniFile%, SIZE_SETTINGS, SizeChoice, 1920x1080
SizeChoice := SavedSize
selectedControl := sizeToControl[SavedSize]
for key, val in sizeToControl {
    label := (val = selectedControl) ? "[" . key . "]" : key
    GuiControl,, %val%, %label%
}
DefaultSize := "1920x1080"
DefaultNudge := 20

;=============== LOAD WINDOW SETTINGS FROM INI.
IniRead, SizeChoice, %iniFile%, SIZE_SETTINGS, SizeChoice, %DefaultSize%
IniRead, NudgeStep, %iniFile%, NUDGE_SETTINGS, NudgeStep, %DefaultNudge%

;=============== SET NUDGE STEP FIELD.
GuiControl,, NudgeStep, %NudgeStep%

;=============== HIGHLIGHT SELECTED NUDGE BUTTON IF VISIBLE.
Loop, 6 {
    step := 10 + (A_Index * 5)  ; 15, 20, 25, ...
    name := "Btn" . step
    label := (step = NudgeStep) ? "[" . step . "]" : step
    GuiControl,, %name%, %label%
}

;=============== CONDITIONALLY SET DEFAULT PRIORITY IF IT'S NOT ALREADY SET.
IniRead, priorityValue, %iniFile%, PRIORITY, Priority
if (priorityValue = "")
    IniWrite, Normal, %iniFile%, PRIORITY, Priority

;=============== READ RPCS3 PATH AND EXTRACT EXECUTABLE NAME IF FOUND.
IniRead, rpcs3Path, %iniFile%, RPCS3, Path
if (rpcs3Path != "") {
    global rpcs3Exe
    SplitPath, rpcs3Path, rpcs3Exe
}

;=============== LOAD LAST PLAYED GAME ID AND TITLE WITH SAFE DEFAULTS
IniRead, lastGameID, %iniFile%, LAST_PLAYED, GameID, UnknownID
IniRead, lastGameTitle, %iniFile%, LAST_PLAYED, GameTitle, Unknown Title

;=============== RUNS A COMMAND AND RETURNS THE OUTPUT EXAMPLE: "RPCS3.EXE --VERSION", CALL IT WITH "GETCOMMANDOUTPUT".
GetCommandOutput(cmd) {
    tmpFile := A_Temp "\cmd_output.txt"
    RunWait, %ComSpec% /c %cmd% > "%tmpFile%" 2>&1,, Hide
    FileRead, output, %tmpFile%
    FileDelete, %tmpFile%
    return Trim(output)
}

;=============== SET AS ADMIN.
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

;=============== SYSTEM INFO.
; Ensure AutoHotkey v1 syntax
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

; Get real screen dimensions for that monitor
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


;==========================================


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

;===============
IniRead, gameCount, %iniFile%, GAMES_FOUND, Count, 0

;=============== 🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮🎮
title := "RPCS3 Priority Control Launcher 3 - " . Chr(169) . " " . A_YYYY . " - Philip"
Gui, Show, w1040 h680, %title%
tab1 := Chr(128377) . " MANAGE RPCS3"
tab2 := Chr(127760) . " VIDEO"
Gui, +AlwaysOnTop

Gui, Add, Tab, x0 y0 w1040 h682 Background24292F, %tab1%|%tab2%

;Gui, +LastFound +OwnDialogs +ToolWindow
Gui, Color, 24292F
Gui, Font, Segoe UI Emoji

Gui, Tab, 1
GuiControl,, NudgeStep, %lastNudge%
highlight := "Btn" . lastNudge
;GuiControl, +BackgroundFF6600, %highlight%
;/////////////////////////////////////// ROW 1  ////////////////////////////////////////////////////////////////////////
Gui, Font, s11 bold q5
Gui, Add, Text,                          x10 y32 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x134 y32 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x258 y32 w238 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x506 y32 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x630 y32 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x754 y32 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x878 y32 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,  x10 y35 w114 h30 cFFCC66 +Center +0x200 BackgroundTrans, RUN GAME
Gui, Add, Text,           x134 y35 w114 h30 cFFCC66 +Center +0x200 BackgroundTrans, EBOOT.BIN
Gui, Add, Button, vPriorityLabel        x258 y35 w238 h30 cFFCC66 +Center +0x200, SELECT PROCESS PRIORITY
Gui, Add, DropDownList, vPriorityChoice x258 y65 w238 r6, Idle|Below Normal|Normal|Above Normal|High|Realtime
LoadSettings()
Gui, Add, Button, gSetPriority          x258 y106 w238 h30 cFFCC66 +Center +0x200 Border, SET PROCESS PRIORITY
Gui, Add, Text,                         x506  y42 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, VIEW`nCONFIG
Gui, Add, Text,                         x630  y42 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, REFRESH`nRPCS3 PATH
Gui, Add, Text,                         x754  y35 w114 h30 cFFCC66 +Center +0x200 BackgroundTrans, FIND RPCS3
Gui, Add, Text,                         x878  y35 w114 h30 cFFCC66 +Center +0x200 BackgroundTrans, START RPCS3
Gui, Font, s60 bold q51
Gui, Add, Text, vRunGame gRunRPCS3GameLabel       x21 y35 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F3AE)
Gui, Add, Text, gSetEbootBinPathLabel   x148 y43 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F5C1)
Gui, Font, s52 bold q51
Gui, Add, Text, gViewConfigLabel        x534 y49 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x26EE)
Gui, Font, s60 bold q51
Gui, Add, Text, gRefreshPath            x654 y47 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F5D8)
Gui, Add, Text, gSetRpcs3Path           x768 y43 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F5C1)
Gui, Font, s64 bold q51
Gui, Add, Text, gRunRPCS3Label          x901 y42 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F5B3)

;/////////////////////////////////////// ROW 2  ////////////////////////////////////////////////////////////////////////

Gui, Font, s11 bold q5
Gui, Add, Text,                          x10 y150 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x134 y150 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x258 y150 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x382 y150 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x506 y150 w362 h106 +Center +0x100 Border BackgroundTrans
Gui, Add, Text,                         x878 y150 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                          x10 y161 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, DOWNLOAD`n RPCS3
Gui, Add, Text,                         x134 y161 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, DOWNLOAD`nFW 4.92
Gui, Add, Text,                         x258 y161 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, INSTALL`nFIRMWARE
Gui, Add, Text,                         x382 y161 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, INSTALL`n.pkg .rap .edat
Gui, Add, Text,                         x506 y161 w358 h100 cFFCC66 +Center +0x100 BackgroundTrans,
Gui, Add, Text,                         x878 y161 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, REFRESH`nGUI
Gui, Font, s60 bold q51
Gui, Add, Text, gDownloadRPCS3           x51 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x2B73)
Gui, Add, Text, gDownloadFirmware       x162 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x21CA)
Gui, Add, Text, gInstallfirmware        x285 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x25F0)
Gui, Add, Text, gInstallPkg             x408 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x25F1)
Gui, Font, s11 bold q5
Gui, Add, Text, vGameCount gRefreshGameCount x510 y159 w350 cFFCC66 +Center +0x100, % Chr(0x1F3AE) . " Games Found (Click to Refresh): " . gameCount
Gui, Font, s60 bold q51
Gui, Add, Text, gRefreshGui             x903 y167 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F5D8)
Gui, Add, Progress,                       x0 y265 w1002 h1 0x10 BackgroundcCCCCCC cCCCCCC Disabled

;/////////////////////////////////////// ROW 3  ////////////////////////////////////////////////////////////////////////

Gui, Font, s11 bold q5
Gui, Add, Text,                          x10 y274 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x134 y274 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x258 y274 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                         x382 y274 w114 h106 +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                          x10 y278 w114 h30 cFFCC66 +Center +0x200 BackgroundTrans, MONITOR 1|2
Gui, Add, Text,                         x134 y278 w114 h30 cFFCC66 +Center +0x200 BackgroundTrans, SCREENSHOT
Gui, Add, Text,                         x258 y285 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, VIDEO`nCAPTURE
Gui, Add, Text,                         x382 y285 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, AUDIO`nCAPTURE
Gui, Font, s80 bold q51
Gui, Add, Text, gMoveToMonitor           x24 y273 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x239A)
Gui, Font, s56 bold q51
Gui, Add, Text, gTakeScreenshotLabel    x146 y280 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F4F8)
Gui, Font, s56 bold q51
Gui, Add, Text, gVideoCaptureLabel      x270 y284 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F4F9)
Gui, Add, Text, gAudioCaptureLabel      x395 y291 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F50A)
;-----------------------------------------------------------------------------------------------------------------------
Gui, Font, s11 bold q5
;Gui, Add, Text,                 x200 y167 w60  h30 cFFCC66 +0x200 BackgroundTrans, % " Position:"
;Gui, Add, Text, gNudgeLeft      x273 y167 w30  h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % "L"
;Gui, Add, Text, gNudgeRight     x315 y167 w30  h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % "R"
;Gui, Add, Text, gNudgeUp        x358 y167 w30  h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % "U"
;Gui, Add, Text, gNudgeDown      x402 y167 w30  h30 cFFCC66 +Center +0x200 Border BackgroundTrans, % "D"
;Gui, Add, Text,                     X460 y167 h30 cFFCC66 +Center +0x200, Nudge Steps (in Pixels):
;Gui, Add, Text, vBtn5 gSetNudge     x632 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 5
;Gui, Add, Text, vBtn10 gSetNudge    x674 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 10
;Gui, Add, Text, vBtn15 gSetNudge    x714 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 15
;Gui, Add, Text, vBtn20 gSetNudge    x755 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 20
;Gui, Add, Text, vBtn25 gSetNudge    x797 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 25
;Gui, Add, Text, vBtn30 gSetNudge    x838 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 30
;Gui, Add, Text, vBtn35 gSetNudge    x879 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 35
;Gui, Add, Text, vBtn40 gSetNudge    x920 y167 w30 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 40
;Gui, Add, Edit, vNudgeStep x800 y162 w50 h30 hidden, 20
;IniRead, lastNudge, %iniFile%, NUDGE_SETTINGS, NudgeStep, 20
;-----------------------------------------------------------------------------------------------------------------------
;Gui, Add, Text,                                 x10 y205 w60 h30 cFFCC66 +0x200 BackgroundTrans, % " Set Size:"
;;Gui, Add, Text, vSize800        gSetSizeChoice  x80 y205 w80 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 800x600
;Gui, Add, Text, vSize1024       gSetSizeChoice x170 y205 w90 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 1024x768
;Gui, Add, Text, vSize1280       gSetSizeChoice x270 y205 w90 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 1280x720
;Gui, Add, Text, vSize1920       gSetSizeChoice x370 y205 w90 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 1920x1080
;Gui, Add, Text, vSize2560       gSetSizeChoice x470 y205 w100 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, 2560x1440
;Gui, Add, Text, vSizeFull       gSetSizeChoice x580 y205 w90 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, FullScreen
;Gui, Add, Text, vSizeWindowed   gSetSizeChoice x680 y205 w90 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Windowed
;Gui, Add, Text, vSizeHidden     gSetSizeChoice x780 y205 w90 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Hidden
;Gui, Add, Text, gResetDefaults                 x880 y205 w70 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Reset
;-----------------------------------------------------------------------------------------------------------------------
;Gui, Add, Text, gDownloadFFMPEGLabel    x370 y243 w200 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Download/Install FFMPEG
;Gui, Add, Text, gAddFFMPEGToPathLabel   x580 y243 w180 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Add FFMPEG to PATH
;Gui, Add, Text, gRemoveFFMPEGLabel      x770 y243 w180 h30 cFFCC66 +Center +0x200 Border BackgroundTrans, Remove FFMPEG
;Install Vrtual Audio Cable
Gui, Add, Progress, x0 y389 w1000 h1 0x10 BackgroundcCCCCCC cCCCCCC Disabled

;/////////////////////////////////////// ROW 4  ////////////////////////////////////////////////////////////////////////

Gui, Font, s11 bold q5
Gui, Add, Text,      x10 y400 w114 h106         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,     x134 y400 w114 h106         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,     x258 y400 w486 h222         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,     x756 y400 w114 h106         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,      x10 y472 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, VERSION
Gui, Add, Text,     x134 y472 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, HELP
global noImage
;icon := A_ScriptDir . "\games\Ridge Racer 7 [BLUS30001]\PS3_GAME\ICON0.PNG"
Gui, Add, Picture,  x258 y400 +BackgroundTrans vGameIcon
if (found)
    hbm := LoadPicture(iconPath, "GDI+ h222")
else
hbm := LoadPicture(noImage, "GDI+ h222")
GuiControl,, GameIcon, HBITMAP:%hbm%
Gui, Add, Text,                  x756 y472 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, VIEW LOGS
Gui, Add, Picture, gAbout        x888 y408 w90 h90 vRPCL3Icon, rpcl3_default_256_dark.png
Gui, Font, s72 q5
Gui, Add, Text, gShowVersionLabel x31 y382 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F6C8)
Gui, Font, s56 q5
Gui, Add, Text, gShowHelpLabel x150 y382 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x2753)
Gui, Font, s56 q5
Gui, Add, Text, gViewLog         x770 y382 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F56E)

;/////////////////////////////////////// ROW 5  ////////////////////////////////////////////////////////////////////////

Gui, Font, s11 bold q5
Gui, Add, Text,                   x10 y516 w114 h106         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                  x134 y516 w114 h106         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                  x756 y516 w114 h106         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                  x880 y516 w114 h106         +Center +0x200 Border BackgroundTrans
Gui, Add, Text,                   x10 y590 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, CLOSE RPCS3
Gui, Add, Text,                  x134 y590 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, SYSTEM INFO
Gui, Add, Text,                  x756 y590 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, CLEAR LOGS
Gui, Add, Text,                  x880 y590 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, CLOSE RPCL3
Gui, Font, s64 bold q5
Gui, Add, Text, gCloseRpcs3Label  x30 y500 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x23FB)
Gui, Font, s48 bold q5
Gui, Add, Text, gSystemInfoLabel x155 y500 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x2139)
Gui, Add, Text, gClearLog        x775 y500 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x274C)
Gui, Font, s64 bold q5
Gui, Add, Text, gExitAhkLabel    x900 y500 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x23FB)
Gui, Add, Progress, x0 y632 w1000 h1 0x10 BackgroundcCCCCCC cCCCCCC Disabled
;/////////////////////////////////////// STATUS BAR  ////////////////////////////////////////////////////////////////////////
; ============== custom statusbar 1 is used for RPCS3 status use 2 and 3.
Gui, Font, cCCCCCC s10.5 regular norm q5, Segoe UI Emoji
;Gui, Add, Progress, x0 y576 w1002 h1 0x10 cCCCCCC Disabled
Gui, Add, Text, vCurrentPriority  x10 y635 w180,
Gui, Add, Text, vVariableText2   x200 y635 w180 cCCCCCC, [GAME_ID]
Gui, Add, Text, vVariableText3   x390 y635 w652 BackgroundTrans, [GAME_TITLE]
;=============== function to update segment for the bottom statusbar, 1 is reserved for process priority status, use 2.
Gui, Add, StatusBar, vStatusBar1 hWndhStatusBar
SB_SetParts(345, 665)
UpdateStatusBar(msg, segment := 1) {
    SB_SetText(msg, segment)
}
;=============== update gui controls for last game in the custom statusbar. -------------------------------------------------------
;idText := "LAST_PLAYED: " . (lastGameID != "" ? lastGameID : "NoData")
;GuiControl,, VariableText2, %idText%

Log("DEBUG", "Updated VariableText2 with: " . idText)

titleText := (lastGameTitle != "" ? lastGameTitle : "NoData")
GuiControl,, VariableText3, %titleText%

Log("DEBUG", "Updated VariableText3 with: " . titleText)

;=============== start timers for cpu/memory every x second(s). ------------------------------------------
SetTimer, UpdateCPUMem, 1000

;=============== force one immediate priority update.
Gosub, UpdatePriority

;=============== start priority timer after a delay (3s between updates), runs every 3 seconds.
SetTimer, UpdatePriority, 3000

;=============== record timestamp of last update.
FormatTime, timeStamp, , yyyy-MM-dd HH:mm:ss
Log("DEBUG", "Writing Timestamp " . timeStamp . " to " . iniFile)
IniWrite, %timeStamp%, %iniFile%, GAMES_FOUND, LastUpdated

;=====================================================================
;Gui, Tab, 2
;
;; Add this inside your GUI Tab 2 section
;Gui, Tab, 2
;Gui, Add, Text,, Captured Videos:
;Gui, Add, ListView, vVideoList gVideoListClick w500 h250 Grid, Filename|Date
;
;Gui, Add, Button, gPlayVideoFromList, ▶️ Play
;Gui, Add, Button, x+10 gDeleteVideo, 🗑️ Delete
;Gui, Add, Button, x+10 gCopyVideo, 📄 Copy
;
;; Optional preview image
;Gui, Add, Picture, vVideoPreview w300 h170 Border
;
;Gosub, RefreshVideoList
;
;Gui, Tab  ; Leave tab section
;
;LoadCapturedVideos()
;
;return  ; End of auto-execute section

;;/////////////////////////////////////// ROW 1  ////////////////////////////////////////////////////////////////////////

;Gui, Font, s11 bold q5
;Gui, Add, Text,                          x10 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                         x134 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                         x258 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                         x382 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                         x506 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                         x630 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                         x754 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                         x878 y32 w114 h106 +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                          x10 y161 w114 h40 cFFCC66 +Center +0x100 BackgroundTrans, TEST
;Gui, Font, s60 bold q5
;Gui, Add, Text,            x51 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x2B73)
;
;;/////////////////////////////////////// ROW 2  ////////////////////////////////////////////////////////////////////////
;
;Gui, Font, s11 bold q5
;Gui, Add, Text,                   x10 y150 w114 h106         +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                  x134 y150 w114 h106         +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                  x258 y150 w114 h106         +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                  x382 y150 w114 h106         +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                  x506 y150 w114 h106         +Center +0x200 Border BackgroundTrans
;Gui, Add, Text,                   x10 y164 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, RPCS3
;Gui, Add, Text,                  x134 y164 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, RPCS3 WIKI
;Gui, Add, Text,                  x258 y164 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, RPCS3 DISCORD
;Gui, Add, Text,                  x382 y164 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, DESTINATION HOME
;Gui, Add, Text,                  x506 y164 w114 h30  cFFCC66 +Center +0x200 BackgroundTrans, RPCS3 YOUTUBE
;Gui, Font, s52 q5
;Gui, Add, Text, gRpcs3Web         x20 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F310)
;Gui, Add, Text, gRpcs3Wiki       x144 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F310)
;Gui, Add, Text, gRpcs3Discord    x268 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F310)
;Gui, Add, Text, gPsHomeWeb       x392 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F310)
;Gui, Add, Text, RPCS3YouTube     x516 y164 w120 h104 cFFCC66 +Left +0x200 BackgroundTrans, % Chr(0x1F310)
;;===============================
Gui, Tab  ; End tab section

;=============== TODO
;=============== SYSTEM TRAY MENU OPTIONS.
;Menu, Tray, NoStandard                       ;Remove default items like "Pause Script"
;Menu, Tray, Add, Exit, ExitScript            ;Add Exit
Menu, Tray, Add, Show GUI, ShowGui           ;Add a custom "Show GUI" option
Menu, Tray, Add                              ;Add a separator line
Menu, Tray, Add, About RPCL3..., ShowAboutDialog
Menu, Tray, Default, Show GUI                ;Make "Show GUI" the default double-click action

Menu, Tray, Tip, RPCS3 Priority Control Launcher 3    ;Tooltip when hovering
;Menu, Tray, Show
return
;///////////// THIS RETURN ENDS ALL UPDATES TO THE GUI. ////////////////////////////////////////////////////////////////
;return

HoverHandler:
    return  ; needed to avoid accidental clicks triggering action

; Track mouse movement
SetTimer, WatchHover, 100
return

WatchHover:
    MouseGetPos, , , winID, ctrlID
    GuiControlGet, ctrlName, Name, %ctrlID%
    if (ctrlName = "RunGame") {
        ToolTip, 🎮 Launch RPCS3 with selected game
    } else {
        ToolTip
    }
return

;;=============== CALL THIS ONCE RIGHT AFTER THE #INCLUDE SECTION.
;EnsureRPCS3Path()
;
;;=============== REFRESH PATH.
;RefreshRPCS3Path()

;=============== ENSURE WE ALWAYS END UP WITH A VALID RPCS3PATH (OR "" IF NONE)
EnsureRPCS3Path()
{
    global rpcs3Path, rpcs3Exe
    static iniFile := A_ScriptDir "\rpcl3.ini"

    ; xisting INI logic
    IniRead, rpcs3Path, %iniFile%, RPCS3, Path
    rpcs3Path := Trim(rpcs3Path, "`" " ")

    if (rpcs3Path != "" && FileExist(rpcs3Path))
    {
        SplitPath, rpcs3Path, rpcs3Exe
        return rpcs3Path
    }

    ; nothing (or invalid) in INI – try JSON once
    jsonPath := DiscoverRPCS3FromJSON()
    if (jsonPath != "")
    {
        IniWrite, %jsonPath%, %iniFile%, RPCS3, Path
        rpcs3Path := jsonPath
        SplitPath, rpcs3Path, rpcs3Exe
        CustomTrayTip("Auto-Detected RPCS3 Path from rpcl3_games_db.json.", 3)
        Log("INFO", "Auto-detected RPCS3 path: " . jsonPath)
        return rpcs3Path
    }

    ; still nothing – just warn (no selector here)
    CustomTrayTip("rpcs3.exe Not Found. Please set it manually.", 3)
    Log("WARN", "rpcs3.exe not found. Waiting for manual selection.")
    return ""
}


;=============== FIND GAME LOADER RPCS3.EXE IN JSON.
; Read JSON text from file
FileRead, jsonText, %jsonFile%
if (ErrorLevel) {
    MsgBox, 16, Error, Could not read %jsonFile%.
    ExitApp
}

; Parse JSON
jsonObj := JSON.Load(jsonText)
if (!IsObject(jsonObj)) {
    MsgBox, 16, Error, Failed to parse JSON.
    ExitApp
}

foundLoader := ""

; Loop through all games in jsonObj
for gameId, gameData in jsonObj
{
    if (gameData.HasKey("Properties") && gameData.Properties.HasKey("Loader")) {
        loader := gameData.Properties.Loader
        StringLower, loader, loader

        if (loader = "rpcs3.exe") {
            foundLoader := loader
            foundPath := A_ScriptDir . "\rpcs3.exe"
            SaveRPCS3Path(foundPath)
            break
        }
    }
}

if (foundLoader != "") {
    MsgBox, 64, Found!, Found loader: %foundLoader%
} else {
    MsgBox, 48, Not found, Did not find "rpcs3.exe" in rpcl3_games_db.json
}

;===============
GetGameCount(jsonFile) {
FileRead, jsonContent,  %A_ScriptDir%\rpcl3_games_db.json
    if (ErrorLevel) {
        CustomTrayTip("Failed to read " . jsonPath, 3)
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
        CustomTrayTip("JSON parse error:`n" . e.Message, 3)
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
        CustomTrayTip("Failed to read JSON file:`n" . jsonFile, 3)
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
        CustomTrayTip("Game count refreshed: " . count, 1)

    } catch e {
        CustomTrayTip("JSON parse error:`n" . e.Message, 3)
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
    CustomTrayTip("Current SizeChoice: " . SizeChoice, 1)
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

;=============== REFRESH PATH TO GAMELOADER PCS3.EXE.
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
RPCS3YouTube:
    ;WARNING WITH EXCLAMATION ICON (48) AND 10-SECOND TIMEOUT
    MsgBox, 52, External Link Warning, Attention. This link will take you to an external website.`n`nAre you sure you want to go there?, 7

    ;HANDLE ALL POSSIBLE RESPONSES
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

; ─── Show RPCS3 version function. ────────────────────────────────────────────────────────────────────
About:
    ShowAboutDialog()
    Log("DEBUG", "RPCL3: About dialog window was opened.")
return

; ─── RPCS3 ────────────────────────────────────────────────────────────────────
RPCS3:
return

; ─── Show RPCS3 help function. ────────────────────────────────────────────────────────────────────
ShowHelpLabel:
global rpcs3Path
if (rpcs3Path = "") {
    MsgBox, 0, Error, Path not selected or invalid.
    Log("ERROR", "Path not selected or invalid.")
    return
}
;CHECK IF RPCS3.EXE IS RUNNING
Process, Exist, rpcs3.exe
if (ErrorLevel != 0) {
    MsgBox, 0, RPCS3 is running, RPCS3 is currently running. Kill it to show help?
    Log("WARNING", "Can not show Help if RPCS3 is running.")
    IfMsgBox, No
        return
    Process, Close, rpcs3.exe
    Sleep, 500
}

; Quote the path to handle spaces
helpOutput := GetCommandOutput("""" rpcs3Path """ --help")
if (helpOutput = "") {
MsgBox, 16, Error, Could not retrieve RPCS3 help output.
return
}

Gui, HelpGui:Destroy
Gui, HelpGui:+Resize +MinSize
Gui, HelpGui:Font, s9, Consolas
Gui, HelpGui:Add, Edit, w600 h400 ReadOnly -Wrap, %helpOutput%
Gui, HelpGui:Show,, RPCS3 Help
return

;DISPLAY HELP OUTPUT
MsgBox, %helpOutput%

Gui, HelpGui:Destroy
Gui, HelpGui:+Resize +MinSize
Gui, HelpGui:Font, s9, Consolas
Gui, HelpGui:Add, Edit, w600 h400 ReadOnly -Wrap, %helpOutput%
Gui, HelpGui:Show,, RPCS3 Help
return

HelpRpcl3:
return

; ─── Show RPCS3 version function. ────────────────────────────────────────────────────────────────────
;Version:
;   ShowVersion()
;Return
;
;ShowVersion() {
;   rpcs3Path := GetRPCS3Path()
;   global GetRPCS3Path
;   if (rpcs3Path = "") {
;       MsgBox, 0, Error, Path not selected or invalid.
;       return
;   }
;
;   ;Check if rpcs3.exe is running
;   Process, Exist, rpcs3.exe
;   if (ErrorLevel != 0) {
;       MsgBox, 0, RPCS3 is running, RPCS3 is currently running. Kill it to show version info?
;       IfMsgBox, No
;           return
;       Process, Close, rpcs3.exe
;       Sleep, 500
;   }
;
;   ;Run the --version command
;	versionOutput := GetCommandOutput("rpcs3.exe --version")
;   if (versionOutput = "") {
;		return
;   }
;
;   Gui, VersionGui:Destroy
;   Gui, VersionGui:+Resize +MinSize
;   Gui, VersionGui:Font, s9, Consolas
;   Gui, VersionGui:Add, Edit, w600 h200 ReadOnly -Wrap, %versionOutput%
;   Gui, VersionGui:Show,, RPCS3 Version Info
;}
ShowVersion() {
    rpcs3Path := GetRPCS3Path()
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

    ;Run the --version command
	versionOutput := GetCommandOutput("rpcs3.exe --version")
    if (versionOutput = "") {
		return
    }

    Gui, VersionGui:Destroy
    Gui, VersionGui:+Resize +MinSize
    Gui, VersionGui:Font, s9, Consolas
    Gui, VersionGui:Add, Edit, w600 h200 ReadOnly -Wrap, %versionOutput%
    Gui, VersionGui:Show,, RPCS3 Version Info
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
DownloadRPCS3:
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
    json      := GetUrl("https://api.github.com/repos/RPCS3/rpcs3-binaries-win/releases/latest")
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

        SB_SetText("Path saved: " . selectedPath, 2)
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
    Log("DEBUG", "Saved path to config: " . path)
    CustomTrayTip("Saved Path to config: " . path, 1)
}

rpcs3Path := GetRPCS3Path()
Log("DEBUG", "Saved path to config: " . path)

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

; extract just the exe name if needed elsewhere
SplitPath, rpcs3Path, rpcs3Exe

;TODO
;--- optional help gui ---
Gui, HelpGui:Destroy
Gui, HelpGui:+Resize +MinSize
Gui, HelpGui:Font, s9, Consolas
Gui, HelpGui:Add, Edit, w600 h400 ReadOnly -Wrap, %helpOutput%
Gui, HelpGui:Show,, RPCS3 Help
return

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
    CustomTrayTip("Package installed successfully.", 1)
return

; ─── Set process priority function. ────────────────────────────────────────────────────────────────────
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
    } else {
        CustomTrayTip("RPCS3 not running.", 1)
        Log("WARN", "Attempted to set priority, but RPCS3 is not running.")
        SB_SetText("RPCS3 not running when trying to set priority", 2)
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
        CustomTrayTip("Initial Priority Set to " defaultPriority, 1)

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
    SoundPlay, %A_ScriptDir%\rpcl3_game_over.wav  ; ← plays the sound once
    ;Confirm what we're checking for
    Log("DEBUG", "Checking for process: " . rpcs3Exe)
    Process, Exist, %rpcs3Exe%

    pid := ErrorLevel
    if (pid) {
        KillAllProcesses(pid)  ;Pass PID to function
        CustomTrayTip("Killed all RPCS3 processes.", 2)
        Log("INFO", "Killed all RPCS3 processes (PID: " . pid . ")")
        SB_SetText("Killed all RPCS3 processes.", 2)
    } else {
        CustomTrayTip("No RPCS3 processes running.", 2)
        Log("INFO", "No RPCS3 processes running.")
        SB_SetText("No RPCS3 processes running", 2)
    }

    Gui, Show ;Show or hide GUI but keep script alive
    Menu, Tray, Show  ;Ensure tray icon stays visible
return

;===============
ExitAHKLabel:
    Log("INFO", "Exiting AHK using the Exit button.")
    ExitApp
return

; ─── Set EBOOT.BIN path function. ────────────────────────────────────────────────────────────────────
SetEbootBinPathLabel:
global iniFile
; 1  Ask user for an EBOOT.BIN
FileSelectFile, selectedEboot, 3,, Select EBOOT.BIN, EBOOT.BIN
if (ErrorLevel || !selectedEboot)
    return                                        ; user cancelled
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
; 4  Load games database (cached after first call)
gamesDB := LoadGamesDB(A_ScriptDir . "\rpcl3_games_db.json")
if (!gamesDB) {
    MsgBox, 16, Error, Could not load rpcl3_games_db.json
    return
}
; 5  Determine game title
if (gamesDB.HasKey(gameID))
    gameTitle := gamesDB[gameID].Properties.GameTitle
else
    gameTitle := "Unknown Title"
; 6  Ask user only if we still don’t know ID or title
if (gameID = "UnknownID" || gameTitle = "Unknown Title") {
    InputBox, userGameID, Enter Game ID (9 chars),\nExample: BLUS30001
    if (ErrorLevel || StrLen(userGameID) != 9)
        return
    InputBox, userGameTitle, Enter Game Title
    if (ErrorLevel)
        return
    gameID    := userGameID
    gameTitle := userGameTitle
    ; Save into NEW_GAMES for later curation
    IniWrite, %gameID%,    %iniFile%, NEW_GAMES, GameID
    IniWrite, %gameTitle%, %iniFile%, NEW_GAMES, GameTitle
}
; 7  Persist selected EBOOT and basic info
IniWrite, %selectedEboot%, %iniFile%, RUN_GAME, EbootBinPath
IniWrite, %gameID%,       %iniFile%, LAST_PLAYED, GameID
IniWrite, %gameTitle%,    %iniFile%, LAST_PLAYED, GameTitle
Log("INFO", "Saved EBOOT & game info: " . gameID . " - " . gameTitle)

; 8  Show the cover art & update LAST_PLAYED.IconPath
ShowIconAndRemember(selectedEboot)
return

; after user picks an EBOOT.BIN and you’ve validated the file exists:
FileSelectFile, selectedEboot, 3,, Select EBOOT.BIN, EBOOT.BIN
    if (ErrorLevel || !selectedEboot)
return

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
    IniWrite, %selectedEboot%, %iniFile%, RUN_GAME, EbootBinPath
    IniWrite, %selectedEboot%, %iniFile%, LAST_PLAYED, EbootPath
    IniWrite, %gameID%,       %iniFile%, LAST_PLAYED, GameID
    IniWrite, %gameTitle%,    %iniFile%, LAST_PLAYED, GameTitle
    IniWrite, %iconPath%,     %iniFile%, LAST_PLAYED, IconPath

    ; ── 6. UI / log feedback ─────────────────────────────────
    UpdateStatusBar("Path saved: " . selectedEboot, 3)
    CustomTrayTip("Game Set: " . gameID . " - " . gameTitle, 1)
    Log("INFO", "Last played updated: " . gameID . " - " . gameTitle)
}

; ─── Run RPCS3 standalone function. ────────────────────────────────────────────────────────────────────
;RunRPCS3Label:
;    global iniFile
;    if (!FileExist(iniFile)) {
;        SplitPath, iniFile, iniFileName
;        CustomTrayTip("Missing " . iniFile . " Set RPCS3 path first.", 3)
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
;        CustomTrayTip("Could not read path from " . iniFile, 3)
;        SB_SetText("Could not read the path from " . iniFile, 2)
;        Log("ERROR", "Could not read the path from section [RPCS3] in`n" . iniFile)
;        Return
;    }
;
;    if !FileExist(rpcs3Path) {
;        CustomTrayTip("File not found: " . rpcs3Path, 3)
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
;    CustomTrayTip("ERROR: RPCS3 did not launch!", 3)
;    return
;}
;
;SoundPlay, %A_ScriptDir%\rpcl3_good_morning.wav
;Log("INFO", "Game Started.")
;SB_SetText("Good Morning! Game Started.", 2)
;CustomTrayTip("Good Morning! Game Started.", 1)
;UpdateStatusBar("Good Morning! Game Started.", 3)


; ─── Run RPCS3 standalone function. ────────────────────────────────────────────────────────────────────
RunRPCS3Label:
    global iniFile
    if (!FileExist(IniFile)) {
        SplitPath, IniFile, iniFileName
        CustomTrayTip("Missing " . IniFile . " Set RPCS3 Path first.", 3)
        SB_SetText("Missing " . IniFile . " Set RPCS3 Path first.", 3)
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

    SoundPlay, %A_ScriptDir%\rpcl3_good_morning.wav
    Log("INFO", "Game Started.")
    SB_SetText("Good Morning! Game Started.", 2)
    CustomTrayTip("Good Morning! Game Started.", 1)
    UpdateStatusBar("Good Morning! Game Started.", 3)
Return

; ─── Start RPCS3 game function. ────────────────────────────────────────────────────────────────────
RunRPCS3GameLabel:
global iniFile, rpcs3Exe
rpcs3Path := GetRPCS3Path()

; Kill existing RPCS3 processes forcefully
RunWait, taskkill /im %rpcs3Exe% /F,, Hide
Sleep, 1000

;Read RPCS3 path and extract executable name if found
IniRead, rpcs3Path, %IniFile%, RPCS3, Path
if (rpcs3Path != "") {
    global rpcs3Exe
    SplitPath, rpcs3Path, rpcs3Exe
}
IniRead, fullEbootPath, %iniFile%, RUN_GAME, EbootBinPath

; Validate paths
if (!FileExist(rpcs3Path)) {
    CustomTrayTip("RPCS3 executable not found!", 3)
    SB_SetText("ERROR: RPCS3 executable not found.", 2)
    Log("ERROR", "RPCS3 executable not found: " . rpcs3Path)
    return
}

if (!FileExist(fullEbootPath)) {
    CustomTrayTip("EBOOT.BIN not found.", 3)
    SB_SetText("ERROR: EBOOT.BIN not found.", 2)
    Log("ERROR", "EBOOT.BIN not found: " . fullEbootPath)
    return
}

; Extract GameID for logging or later use
gameID := ExtractGameID(fullEbootPath)
if (gameID = "") {
    Log("WARN", "Failed to extract GameID from path: " . fullEbootPath)
} else {
    Log("DEBUG", "Extracted GameID: " . gameID)
}
; Extract executable filename from full path
SplitPath, rpcs3Path, rpcs3Exe

; Convert EBOOT.BIN path to relative if inside script folder
if (InStr(fullEbootPath, A_ScriptDir . "\") = 1) {
    ebootRel := SubStr(fullEbootPath, StrLen(A_ScriptDir) + 2)  ; Remove script dir + backslash
} else {
    ebootRel := fullEbootPath
}

; Normalize slashes to backslashes
StringReplace, ebootRel, ebootRel, /, \, All

; Build command string (ensure proper quoting)
cmd := """" . rpcs3Path . """ --no-gui --fullscreen """ . ebootRel . """"
Log("DEBUG", "Full command: " . cmd)
; Full command: "rpcs3.exe" --no-gui --fullscreen "games\Ridge Racer 7 [BLUS30001]\PS3_GAME\USRDIR\EBOOT.BIN"
; Save last run command to INI (optional)
IniWrite, %cmd%, %iniFile%, RUN_GAME, RunCommand

; Run RPCS3 with the constructed command line, start in the RPCS3 directory
SplitPath, rpcs3Path, , rpcs3Dir
Run, %ComSpec% /c %cmd%, %rpcs3Dir%, , newPID

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

SoundPlay, %A_ScriptDir%\rpcl3_good_morning.wav
Log("DEBUG", "Started RPCS3 with GameID: " . gameID)
SB_SetText("Good Morning! Your Game Started.", 2)
CustomTrayTip("Good Morning! Your Game Started.", 1)
UpdateStatusBar("Good Morning! Your Game Started. ", 3)

; ─── View logs function. ────────────────────────────────────────────────────────────────────
ViewLog:
    Run, notepad.exe "%A_ScriptDir%\rpcl3.log"
    Log("DEBUG", "Opened" . LogFileName . " in Notepad.")
    SB_SetText(LogFileName . " opened.", 2)
    UpdateStatusBar(logFileName . " opened.", 3)
return

; ─── Clear logs function. ────────────────────────────────────────────────────────────────────
ClearLog:
    FileDelete, %A_ScriptDir%\rpcl3.log
    CustomTrayTip("Log file cleared successfully", 1)
return

; ─── View configuration function. ────────────────────────────────────────────────────────────────────
ViewConfigLabel:
    global iniFile
    Run, notepad.exe "%iniFile%"
    SplitPath, iniFile, iniFileName
    Log("DEBUG", "Opened: " iniFile)
    UpdateStatusBar(iniFile . " opened.", 3)
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
        global logInterval := 5000   ; 5 seconds in milliseconds

        LogSystemUsageIfDue(cpuLoad, freeMem, totalMem)

    } catch e {
        SB_SetText("Error fetching CPU/memory: " . e.Message, 2)
    }
}

; ─── Kill RPCS3 process with escape button function. ────────────────────────────────────────────────────────────────────
Esc::
    Process, Exist, rpcs3.exe
    if (ErrorLevel) {
        CustomTrayTip("ESC pressed. Killing RPCS3 processes.", 2)
        Log("WARN", "ESC pressed. Killing all RPCS3 processes.")
        SB_SetText("ESC pressed. Killed all RPCS3 processes.", 2)
        KillAllProcesses1()
    } else {
        CustomTrayTip("No RPCS3 processes found.", 1)
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

; ─── RPCSe3 show version function. ────────────────────────────────────────────────────────────────────
ShowVersionLabel:
    ShowVersion()
return

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
    sevenZipPath := A_ScriptDir "\7z.exe"

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
        CustomTrayTip("GameID not found in INI.", 3)
        Log("ERROR", "GameID not found in INI file.")
        SB_SetText("GameID not found in INI.", 2)
        return
    }

    ; 2 Ensure RPCS3 exists
    if !WinExist("ahk_exe rpcs3.exe") {
        CustomTrayTip("RPCS3 Window Not Found.", 3)
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
        CustomTrayTip("GDI+ init failed.", 3)
        Log("ERROR", "GDI+ failed to initialise.")
        SB_SetText("GDI+ init failed.", 2)
        return
    }

    ; 7 Capture RPCS3 window
    pBitmap := Gdip_BitmapFromScreen(X "|" Y "|" W "|" H)
    if !pBitmap {
        Log("ERROR", "Screen capture failed. hwnd=" . hwnd)
        CustomTrayTip("Screen capture failed (see log).", 3)
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
        CustomTrayTip("Failed to save screenshot! Code " . result, 3)
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
    CustomTrayTip("Cannot Record, RPCS3 is not running.", 2)
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
        CustomTrayTip("Missing Framerate, Framerate (fps) is not defined. Defaulting to 30.", 2)
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
CustomTrayTip("Audio output set to CABLE Input, audio input set to CABLE Output.", 1)
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
    CustomTrayTip("Debug FFmpeg Args: " fullCmd, 1)
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
    CustomTrayTip("Recording Stopped, Saved to: " outFile, 1)
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    CustomTrayTip("Audio output set to default", 1)
}
return

; ─── Audio capture function. ────────────────────────────────────────────────────────────────────
AudioCaptureLabel:
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
        ;Process, Close, %ffmpegPID%
        ControlSend,, q, ahk_pid %ffmpegPID%.

    recording := false
    GuiControl, +c808080, AudioCaptureLabel
    CustomTrayTip("Recording Stopped, Saved to: " . outFile, 1)
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    CustomTrayTip("Audio output set to default", 1)
    Run, %FileCreateDir%
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
    FFmpegFolder := A_ScriptDir "\ffmpeg"
    FFMPEG_EXE_FOLDER := FFmpegFolder "\ffmpeg.exe"

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
    ; Add FFmpegBin to user PATH environment variable
    EnvGet, currPath, USER, PATH
    newPath := FFmpegBin

    if InStr(currPath, newPath) {
        MsgBox, 64, Info, FFMPEG path is already in your user PATH.
        return
    }

    ; Append new path
    if (currPath != "")
        newPath := currPath . ";" . newPath

    RegWrite, REG_SZ, HKEY_CURRENT_USER, Environment, PATH, %newPath%
    MsgBox, 64, Success, Added FFMPEG path to user PATH.nYou may need to restart your shell or log off/on for changes to take effect.
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
