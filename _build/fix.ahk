Let me fix the centering and scaling issues. The problem is with the positioning calculations. Here's a corrected version:

ShowPic1Fullscreen:
    ; Get screen dimensions
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Simple approach: place image at top-left corner with reasonable size
    ; Use 80% of screen width, let height scale automatically
    imgWidth := Floor(ScreenWidth * 0.8)

    ; Position closer to center but not calculated center (which seems off)
    startX := Floor(ScreenWidth * 0.1)  ; 10% from left edge
    startY := Floor(ScreenHeight * 0.1) ; 10% from top edge

    ; Add picture with only width specified for proper aspect ratio
    Gui, Fullscreen:Add, Picture, x%startX% y%startY% w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen
    Gui, Fullscreen:Show, x0 y0 w%ScreenWidth% h%ScreenHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
Or try this even simpler version that starts from the top-left:

ShowPic1Fullscreen:
    ; Get screen dimensions
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Very simple approach: small margins from edges
    marginX := 50
    marginY := 50

    ; Calculate available space
    availableWidth := ScreenWidth - (marginX * 2)
    availableHeight := ScreenHeight - (marginY * 2)

    ; Use 90% of available width
    imgWidth := Floor(availableWidth * 0.9)

    ; Position with margins
    Gui, Fullscreen:Add, Picture, x%marginX% y%marginY% w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen
    Gui, Fullscreen:Show, x0 y0 w%ScreenWidth% h%ScreenHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
Or if the positioning is still wrong, let's try absolute positioning:

ShowPic1Fullscreen:
    ; Get screen dimensions
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Try absolute positioning - start from actual coordinates
    imgX := 100  ; 100 pixels from left
    imgY := 100  ; 100 pixels from top
    imgWidth := ScreenWidth - 200  ; Full width minus margins

    ; Add picture
    Gui, Fullscreen:Add, Picture, x%imgX% y%imgY% w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen
    Gui, Fullscreen:Show, x0 y0 w%ScreenWidth% h%ScreenHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
Try these three versions. The last one with absolute positioning (100 pixels from left and top) should definitely be visible and properly positioned. Let me know which one works best and I can fine-tune the positioning from there.

