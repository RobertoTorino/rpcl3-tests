; YouTube: @game_play267
; Twitch: RR_357000
; X:@relliK_2048
; Discord:
; RPCL3 Process Control
#SingleInstance force
#Persistent
#NoEnv

SetWorkingDir %A_ScriptDir%

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
scriptTitle := "RPCS3 End Process"
if WinExist("ahk_class AutoHotkey ahk_exe " A_ScriptName) && !A_IsCompiled {
    ;Re-run if script is not compiled
    ExitApp
}

;Try to send a message to existing instance
if A_Args[1] = "activate" {
    PostMessage, 0x5555,,,, ahk_class AutoHotkey
    ExitApp
}


; ─── Start GUI. ───────────────────────────────────────────────────────────────────────────────────────────────────────
title := "RPCS3 End Process - " . Chr(169) . " " . A_YYYY . " - Philip"
Gui, Show, w400 h50, %title%
Gui, +LastFound
Gui, Font, s10 q5, Arial
Gui, Margin, 15, 15
GuiHwnd := WinExist()

Gui, Add, Text, w390 h40 +Center, Press the Escape button to quit rpcs3.

; ─── System tray. ────────────────────────────────────────────────────────────
Menu, Tray, NoStandard                                  ;Remove default items like "Pause Script"
Menu, Tray, Add, Show GUI, ShowGui                      ;Add a custom "Show GUI" option
Menu, Tray, Add                                         ;Add a separator line
Menu, Tray, Add, About RPCL3EP..., ShowAboutDialog
Menu, Tray, Default, Show GUI                           ;Make "Show GUI" the default double-click action
Menu, Tray, Tip, RPCS3 End Process                      ;Tooltip when hovering

; ─── This return ends all updates to the gui. ─────────────────────────────────────────────────────────────────────────
return
; ─── END GUI. ─────────────────────────────────────────────────────────────────────────────────────────────────────────


; ─── Kill RPCS3 process with escape button function. ──────────────────────────────────────────────────────────────────
Esc::
    Process, Exist, rpcs3.exe
    if (ErrorLevel) {
        CustomTrayTip("ESC pressed. Killing RPCS3 processes.", 2)
        KillAllProcessesEsc()
    } else {
        CustomTrayTip("No RPCS3 processes found.", 1)
    }
return


KillAllProcessesEsc() {
    RunWait, taskkill /im rpcs3.exe /F,, Hide
    RunWait, taskkill /im powershell.exe /F,, Hide
    ;RunWait, taskkill /im autohotkey.exe /F,, Hide
}


; ─── Custom tray tip function ─────────────────────────────────────────────────────────────────────────────────────────
CustomTrayTip(Text, Icon := 1) {
    ; Parameters:
    ; Text  - Message to display
    ; Icon  - 0=None, 1=Info, 2=Warning, 3=Error (default=1)
    static Title := "RPCL3 End Process"
    ; Validate icon input (clamp to 0-3 range)
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    ; 16 = No sound (bitwise OR with icon value)
    TrayTip, %Title%, %Text%, , % Icon|16
}


; ─── Show "about" dialog function. ────────────────────────────────────────────────────────────────────
ShowAboutDialog() {
    ; Extract embedded version.dat resource to temp file
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
    ; Read version string
    FileRead, verContent, %tempFile%
    version := "Unknown"
    if (verContent != "") {
        version := verContent
    }

aboutText := "RPCS3 End Process`n"
           . "Kills all RPCS3 Processes`n"
           . "Version: " . version . "`n"
           . Chr(169) . " " . A_YYYY . " Philip" . "`n"
           . "YouTube: @game_play267" . "`n"
           . "Twitch: RR_357000" . "`n"
           . "X: @relliK_2048" . "`n"
           . "Discord:"

MsgBox, 64, About RPCL3PC, %aboutText%
}

; ─── Show GUI. ────────────────────────────────────────────────────────────────────────────────────────────────────────
ShowGui:
    Gui, Show
    SB_SetText("RPCS3 Process Control GUI Shown.", 2)
return

GuiClose:
    ExitApp
return
