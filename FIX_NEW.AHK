; YouTube: @game_play267
; Twitch: RR_357000
; X:@relliK_2048
; Discord:
; Icon Manager
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
title := "RPCL3 Icon Manager - " . Chr(169) . " " . A_YYYY . " - Philip"
Gui, Color, 24292F
Gui, +AlwaysOnTop
Gui, Font, s10 q5, Segoe UI Emoji
Gui, Font, s10, Segoe UI

; Search/Select Game section
Gui, Add, GroupBox,                     x10 y5 w455 h115 cCCCCCC, Select Game
Gui, Add, Text,                         x20 y25 cCCCCCC, Search game:
Gui, Add, Text, vTotalGames             x230 y25 w180 h20 cCCCCCC, Total games in database: Loading...
Gui, Add, Edit, vSearchTerm             x20 y45 w200 h22
Gui, Add, Button, gSearchGames          x230 y45 w60 h20 cCCCCCC, Search
Gui, Add, ComboBox, vGameSelect         x20 y70 w435 h200 gGameSelected cCCCCCC, Select a game...
Gui, Add, Text, vStatusText             x20 y95 w440 h20 cCCCCCC, Ready. Select a game to manage its icon.

; Current Game Info section
Gui, Add, GroupBox,                     x10 y130 w455 h185 cCCCCCC, Current Game Info
Gui, Add, Text,                         x20 y150 cCCCCCC, Selected Game:
Gui, Add, Text, vSelectedGame           x20 y170 w440 h20 cCCCCCC, None selected
Gui, Add, Text,                         x20 y190 cCCCCCC, Current Icon Path:
Gui, Add, Text, vCurrentIconPath        x20 y210 w440 h20 cCCCCCC, -
Gui, Add, Text,                         x20 y230 cCCCCCC, Icon in rpcl3_icons:
Gui, Add, Text, vIconInFolder           x20 y250 w200 h20 cCCCCCC, Checking...
Gui, Add, Text,                         x20 y270 cCCCCCC, Sound File (SND0):
Gui, Add, Text, vSoundFileInfo          x20 y290 w200 h20 cCCCCCC, Checking...

; Icon Preview section
Gui, Add, GroupBox,                     x10 y325 w280 h185 cCCCCCC, Current Icon Preview
Gui, Add, Picture, vCurrentIcon         x20 y350 w260 h145 gShowPic1, ; Added gShowPic1 to make icon clickable
Gui, Add, Text, vIconStatus             x20 y485 w260 h20 cCCCCCC, No icon loaded

; Sound Control section
Gui, Add, GroupBox,                     x300 y325 w165 h75 cCCCCCC, Sound Control
Gui, Add, Button, gPlaySound            x310 y350 w70 h20 cCCCCCC, Play
Gui, Add, Button, gStopSound            x385 y350 w70 h20 cCCCCCC, Stop
Gui, Add, Text, vSoundStatus            x310 y375 w150 h20 cCCCCCC, No sound loaded

; Icon Actions section
Gui, Add, GroupBox,                     x300 y410 w165 h100 cCCCCCC, Icon Actions
Gui, Add, Button, gCopyExistingIcon     x310 y430 w145 h20 cCCCCCC, Copy Icon to Folder
Gui, Add, Button, gBrowseAndCopyIcon    x310 y455 w145 h20 cCCCCCC, Browse and Copy Icon
Gui, Add, Button, gDeleteIconFromFolder x310 y480 w145 h20 cCCCCCC, Delete Icon from Folder

Gui, Show, w475 h520, %title%

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
        MsgBox, 16, Count Query Failed, Query failed: %errMsg%
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
    ; Handle different path structures for disc games vs PSN games
    if (CurrentIcon0Path != "") {
        CurrentIcon0Path := LTrim(CurrentIcon0Path, "\/")

        ; Check if path starts with known PSN or disc game prefixes
        if (SubStr(CurrentIcon0Path, 1, 8) = "dev_hdd0" || SubStr(CurrentIcon0Path, 1, 5) = "games") {
            ; Path already includes the proper prefix, use as-is
            CurrentIconPath := A_ScriptDir . "\" . CurrentIcon0Path
        } else {
            ; Legacy path without prefix, assume it's a disc game
            CurrentIconPath := A_ScriptDir . "\games\" . CurrentIcon0Path
        }
    } else {
        CurrentIconPath := ""
    }

    ; Build the full path to Pic1 file (same logic)
    if (CurrentPic1Path != "") {
        CurrentPic1Path := LTrim(CurrentPic1Path, "\/")

        ; Check if path starts with known PSN or disc game prefixes
        if (SubStr(CurrentPic1Path, 1, 8) = "dev_hdd0" || SubStr(CurrentPic1Path, 1, 5) = "games") {
            ; Path already includes the proper prefix, use as-is
            CurrentPic1FullPath := A_ScriptDir . "\" . CurrentPic1Path
        } else {
            ; Legacy path without prefix, assume it's a disc game
            CurrentPic1FullPath := A_ScriptDir . "\games\" . CurrentPic1Path
        }
    } else {
        CurrentPic1FullPath := ""
    }

    ; Build the full path to Snd0 file with special PSN handling
    if (CurrentSnd0Path != "") {
        CurrentSnd0Path := LTrim(CurrentSnd0Path, "\/")

        ; Check if path starts with known PSN or disc game prefixes
        if (SubStr(CurrentSnd0Path, 1, 8) = "dev_hdd0" || SubStr(CurrentSnd0Path, 1, 5) = "games") {
            ; Path already includes the proper prefix, use as-is
            CurrentSnd0FullPath := A_ScriptDir . "\" . CurrentSnd0Path
        } else {
            ; Legacy path without prefix, assume it's a disc game
            CurrentSnd0FullPath := A_ScriptDir . "\games\" . CurrentSnd0Path
        }
    } else {
        ; No Snd0 path in database, try PSN default location
        ; For PSN games, check if SND0.AT3 exists in dev_hdd0\game\<GAME_ID>\SND0.AT3
        psnSoundPath := A_ScriptDir . "\dev_hdd0\game\" . CurrentGameId . "\SND0.AT3"
        if FileExist(psnSoundPath) {
            CurrentSnd0FullPath := psnSoundPath
        } else {
            CurrentSnd0FullPath := ""
        }
    }

    ; If we still don't have a sound file, try additional PSN locations
    if (CurrentSnd0FullPath = "" || !FileExist(CurrentSnd0FullPath)) {
        ; Try alternative PSN sound file locations one by one
        psnLocation1 := A_ScriptDir . "\dev_hdd0\game\" . CurrentGameId . "\SND0.AT3"
        psnLocation2 := A_ScriptDir . "\dev_hdd0\game\" . CurrentGameId . "\USRDIR\SND0.AT3"

        ; Check first location
        if FileExist(psnLocation1) {
            CurrentSnd0FullPath := psnLocation1
        } else if FileExist(psnLocation2) {
            ; Check second location
            CurrentSnd0FullPath := psnLocation2
        }
    }

    ; Check for icon in rpcl3_icons folder - explicit path building
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

    ; Check and handle sound file with automatic conversion
    if (CurrentSnd0FullPath != "" && FileExist(CurrentSnd0FullPath)) {
        FileGetSize, soundSize, %CurrentSnd0FullPath%

        ; Show where the sound file was found
        if (InStr(CurrentSnd0FullPath, "dev_hdd0")) {
            GuiControl,, SoundFileInfo, Found PSN (%soundSize% bytes)
        } else {
            GuiControl,, SoundFileInfo, Found (%soundSize% bytes)
        }

        ; Auto-play the sound using the new conversion system
        if (PlaySoundFile(CurrentSnd0FullPath)) {
            ; Sound played successfully
        } else {
            GuiControl,, SoundStatus, Failed to play sound file
        }

    } else if (CurrentSnd0FullPath != "") {
        GuiControl,, SoundFileInfo, File not found
        GuiControl,, SoundStatus, Sound file not found: %CurrentSnd0FullPath%
    } else {
        GuiControl,, SoundFileInfo, No sound file found
        GuiControl,, SoundStatus, No sound file found (checked PSN locations)
    }

    GuiControl,, StatusText, Game selected: %CurrentGameTitle%
return


; Function to handle AT3 conversion and playback
PlaySoundFile(soundPath) {
    if (soundPath = "" || !FileExist(soundPath)) {
        GuiControl,, SoundStatus, No sound file available
        return false
    }

    ; Check if it's an AT3 file that needs conversion
    SplitPath, soundPath, , dir, ext, name
    StringLower, ext, ext  ; Convert to lowercase for comparison

    if (ext = "at3") {
        ; Convert AT3 to WAV
        wavPath := dir . "\" . name . ".wav"

        ; Check if WAV already exists and is newer than AT3
        if FileExist(wavPath) {
            FileGetTime, at3Time, %soundPath%
            FileGetTime, wavTime, %wavPath%
            if (wavTime >= at3Time) {
                ; WAV is newer or same age, use it
                SoundPlay, %wavPath%
                GuiControl,, SoundStatus, Playing converted WAV: %name%.wav
                return true
            }
        }

        ; Need to convert AT3 to WAV
        GuiControl,, SoundStatus, Converting AT3 to WAV...
        if (ConvertAt3ToWav(soundPath, wavPath)) {
            SoundPlay, %wavPath%
            GuiControl,, SoundStatus, Playing converted WAV: %name%.wav
            return true
        } else {
            GuiControl,, SoundStatus, Failed to convert AT3 file
            return false
        }
    } else {
        ; Not an AT3 file, try to play directly
        SoundPlay, %soundPath%
        GuiControl,, SoundStatus, Playing: %soundPath%
        return true
    }
}


; Function to convert AT3 to WAV
ConvertAt3ToWav(at3Path, wavPath) {
    exe := A_ScriptDir . "\tools\vgmstream-cli.exe"

    ; Check if conversion tool exists
    if (!FileExist(exe)) {
        GuiControl,, StatusText, Error: vgmstream-cli.exe not found in tools folder
        MsgBox, 48, Missing Tool, Missing vgmstream-cli.exe`n`nPlace the file in: %A_ScriptDir%\tools\vgmstream-cli.exe
        return false
    }

    ; Build conversion command
    cmd := """" . exe . """ """ . at3Path . """ -o """ . wavPath . """"

    ; Show conversion status
    GuiControl,, StatusText, Converting AT3 to WAV...

    ; Run conversion (with timeout)
    RunWait, %cmd%,, Hide UseErrorLevel

    ; Check if conversion succeeded
    if (ErrorLevel = 0 && FileExist(wavPath)) {
        FileGetSize, wavSize, %wavPath%
        GuiControl,, StatusText, AT3 conversion successful (%wavSize% bytes)
        return true
    } else {
        GuiControl,, StatusText, AT3 conversion failed (Error: %ErrorLevel%)
        return false
    }
}


PlaySound:
    if (CurrentSnd0FullPath = "") {
        MsgBox, 48, No Sound File, No sound file available for the selected game.
        return
    }

    if !FileExist(CurrentSnd0FullPath) {
        MsgBox, 48, File Not Found, Sound file not found:`n%CurrentSnd0FullPath%
        return
    }

    ; Use the new conversion system
    if (PlaySoundFile(CurrentSnd0FullPath)) {
        GuiControl,, StatusText, Playing sound file...
    } else {
        GuiControl,, StatusText, Failed to play sound file
    }
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
    Gui, Pic1:Add, Picture, x10 y10 w600 h430 vPic1Image gShowPic1Fullscreen, %CurrentPic1FullPath%

    ; Add info text
    infoText := "Game: " . CurrentGameTitle . " (" . CurrentGameId . ")"
    infoText .= "`nPic1 Path: " . CurrentPic1FullPath
    infoText .= "`nFile Size: " . pic1Size . " bytes"
    infoText .= "`nClick image to view fullscreen (ESC to close fullscreen)"
    infoText .= "`nIn full screen use M to switch image between monitors"
    Gui, Pic1:Add, Text, x10 y410 w600 h90 vPic1Info, %infoText%

    ; Show the window positioned to the right of main GUI
    Gui, Pic1:Show, x%pic1X% y%pic1Y% w620 h500
return


ShowPic1Fullscreen:
    ; Store the current monitor number globally
    if (!CurrentFullscreenMonitor)
        CurrentFullscreenMonitor := 1

    ; Get monitor info
    SysGet, MonitorCount, MonitorCount
    SysGet, Monitor, Monitor, %CurrentFullscreenMonitor%

    ; Calculate dimensions
    ; MonWidth := MonitorRight - MonitorLeft ; comment to fill width
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
    topMargin := Floor(MonHeight * 0.01)  ; 5% from top

    ; Add picture - only specify width to maintain aspect ratio, remove width to fill width
    ; Gui, Fullscreen:Add, Picture, x%centerX% y%topMargin% w%imgWidth% vFullscreenImage, %CurrentPic1FullPath%
    Gui, Fullscreen:Add, Picture, x%centerX% y%topMargin% vFullscreenImage, %CurrentPic1FullPath%

    ; Add instructions with monitor switching info
    instructions := "Press ESC to close | Press M to switch to next monitor (" . CurrentFullscreenMonitor . "/" . MonitorCount . ")"
    Gui, Fullscreen:Add, Text, x20 y20 w600 h30 cWhite BackgroundTrans, %instructions%

    ; Show on current monitor
    Gui, Fullscreen:Show, x%MonitorLeft% y%MonitorTop% h%MonHeight%

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
