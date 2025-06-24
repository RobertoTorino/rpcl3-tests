ShowPic1Fullscreen:
    ; Get screen dimensions
    SysGet, ScreenWidth, 78
    SysGet, ScreenHeight, 79

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Calculate image size to fit screen while maintaining aspect ratio
    ; Use 95% of screen size to ensure it fits
    maxWidth := Floor(ScreenWidth * 0.95)
    maxHeight := Floor(ScreenHeight * 0.95)

    ; Since we can't easily get image dimensions in AHK v1,
    ; we'll use a conservative approach to ensure the image fits

    ; Try different scaling approaches based on screen size
    if (ScreenWidth > 1920) {
        ; Large screen - use 80% to be safe
        imgWidth := Floor(ScreenWidth * 0.8)
        imgHeight := Floor(ScreenHeight * 0.8)
    } else if (ScreenWidth > 1280) {
        ; Medium screen - use 85%
        imgWidth := Floor(ScreenWidth * 0.85)
        imgHeight := Floor(ScreenHeight * 0.85)
    } else {
        ; Small screen - use 90%
        imgWidth := Floor(ScreenWidth * 0.9)
        imgHeight := Floor(ScreenHeight * 0.9)
    }

    ; Center the image
    centerX := Floor((ScreenWidth - imgWidth) / 2)
    centerY := Floor((ScreenHeight - imgHeight) / 2)

    ; Ensure minimum margins
    if (centerX < 20) {
        centerX := 20
        imgWidth := ScreenWidth - 40
    }
    if (centerY < 20) {
        centerY := 20
        imgHeight := ScreenHeight - 40
    }

    ; Add picture control with calculated size and position
    Gui, Fullscreen:Add, Picture, x%centerX% y%centerY% w%imgWidth% h%imgHeight% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions in top-left corner
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show fullscreen
    Gui, Fullscreen:Show, x0 y0 w%ScreenWidth% h%ScreenHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return
