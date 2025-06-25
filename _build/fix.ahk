You need to position the Pic1 window to the right of the main GUI. Here's the fix:

ShowPic1:
    ; Function called when icon is clicked
    if (CurrentGameId = "") {
        MsgBox, 48, No Game Selected, Please select a game first.
        return
    }

    if (CurrentPic1FullPath = "") {
        MsgBox, 48, No Pic1 Path, No Pic1 path found in database for this game.
        return
    }

    if !FileExist(CurrentPic1FullPath) {
        MsgBox, 48, File Not Found, Pic1 file not found:`n%CurrentPic1FullPath%
        return
    }

    ; Get the position of the main GUI window
    Gui, Show  ; Make sure main GUI is active to get its position
    WinGetPos, mainX, mainY, mainWidth, mainHeight, RPCL3 Icon Manager

    ; Calculate position for Pic1 window (to the right of main window)
    pic1X := mainX + mainWidth + 10  ; 10 pixels gap
    pic1Y := mainY                   ; Same vertical position as main window

    ; Create new window to show Pic1
    Gui, Pic1:New, +Owner1 +AlwaysOnTop, %CurrentGameTitle% - Pic1
    Gui, Pic1:Font, s10, Segoe UI

    ; Get image dimensions for proper sizing
    FileGetSize, pic1Size, %CurrentPic1FullPath%

    ; Add picture control - let it auto-size initially
    Gui, Pic1:Add, Picture, x10 y10 w600 h400 vPic1Image gShowPic1Fullscreen, %CurrentPic1FullPath%

    ; Add info text
    infoText := "Game: " . CurrentGameTitle . " (" . CurrentGameId . ")"
    infoText .= "`nPic1 Path: " . CurrentPic1FullPath
    infoText .= "`nFile Size: " . pic1Size . " bytes"
    infoText .= "`n`nClick image to view fullscreen (ESC to close fullscreen)"
    Gui, Pic1:Add, Text, x10 y420 w600 h90 vPic1Info, %infoText%

    ; Show the window positioned to the right of main GUI
    Gui, Pic1:Show, x%pic1X% y%pic1Y% w620 h500
return
If the window title doesn't match exactly, you can also use this alternative approach that gets the main window position differently:

ShowPic1:
    ; Function called when icon is clicked
    if (CurrentGameId = "") {
        MsgBox, 48, No Game Selected, Please select a game first.
        return
    }

    if (CurrentPic1FullPath = "") {
        MsgBox, 48, No Pic1 Path, No Pic1 path found in database for this game.
        return
    }

    if !FileExist(CurrentPic1FullPath) {
        MsgBox, 48, File Not Found, Pic1 file not found:`n%CurrentPic1FullPath%
        return
    }

    ; Get the position of the main GUI window using the GUI handle
    Gui, +LastFound
    WinGetPos, mainX, mainY, mainWidth, mainHeight

    ; Calculate position for Pic1 window (to the right of main window)
    pic1X := mainX + mainWidth + 10  ; 10 pixels gap
    pic1Y := mainY                   ; Same vertical position as main window

    ; Make sure the window doesn't go off-screen
    SysGet, ScreenWidth, 78
    if (pic1X + 620 > ScreenWidth) {
        ; If it would go off-screen, position it to the left instead
        pic1X := mainX - 630  ; 620 width + 10 gap
        if (pic1X < 0) {
            ; If left doesn't work either, center it on screen
            pic1X := Floor((ScreenWidth - 620) / 2)
        }
    }

    ; Create new window to show Pic1
    Gui, Pic1:New, +Owner1, %CurrentGameTitle% - Pic1
    Gui, Pic1:Font, s10, Segoe UI

    ; Get image dimensions for proper sizing
    FileGetSize, pic1Size, %CurrentPic1FullPath%

    ; Add picture control - let it auto-size initially
    Gui, Pic1:Add, Picture, x10 y10 w600 h400 vPic1Image gShowPic1Fullscreen, %CurrentPic1FullPath%

    ; Add info text
    infoText := "Game: " . CurrentGameTitle . " (" . CurrentGameId . ")"
    infoText .= "`nPic1 Path: " . CurrentPic1FullPath
    infoText .= "`nFile Size: " . pic1Size . " bytes"
    infoText .= "`n`nClick image to view fullscreen (ESC to close fullscreen)"
    Gui, Pic1:Add, Text, x10 y420 w600 h90 vPic1Info, %infoText%

    ; Show the window positioned to the right of main GUI
    Gui, Pic1:Show, x%pic1X% y%pic1Y% w620 h500
return
The key changes:

Get main window position: Uses WinGetPos to get the main GUI's position and size
Calculate new position: Places the Pic1 window to the right with a 10-pixel gap
Screen boundary check: Makes sure the window doesn't go off-screen (second version)
Owner relationship: +Owner1 makes the Pic1 window owned by the main GUI
Proper positioning: Uses x%pic1X% y%pic1Y% in the Show command
This will make the Pic1 window appear to the right of your main window instead of behind it!
