#SingleInstance Force
#NoEnv
#Include %A_ScriptDir%\tools\SQLiteDB.ahk

; Global variables
Global db
Global CurrentGameId, CurrentGameTitle, CurrentIconPath, CurrentPic1FullPath, CurrentSnd0FullPath

; Icon Manager Script
db := new SQLiteDB()
if !db.OpenDB(A_ScriptDir . "\games.db") {
    err := db.ErrorMsg
    MsgBox, 16, DB Error, Failed to open DB.`n%err%
    ExitApp
}

; Verify database is open
if !db._Handle {
    MsgBox, 16, DB Handle Error, Database handle is invalid
    ExitApp
}

; Create icons folder if it doesn't exist
IconsFolder := A_ScriptDir . "\rpcl3_icons"
FileCreateDir, %IconsFolder%

; Create Icon Manager GUI
Gui, Font, s10, Segoe UI

; Search/Select Game section
Gui, Add, GroupBox, x10 y10 w480 h120, Select Game
Gui, Add, Text, x20 y30, Search game:
Gui, Add, Edit, vSearchTerm x20 y50 w200 h20
Gui, Add, Button, gSearchGames x230 y50 w60 h20, Search
Gui, Add, ComboBox, vGameSelect x20 y75 w400 h200 gGameSelected, Select a game...
Gui, Add, Text, vTotalGames x20 y105 w450 h20, Total games in database: Loading...

; Current Game Info section
Gui, Add, GroupBox, x10 y140 w480 h140, Current Game Info
Gui, Add, Text, x20 y160, Selected Game:
Gui, Add, Text, vSelectedGame x20 y175 w450 h20, None selected
Gui, Add, Text, x20 y195, Current Icon Path:
Gui, Add, Text, vCurrentIconPath x20 y210 w450 h20, -
Gui, Add, Text, x20 y215, Icon in rpcl3_icons:
Gui, Add, Text, vIconInFolder x20 y230 w200 h20, Checking...
Gui, Add, Text, x20 y245, Sound File (SND0):
Gui, Add, Text, vSoundFileInfo x20 y260 w200 h20, Checking...

; Sound Control section
Gui, Add, GroupBox, x260 y140 w230 h140, Sound Control
Gui, Add, Button, gPlaySound x270 y160 w100 h30, Play Sound
Gui, Add, Button, gStopSound x380 y160 w100 h30, Stop Sound
Gui, Add, Text, vSoundStatus x270 y200 w200 h60, No sound loaded

; Icon Preview section
Gui, Add, GroupBox, x10 y290 w240 h150, Current Icon Preview
Gui, Add, Picture, vCurrentIcon x20 y310 w220 h100 gShowPic1,
Gui, Add, Text, vIconStatus x20 y415 w200 h20, No icon loaded

; Icon Actions section
Gui, Add, GroupBox, x260 y290 w230 h150, Icon Actions
Gui, Add, Button, gCopyExistingIcon x270 y310 w200 h30, Copy Existing Icon to Folder
Gui, Add, Button, gBrowseAndCopyIcon x270 y350 w200 h30, Browse & Copy New Icon
Gui, Add, Button, gDeleteIconFromFolder x270 y390 w200 h30, Delete Icon from Folder

; Progress section
Gui, Add, GroupBox, x10 y450 w480 h80, Status
Gui, Add, Text, vStatusText x20 y470 w450 h40, Ready. Select a game to manage its icon.

Gui, Show, w500 h540, Icon Manager

; Load total game count on startup
LoadTotalGames()
return

LoadTotalGames() {
    ; Check if database object exists and has a handle
    if (!db || !db._Handle) {
        GuiControl,, TotalGames, Total games: Database not connected
        MsgBox, 16, DB Error, Database object or handle is invalid
        return
    }

    ; Try the count query
    countSql := "SELECT COUNT(*) FROM games"

    if !db.GetTable(countSql, countResult) {
        errMsg := db.ErrorMsg
        GuiControl,, TotalGames, Total games: Query failed - %errMsg%
        return
    }

    if (countResult.RowCount = 0) {
        GuiControl,, TotalGames, Total games: No data returned
        return
    }

    if countResult.GetRow(1, row) {
        totalCount := row[1]
        GuiControl,, TotalGames, Total games in database: %totalCount%
    } else {
        GuiControl,, TotalGames, Total games: Error reading count
    }
}

SearchGames:
    Gui, Submit, NoHide

    if (SearchTerm = "") {
        MsgBox, 48, Input Required, Please enter a search term.
        return
    }

    ; Search for games
    StringReplace, searchTerm, SearchTerm, ', '', All
    sql := "SELECT GameId, GameTitle FROM games WHERE GameTitle LIKE '%" . searchTerm . "%' OR GameId LIKE '%" . searchTerm . "%' ORDER BY GameTitle LIMIT 20"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, Search failed
        return
    }

    ; Clear and populate combo box
    GuiControl,, GameSelect, |Select a game...

    if (result.RowCount = 0) {
        GuiControl,, StatusText, No games found matching "%SearchTerm%"
        return
    }

    ; Add games to combo box
    Loop, % result.RowCount {
        row := ""
        if result.GetRow(A_Index, row) {
            gameEntry := row[1] . " - " . row[2]
            GuiControl,, GameSelect, %gameEntry%
        }
    }

    statusText := "Found " . result.RowCount . " games. Select one from the dropdown."
    GuiControl,, StatusText, %statusText%
return

GameSelected:
    Gui, Submit, NoHide

    if (GameSelect = "Select a game..." || GameSelect = "") {
        return
    }

    ; Stop any currently playing sound
    SoundPlay, *-1

    ; Extract Game ID from selection (format: "GAMEID - Title")
    StringSplit, parts, GameSelect, %A_Space%-%A_Space%
    selectedGameId := parts1

    ; Get detailed game info - now including Pic1 and Snd0
    StringReplace, escapedGameId, selectedGameId, ', '', All
    sql := "SELECT GameId, GameTitle, Icon0, Pic1, Snd0 FROM games WHERE GameId = '" . escapedGameId . "'"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, Failed to get game details
        return
    }

    if (result.RowCount = 0) {
        MsgBox, 16, Error, Game not found
        return
    }

    result.GetRow(1, row)
    CurrentGameId := row[1]
    CurrentGameTitle := row[2]
    CurrentIcon0Path := row[3]
    CurrentPic1Path := row[4]
    CurrentSnd0Path := row[5]  ; Store Snd0 path

    ; Build the full path to the original icon file
    if (CurrentIcon0Path != "") {
        CurrentIcon0Path := LTrim(CurrentIcon0Path, "\/")
        CurrentIconPath := A_ScriptDir . "\" . CurrentIcon0Path
    } else {
        CurrentIconPath := ""
    }

    ; Build the full path to Pic1 file
    if (CurrentPic1Path != "") {
        CurrentPic1Path := LTrim(CurrentPic1Path, "\/")
        CurrentPic1FullPath := A_ScriptDir . "\" . CurrentPic1Path
    } else {
        CurrentPic1FullPath := ""
    }

    ; Build the full path to Snd0 file
    if (CurrentSnd0Path != "") {
        CurrentSnd0Path := LTrim(CurrentSnd0Path, "\/")
        CurrentSnd0FullPath := A_ScriptDir . "\" . CurrentSnd0Path
    } else {
        CurrentSnd0FullPath := ""
    }

    ; Check for icon in rpcl3_icons folder
    IconInFolder := A_ScriptDir . "\rpcl3_icons\" . CurrentGameId . ".PNG"

    ; Update GUI
    GuiControl,, SelectedGame, %CurrentGameId% - %CurrentGameTitle%
    GuiControl,, CurrentIconPath, %CurrentIconPath%

    ; Check if icon exists in rpcl3_icons folder
    if FileExist(IconInFolder) {
        FileGetSize, iconSize, %IconInFolder%
        GuiControl,, IconInFolder, Yes (%iconSize% bytes)
        GuiControl,, CurrentIcon, %IconInFolder%
        GuiControl,, IconStatus, From rpcl3_icons folder (click to view Pic1)
    } else {
        GuiControl,, IconInFolder, No

        ; Try to show icon from original file path
        if (CurrentIconPath != "" && FileExist(CurrentIconPath)) {
            GuiControl,, CurrentIcon, %CurrentIconPath%
            statusText := "From original location: " . CurrentIconPath
            GuiControl,, IconStatus, %statusText% (click to view Pic1)
        } else {
            GuiControl,, CurrentIcon,
            if (CurrentIconPath != "") {
                statusText := "Original not found: " . CurrentIconPath
                GuiControl,, IconStatus, %statusText%
            } else {
                GuiControl,, IconStatus, No icon path in database
            }
        }
    }

    ; Check and handle sound file
    if (CurrentSnd0FullPath != "" && FileExist(CurrentSnd0FullPath)) {
        FileGetSize, soundSize, %CurrentSnd0FullPath%
        GuiControl,, SoundFileInfo, Found (%soundSize% bytes)
        GuiControl,, SoundStatus, Sound file ready to play

        ; Auto-play the sound when game is selected
        SoundPlay, %CurrentSnd0FullPath%
        GuiControl,, SoundStatus, Playing: %CurrentSnd0FullPath%

    } else if (CurrentSnd0FullPath != "") {
        GuiControl,, SoundFileInfo, File not found
        GuiControl,, SoundStatus, Sound file not found: %CurrentSnd0FullPath%
    } else {
        GuiControl,, SoundFileInfo, No path in database
        GuiControl,, SoundStatus, No sound file path in database
    }

    GuiControl,, StatusText, Game selected: %CurrentGameTitle%
return

PlaySound:
    if (CurrentSnd0FullPath = "") {
        MsgBox, 48, No Sound File, No sound file available for the selected game.
        return
    }

    if !FileExist(CurrentSnd0FullPath) {
        MsgBox, 48, File Not Found, Sound file not found:`n%CurrentSnd0FullPath%
        return
    }

    ; Play the sound
    SoundPlay, %CurrentSnd0FullPath%
    GuiControl,, SoundStatus, Playing: %CurrentSnd0FullPath%
    GuiControl,, StatusText, Playing sound file...
return

StopSound:
    ; Stop any playing sound (AHK v1 syntax)
    SoundPlay, *-1
    GuiControl,, SoundStatus, Sound stopped
    GuiControl,, StatusText, Sound playback stopped
return

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

    ; Create new window to show Pic1
    Gui, Pic1:New, +Resize, %CurrentGameTitle% - Pic1
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
    Gui, Pic1:Add, Text, x10 y420 w600 h60 vPic1Info, %infoText%

    ; Show the window
    Gui, Pic1:Show, w620 h490
return

ShowPic1Fullscreen:
    ; Get monitor count
    SysGet, MonitorCount, MonitorCount

    if (MonitorCount > 1) {
        ; Multiple monitors - use cursor position to determine which monitor
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
    } else {
        ; Single monitor
        SysGet, MonWidth, 78
        SysGet, MonHeight, 79
        MonitorLeft := 0
        MonitorTop := 0
    }

    ; Create fullscreen window
    Gui, Fullscreen:New, -Caption -Border +AlwaysOnTop, Fullscreen Viewer
    Gui, Fullscreen:Color, Black

    ; Position image
    imgWidth := MonWidth - 100

    ; Add picture with x=0, y=0 as you requested
    Gui, Fullscreen:Add, Picture, x0 y0 w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions
    Gui, Fullscreen:Add, Text, x20 y20 w400 h30 cWhite BackgroundTrans, Press ESC to close fullscreen

    ; Show on selected monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% w%MonWidth% h%MonHeight%

    ; Set up ESC key hotkey to close fullscreen
    Hotkey, Escape, CloseFullscreen, On
return

CloseFullscreen:
    Hotkey, Escape, CloseFullscreen, Off
    Gui, Fullscreen:Destroy
return

FullscreenGuiClose:
    Hotkey, Escape, CloseFullscreen, Off
    Gui, Fullscreen:Destroy
return

Pic1GuiClose:
    Gui, Pic1:Destroy
return

CopyExistingIcon:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    if (CurrentIconPath = "" || !FileExist(CurrentIconPath)) {
        MsgBox, 48, No File, No existing icon file found for this game.`n`nExpected location: %CurrentIconPath%
        return
    }

    ; Confirm action
    MsgBox, 4, Confirm Copy, Copy the existing icon file to rpcl3_icons folder?`n`nFrom: %CurrentIconPath%`nTo: %CurrentGameId%.PNG`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    CopyIconToFolder(CurrentIconPath, CurrentGameId, CurrentGameTitle)
return

BrowseAndCopyIcon:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Browse for icon file
    FileSelectFile, selectedIcon, 1, , Select icon file, Image Files (*.png; *.jpg; *.jpeg; *.bmp; *.gif)

    if (selectedIcon = "") {
        return
    }

    ; Confirm action
    MsgBox, 4, Confirm Copy, Copy this icon to rpcl3_icons folder?`n`nFrom: %selectedIcon%`nTo: %CurrentGameId%.PNG`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    CopyIconToFolder(selectedIcon, CurrentGameId, CurrentGameTitle)
return

CopyIconToFolder(sourcePath, gameId, gameTitle) {
    GuiControl,, StatusText, Copying icon to rpcl3_icons folder...

    ; Build the icons folder path explicitly in the function
    iconsDir := A_ScriptDir . "\rpcl3_icons"
    destPath := iconsDir . "\" . gameId . ".PNG"

    ; Create the icons directory
    FileCreateDir, %iconsDir%

    ; Verify folder was created
    if !FileExist(iconsDir) {
        MsgBox, 16, Folder Error, Could not create icons folder: %iconsDir%
        return
    }

    ; Check source file exists
    if !FileExist(sourcePath) {
        MsgBox, 16, Source Error, Source file does not exist: %sourcePath%
        return
    }

    ; Delete destination if it exists to ensure clean copy
    if FileExist(destPath) {
        FileDelete, %destPath%
    }

    ; Copy the file
    FileCopy, %sourcePath%, %destPath%, 1

    ; Check if copy was successful
    if (ErrorLevel) {
        GuiControl,, StatusText, Error: Failed to copy icon file
        errorMsg := "Failed to copy icon file"
        errorMsg .= "`nSource: " . sourcePath
        errorMsg .= "`nDestination: " . destPath
        errorMsg .= "`nErrorLevel: " . ErrorLevel
        MsgBox, 16, Copy Error, %errorMsg%
        return
    }

    ; Verify the file was actually copied
    if !FileExist(destPath) {
        MsgBox, 16, Copy Verification Failed, File not found after copy: %destPath%
        return
    }

    ; Get file size
    FileGetSize, destSize, %destPath%

    ; Success
    statusText := "Success: Icon copied to " . gameId . ".PNG (" . destSize . " bytes)"
    GuiControl,, StatusText, %statusText%

    GuiControl,, IconInFolder, Yes (%destSize% bytes)
    GuiControl,, CurrentIcon, %destPath%
    GuiControl,, IconStatus, Copied to rpcl3_icons folder (click to view Pic1)

    successMsg := "Icon successfully copied!"
    successMsg .= "`nTo: " . destPath
    successMsg .= "`nSize: " . destSize . " bytes"
    MsgBox, 64, Success, %successMsg%

    ; Refresh display
    Gosub, GameSelected
}

DeleteIconFromFolder:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Check if icon exists in folder - explicit path building
    IconInFolder := A_ScriptDir . "\rpcl3_icons\" . CurrentGameId . ".PNG"
    if !FileExist(IconInFolder) {
        MsgBox, 48, No Icon, No icon found in rpcl3_icons folder for this game.`nLooking for: %IconInFolder%
        return
    }

    ; Confirm deletion
    MsgBox, 4, Confirm Delete, Delete the icon from rpcl3_icons folder?`n`nFile: %IconInFolder%`nGame: %CurrentGameTitle%`n`nNote: This will not delete the original file.

    IfMsgBox, No
        return

    ; Delete the file
    FileDelete, %IconInFolder%

    if (ErrorLevel) {
        GuiControl,, StatusText, Error: Failed to delete icon file
        MsgBox, 16, Delete Error, Failed to delete icon file:`n%IconInFolder%`n`nError: %ErrorLevel%
        return
    }

    ; Verify deletion
    if FileExist(IconInFolder) {
        MsgBox, 16, Delete Failed, File still exists after delete attempt
        return
    }

    ; Success
    GuiControl,, StatusText, Icon deleted from rpcl3_icons folder
    GuiControl,, IconInFolder, No

    ; Update preview to show original if available
    if (CurrentIconPath != "" && FileExist(CurrentIconPath)) {
        GuiControl,, CurrentIcon, %CurrentIconPath%
        GuiControl,, IconStatus, From original location (folder version deleted)
    } else {
        GuiControl,, CurrentIcon,
        GuiControl,, IconStatus, No icon available
    }

    MsgBox, 64, Success, Icon deleted from rpcl3_icons folder

    ; Refresh display
    Gosub, GameSelected
return

GuiClose:
    ; Stop any playing sound before closing
    SoundPlay, *-1
    db.CloseDB()
ExitApp
