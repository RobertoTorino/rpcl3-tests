#SingleInstance Force
#Persistent

SetWorkingDir A_ScriptDir

; ─── Set as admin. ─────────────────────────────────────────────
if !A_IsAdmin
{
    try
        Run '*RunAs "' A_ScriptFullPath '"'
    catch
        MsgBox "This script needs to be run as Administrator.", "Error"
    ExitApp
}

; ─── Unique window class name. ─────────────────────────────────
#WinActivateForce
scriptTitle := "RPCS3 End Process"
if WinExist("ahk_class AutoHotkey ahk_exe " A_ScriptName) && !A_IsCompiled
    ExitApp

; Try to send message to existing instance
if (A_Args.Has(1) && A_Args[1] = "activate") {
    PostMessage 0x5555, , , , "ahk_class AutoHotkey"
    ExitApp
}

; ─── Start GUI. ─────────────────────────────
title := "RPCS3 End Process - " Chr(169) " " A_YYYY " - Philip"
Gui := GuiCreate()
Gui.SetFont("s10 q5", "Arial")
Gui.MarginX := 15
Gui.MarginY := 15
Gui.OnEvent("Close", GuiClose)
Gui.Add("Text", "w390 h40 +Center", "Press the Escape button to quit rpcs3.")
Gui.Show("w400 h50", title)
GuiHwnd := Gui.Hwnd

; ─── System tray. ─────────────────────────────
A_TrayMenu.Delete()                          ; Remove default items
A_TrayMenu.Add("Show GUI", ShowGui)
A_TrayMenu.Add()                             ; Separator
A_TrayMenu.Add("About RPCL3EP...", ShowAboutDialog)
A_TrayMenu.Default := "Show GUI"
A_TrayMenu.Tip := "RPCS3 End Process"

; ─── Hotkey for Escape. ──────────────────────
Esc:: {
    ProcessExist := ProcessExistFunc("rpcs3.exe")
    if ProcessExist {
        CustomTrayTip("ESC pressed. Killing RPCS3 processes.", 2)
        KillAllProcessesEsc()
    } else {
        CustomTrayTip("No RPCS3 processes found.", 1)
    }
}

ProcessExistFunc(procName) {
    try
        return ProcessExist(procName)
    catch
        return false
}

KillAllProcessesEsc() {
    RunWait('taskkill /im rpcs3.exe /F', , "Hide")
    RunWait('taskkill /im powershell.exe /F', , "Hide")
    ;RunWait('taskkill /im autohotkey.exe /F', , "Hide")
}

CustomTrayTip(Text, Icon := 1) {
    ; Icon: 0=None, 1=Info, 2=Warning, 3=Error. 16 = No sound (bitwise OR)
    Title := "RPCL3 End Process"
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    TrayTip Title, Text, , Icon | 16
}

ShowAboutDialog(*) {
    ; Dummy version handling (resource extraction not directly supported in v2)
    ; Suggest to handle version by other means in AHK v2 if needed.
    version := "Unknown"

    aboutText := "RPCS3 End Process`n"
             . "Kills all RPCS3 Processes`n"
             . "Version: " version "`n"
             . Chr(169) " " A_YYYY " Philip`n"
             . "YouTube: @game_play267`n"
             . "Twitch: RR_357000`n"
             . "X: @relliK_2048`n"
             . "Discord:"

    MsgBox(aboutText, "About RPCL3PC", 64)
}

ShowGui(*) {
    Gui.Show()
    ; SB_SetText is not built-in in v2 unless you use a StatusBar - omitted
}

GuiClose(*) {
    ExitApp
}
