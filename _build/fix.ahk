The issue is that the image is positioned at x=0 but has a calculated width that doesn't account for proper centering.
Let me fix the fullscreen image positioning:

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

    ; Calculate image size and positioning for proper centering
    ; Use 90% of screen width to leave some margin
    imgWidth := Floor(MonWidth * 0.9)
    imgHeight := Floor(MonHeight * 0.9)

    ; Center the image on the screen
    centerX := Floor((MonWidth - imgWidth) / 2)
    centerY := Floor((MonHeight - imgHeight) / 2)

    ; Add picture with proper centering
    Gui, Fullscreen:Add, Picture, x%centerX% y%centerY% w%imgWidth% h%imgHeight% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions with monitor switching info
    instructions := "Press ESC to close | Press M to switch to next monitor (" . CurrentFullscreenMonitor . "/" . MonitorCount . ")"
    Gui, Fullscreen:Add, Text, x20 y20 w600 h30 cWhite BackgroundTrans, %instructions%

    ; Show on current monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% w%MonWidth% h%MonHeight%

    ; Set up hotkeys
    Hotkey, Escape, CloseFullscreen, On
    Hotkey, m, SwitchMonitor, On
return



If you want the image to fill more of the screen while maintaining aspect ratio, try this alternative:

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

    ; For better aspect ratio handling, specify only width OR height
    ; Let AutoHotkey scale the other dimension automatically

    ; Use 85% of screen width, let height auto-scale
    imgWidth := Floor(MonWidth * 0.85)

    ; Center horizontally, and add some top margin
    centerX := Floor((MonWidth - imgWidth) / 2)
    topMargin := Floor(MonHeight * 0.05)  ; 5% from top

    ; Add picture - only specify width to maintain aspect ratio
    Gui, Fullscreen:Add, Picture, x%centerX% y%topMargin% w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions with monitor switching info
    instructions := "Press ESC to close | Press M to switch to next monitor (" . CurrentFullscreenMonitor . "/" . MonitorCount . ")"
    Gui, Fullscreen:Add, Text, x20 y20 w600 h30 cWhite BackgroundTrans, %instructions%

    ; Show on current monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% w%MonWidth% h%MonHeight%

    ; Set up hotkeys
    Hotkey, Escape, CloseFullscreen, On
    Hotkey, m, SwitchMonitor, On
return
The key changes:

Option 1: Properly centers the image both horizontally and vertically
Option 2: Centers horizontally and positions with a small top margin, only specifies width to let AutoHotkey maintain the aspect ratio
