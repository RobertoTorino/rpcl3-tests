Let me fix the fullscreen scaling properly. The issue is that AutoHotkey's Picture control doesn't handle aspect ratio scaling well when both width and height are specified. Here's the corrected version:

ShowPic1Fullscreen:
    ; Get screen dimensions
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; For AutoHotkey v1, the best approach is to let the Picture control
    ; handle the scaling by specifying only one dimension or using -1
    ; This maintains aspect ratio

    ; Calculate safe dimensions (90% of screen to ensure it fits)
    safeWidth := Floor(ScreenWidth * 0.9)
    safeHeight := Floor(ScreenHeight * 0.9)

    ; Center position
    centerX := Floor((ScreenWidth - safeWidth) / 2)
    centerY := Floor((ScreenHeight - safeHeight) / 2)

    ; Method 1: Try with w-1 h-1 which should maintain aspect ratio
    Gui, Fullscreen:Add, Picture, x%centerX% y%centerY% w-1 h-1 vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen
    Gui, Fullscreen:Show, x0 y0 w%ScreenWidth% h%ScreenHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
If that still doesn't work, try this alternative approach:

ShowPic1Fullscreen:
    ; Get screen dimensions
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Try a different approach - specify only width OR height to maintain aspect ratio
    ; Use whichever is smaller (width or height based) to ensure it fits

    ; Use 85% of screen dimensions
    maxWidth := Floor(ScreenWidth * 0.85)
    maxHeight := Floor(ScreenHeight * 0.85)

    ; Calculate center positions
    centerX := Floor((ScreenWidth - maxWidth) / 2)
    centerY := Floor((ScreenHeight - maxHeight) / 2)

    ; Try specifying only width, let height auto-scale
    Gui, Fullscreen:Add, Picture, x%centerX% y%centerY% w%maxWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen
    Gui, Fullscreen:Show, x0 y0 w%ScreenWidth% h%ScreenHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
Or the most conservative approach:

ShowPic1Fullscreen:
    ; Get screen dimensions
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Very conservative approach - use much smaller size to ensure it fits
    ; Use 70% of the smaller dimension
    if (ScreenWidth < ScreenHeight) {
        imgSize := Floor(ScreenWidth * 0.7)
    } else {
        imgSize := Floor(ScreenHeight * 0.7)
    }

    ; Center the square/rectangular area
    centerX := Floor((ScreenWidth - imgSize) / 2)
    centerY := Floor((ScreenHeight - imgSize) / 2)

    ; Add picture with square dimensions, let it scale within
    Gui, Fullscreen:Add, Picture, x%centerX% y%centerY% w%imgSize% h%imgSize% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen
    Gui, Fullscreen:Show, x0 y0 w%ScreenWidth% h%ScreenHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
Try these three approaches in order. The first one (w-1 h-1) should maintain aspect ratio, the second one specifies only width to let height auto-scale, and the third one uses the most conservative sizing to guarantee it fits.

Which approach works best for your images?

