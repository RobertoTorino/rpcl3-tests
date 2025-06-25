Option 1: Show on All Monitors (Easiest)
ShowPic1Fullscreen:
    ; Ask user which monitor to use
    MsgBox, 4, Monitor Selection, Show on primary monitor?`n`nYes = Primary Monitor`nNo = Secondary Monitor
    IfMsgBox, Yes
        monitorNum := 1
    else
        monitorNum := 2

    ; Get monitor dimensions
    SysGet, MonitorCount, MonitorCount
    if (monitorNum > MonitorCount) {
        MsgBox, 48, Monitor Error, Monitor %monitorNum% not found. Using primary monitor.
        monitorNum := 1
    }

    ; Get specific monitor info
    SysGet, Monitor, Monitor, %monitorNum%

    ; Calculate monitor dimensions
    MonWidth := MonitorRight - MonitorLeft
    MonHeight := MonitorBottom - MonitorTop

    ; Create fullscreen window on specific monitor
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Position image
    imgWidth := MonWidth - 100  ; Leave some margin

    ; Add picture
    Gui, Fullscreen:Add, Picture, x0 y0 w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen on specific monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% w%MonWidth% h%MonHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
Option 2: Automatic Monitor Detection
ShowPic1Fullscreen:
    ; Get monitor count
    SysGet, MonitorCount, MonitorCount

    if (MonitorCount = 1) {
        ; Single monitor - use primary
        SysGet, MonWidth, 78
        SysGet, MonHeight, 79
        MonitorLeft := 0
        MonitorTop := 0
    } else {
        ; Multiple monitors - let user choose or use cursor position
        ; Get current cursor position to determine which monitor
        MouseGetPos, mouseX, mouseY

        ; Find which monitor the cursor is on
        selectedMonitor := 1
        Loop, %MonitorCount% {
            SysGet, Mon, Monitor, %A_Index%
            if (mouseX >= MonLeft && mouseX <= MonRight && mouseY >= MonTop && mouseY <= MonBottom) {
                selectedMonitor := A_Index
                break
            }
        }

        ; Use the monitor where cursor is located
        SysGet, Monitor, Monitor, %selectedMonitor%
        MonWidth := MonitorRight - MonitorLeft
        MonHeight := MonitorBottom - MonitorTop
    }

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Position image
    imgWidth := MonWidth - 100

    ; Add picture
    Gui, Fullscreen:Add, Picture, x0 y0 w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show on selected monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% w%MonWidth% h%MonHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
Option 3: Hotkeys to Switch Between Monitors
ShowPic1Fullscreen:
    ; Store the current monitor number globally
    if (!CurrentFullscreenMonitor)
        CurrentFullscreenMonitor := 1

    ; Get monitor info
    SysGet, MonitorCount, MonitorCount
    SysGet, Monitor, Monitor, %CurrentFullscreenMonitor%

    ; Calculate dimensions
    MonWidth := MonitorRight - MonitorLeft
    MonHeight := MonitorBottom - MonitorTop

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Position image
    imgWidth := MonWidth - 100

    ; Add picture
    Gui, Fullscreen:Add, Picture, x0 y0 w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions with monitor switching info
    instructions := "Press ESC to close | Press M to switch to next monitor (" . CurrentFullscreenMonitor . "/" . MonitorCount . ")"
    Gui, Fullscreen:Add, Text, x20 y20 w600 h30 cWhite BackgroundTrans, %instructions%

    ; Show on current monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% w%MonWidth% h%MonHeight%

    ; Set up hotkeys
    Hotkey, Escape, CloseFullscreen, On
    Hotkey, m, SwitchMonitor, On
return

SwitchMonitor:
    ; Switch to next monitor
    SysGet, MonitorCount, MonitorCount
    CurrentFullscreenMonitor++
    if (CurrentFullscreenMonitor > MonitorCount)
        CurrentFullscreenMonitor := 1

    ; Close current fullscreen and reopen on new monitor
    Hotkey, Escape, CloseFullscreen, Off
    Hotkey, m, SwitchMonitor, Off
    Gui, Fullscreen:Destroy
    Gosub, ShowPic1Fullscreen
return

CloseFullscreen:
    Hotkey, Escape, CloseFullscreen, Off
    Hotkey, m, SwitchMonitor, Off
    Gui, Fullscreen:Destroy
return
Option 4: Simple Monitor Selection Menu
ShowPic1Fullscreen:
    ; Get monitor count
    SysGet, MonitorCount, MonitorCount

    if (MonitorCount > 1) {
        ; Show monitor selection
        monitorList := ""
        Loop, %MonitorCount% {
            SysGet, Mon, Monitor, %A_Index%
            MonWidth := MonRight - MonLeft
            MonHeight := MonBottom - MonTop
            monitorList .= "Monitor " . A_Index . " (" . MonWidth . "x" . MonHeight . ")|"
        }

        ; Remove trailing |
        StringTrimRight, monitorList, monitorList, 1

        ; Show selection GUI
        Gui, MonSelect:New, , Select Monitor
        Gui, MonSelect:Add, Text, , Choose monitor for fullscreen:
        Gui, MonSelect:Add, DropDownList, vSelectedMon w200, %monitorList%
        Gui, MonSelect:Add, Button, gShowOnSelectedMonitor x70 w60, OK
        GuiControl, MonSelect:Choose, SelectedMon, 1
        Gui, MonSelect:Show, w240 h100
        return
    } else {
        ; Single monitor
        selectedMonitorNum := 1
        Gosub, DoShowFullscreen
    }
return

MonSelectGuiClose:
    Gui, MonSelect:Destroy
return

ShowOnSelectedMonitor:
    Gui, MonSelect:Submit
    selectedMonitorNum := SelectedMon
    Gui, MonSelect:Destroy
    Gosub, DoShowFullscreen
return

DoShowFullscreen:
    ; Get selected monitor info
    SysGet, Monitor, Monitor, %selectedMonitorNum%
    MonWidth := MonitorRight - MonitorLeft
    MonHeight := MonitorBottom - MonitorTop

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Position image
    imgWidth := MonWidth - 100

    ; Add picture
    Gui, Fullscreen:Add, Picture, x0 y0 w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show on selected monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% w%MonWidth% h%MonHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
I recommend Option 2 (automatic cursor-based detection) or Option 3 (hotkey switching with M key) as they provide good user experience. Which approach would you prefer?

Type a message...
ChatDPG can make mistakes; verify imp
