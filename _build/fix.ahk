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

    ; If we still don't have a sound file, try
