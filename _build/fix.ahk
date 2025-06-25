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

    ; Build the full path to Snd0 file (same logic)
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
        CurrentSnd0FullPath := ""
    }

    ; Rest of the GameSelected function remains the same...

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
        GuiControl,, SoundFileInfo, Found (%soundSize% bytes)

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
        GuiControl,, SoundFileInfo, No path in database
        GuiControl,, SoundStatus, No sound file path in database
    }

    GuiControl,, StatusText, Game selected: %CurrentGameTitle%
return
