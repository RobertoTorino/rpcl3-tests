# Tests for RPCL3


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
            ; Store data - AHK v1 needs different syntax for dynamic array assignment
            rowIdx := A_Index
            
            ; Direct assignment to global variables
            GameIds%rowIdx% := row[1]
            GameTitles%rowIdx% := row[2]  
            EbootPaths%rowIdx% := row[3]
            
            ; Debug for first row only
            if (A_Index = 1) {
                testGameId := GameIds1
                testTitle := GameTitles1
                testEboot := EbootPaths1
                MsgBox, 0, Debug Storage, Stored in arrays:`nGameIds1: %testGameId%`nGameTitles1: %testTitle%`nEbootPaths1: %testEboot%
            }
            
            ; Construct full paths from script directory
            rawIconPath := row[4]
            rawPicPath := row[5]
            
            ; Build full icon path
            if (rawIconPath != "") {
                cleanIconPath := LTrim(rawIconPath, "\/")
                fullIconPath := A_ScriptDir . "\" . cleanIconPath
                IconPaths%rowIdx% := fullIconPath
            } else {
                IconPaths%rowIdx% := ""
            }
            
            ; Build full pic path  
            if (rawPicPath != "") {
                cleanPicPath := LTrim(rawPicPath, "\/")
                fullPicPath := A_ScriptDir . "\" . cleanPicPath
                PicPaths%rowIdx% := fullPicPath
            } else {
                PicPaths%rowIdx% := ""
            }
            
            FavoriteStatus%rowIdx% := row[6]
            
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



LaunchGame:
selectedRow := LV_GetNext()
if (!selectedRow) {
MsgBox, 48, No Selection, Please select a game from the list.
return
}

    ; Get game info from stored arrays - AHK v1 syntax
    gameId := GameIds%selectedRow%
    gameTitle := GameTitles%selectedRow%
    ebootPath := EbootPaths%selectedRow%
    
    ; Debug what we retrieved
    MsgBox, 0, Debug Retrieved, Row: %selectedRow%`nGameId: %gameId%`nTitle: %gameTitle%`nEboot: %ebootPath%

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














