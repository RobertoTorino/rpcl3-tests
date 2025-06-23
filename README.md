# Tests for RPCL3


PopulateResults(result) {
; Clear and populate ListView - same code used by all functions
LV_Delete()

    if (result.RowCount = 0) {
        LV_Add("", "No results found", "")
        ClearImagePreview()
        return
    }

    ; Add results to ListView and store paths
    Loop, % result.RowCount {
        row := ""
        if result.GetRow(A_Index, row) {
            ; Store all the paths and info in global arrays - NOW CONSISTENT
            ; row[1] = GameId, row[2] = GameTitle, row[3] = Eboot, row[4] = Icon0, row[5] = Pic1, row[6] = Favorite
            GameIds%A_Index% := row[1]
            GameTitles%A_Index% := row[2]
            EbootPaths%A_Index% := row[3]  ; Store Eboot path
            
            ; Debug: Log what we're storing
            ; MsgBox, 0, Debug, Row %A_Index%:`nGameId: %row[1]%`nTitle: %row[2]%`nEboot: %row[3]%
            
            ; Construct full paths from script directory
            rawIconPath := row[4]
            rawPicPath := row[5]
            
            ; Build full icon path
            if (rawIconPath != "") {
                cleanIconPath := LTrim(rawIconPath, "\/")
                IconPaths%A_Index% := A_ScriptDir . "\" . cleanIconPath
            } else {
                IconPaths%A_Index% := ""
            }
            
            ; Build full pic path  
            if (rawPicPath != "") {
                cleanPicPath := LTrim(rawPicPath, "\/")
                PicPaths%A_Index% := A_ScriptDir . "\" . cleanPicPath
            } else {
                PicPaths%A_Index% := ""
            }
            
            FavoriteStatus%A_Index% := row[6]
            
            ; Add row with star if favorite
            favoriteIcon := (row[6] = 1) ? "★" : ""
            LV_Add("", favoriteIcon, row[1], row[2])
        }
    }

    ; Auto-resize columns
    LV_ModifyCol(1, 25)   ; Keep star column small
    LV_ModifyCol(2, "AutoHdr")
    LV_ModifyCol(3, "AutoHdr")

    ; Clear image preview
    ClearImagePreview()
}





LaunchGame:
; Get selected row
selectedRow := LV_GetNext()
if (!selectedRow) {
MsgBox, 48, No Selection, Please select a game from the list.
return
}

    ; Debug: Show what row is selected
    ; MsgBox, 0, Debug, Selected row: %selectedRow%

    ; Get game info from stored arrays instead of ListView
    gameId := GameIds%selectedRow%
    gameTitle := GameTitles%selectedRow%
    ebootPath := EbootPaths%selectedRow%

    ; Debug: Show what we retrieved
    ; MsgBox, 0, Debug, GameId: %gameId%`nTitle: %gameTitle%`nEboot: %ebootPath%

    ; More detailed error checking
    if (gameId = "") {
        MsgBox, 16, Error, No game ID found for row %selectedRow%.`nTry refreshing your search.
        return
    }

    if (ebootPath = "") {
        MsgBox, 16, Error, Could not find Eboot path for selected game.`nRow: %selectedRow%`nGameId: %gameId%`nTitle: %gameTitle%`n`nTry refreshing your search.
        return
    }

    ; Confirm launch
    msg := "Launch this game?`n`nGame ID: " . gameId . "`nTitle: " . gameTitle . "`nEboot: " . ebootPath
    MsgBox, 4, Confirm Launch, %msg%

    IfMsgBox, Yes
    {
        runCommand := "rpcs3.exe --no-gui --fullscreen """ ebootPath """"
        IniWrite, %runCommand%, %A_ScriptDir%\launcher.ini, RUN_GAME, RunCommand
        MsgBox, 64, Success, Game launch command written to INI:`n%runCommand%
    }
return




Quick test: Voeg dit toe aan het begin van LaunchGame om te zien wat er werkelijk is opgeslagen:

LaunchGame:
selectedRow := LV_GetNext()

    ; Quick debug - show all stored values for this row
    MsgBox, 0, Debug All, Row: %selectedRow%`nGameId: %GameIds%selectedRow%`nTitle: %GameTitles%selectedRow%`nEboot: %EbootPaths%selectedRow%`nIcon: %IconPaths%selectedRow%`nPic: %PicPaths%selectedRow%
