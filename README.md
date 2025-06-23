# Tests for RPCL3


LaunchGame:
selectedRow := LV_GetNext()
if (!selectedRow) {
MsgBox, 48, No Selection, Please select a game from the list.
return
}

    ; Quick debug - show all stored values for this row (AHK v1 syntax)
    gameIdDebug := GameIds%selectedRow%
    titleDebug := GameTitles%selectedRow%
    ebootDebug := EbootPaths%selectedRow%
    iconDebug := IconPaths%selectedRow%
    picDebug := PicPaths%selectedRow%
    
    MsgBox, 0, Debug All, Row: %selectedRow%`nGameId: %gameIdDebug%`nTitle: %titleDebug%`nEboot: %ebootDebug%`nIcon: %iconDebug%`nPic: %picDebug%
    
    ; Get game info from stored arrays
    gameId := GameIds%selectedRow%
    gameTitle := GameTitles%selectedRow%
    ebootPath := EbootPaths%selectedRow%

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
    MsgBox, 4, Confirm Launch, Launch this game?`n`nGame ID: %gameId%`nTitle: %gameTitle%`nEboot: %ebootPath%

    IfMsgBox, Yes
    {
        runCommand := "rpcs3.exe --no-gui --fullscreen """ ebootPath """"
        IniWrite, %runCommand%, %A_ScriptDir%\launcher.ini, RUN_GAME, RunCommand
        MsgBox, 64, Success, Game launch command written to INI:`n%runCommand%
    }
return



PopulateResults(result) {
; Clear and populate ListView
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
            ; Store data (AHK v1 compatible)
            GameIds%A_Index% := row[1]
            GameTitles%A_Index% := row[2]
            EbootPaths%A_Index% := row[3]
            
            ; Debug for first row only (remove after testing)
            if (A_Index = 1) {
                row1 := row[1]
                row2 := row[2]
                row3 := row[3]
                row4 := row[4]
                row5 := row[5]
                row6 := row[6]
                MsgBox, 0, Debug Row 1, GameId: %row1%`nTitle: %row2%`nEboot: %row3%`nIcon0: %row4%`nPic1: %row5%`nFavorite: %row6%
            }
            
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
    LV_ModifyCol(1, 25)
    LV_ModifyCol(2, "AutoHdr")
    LV_ModifyCol(3, "AutoHdr")

    ; Clear image preview
    ClearImagePreview()
}






