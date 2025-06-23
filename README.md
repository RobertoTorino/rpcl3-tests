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
            ; Store data using proper AHK v1 syntax for dynamic variables
            GameId%A_Index% := row[1]
            GameTitle%A_Index% := row[2]
            EbootPath%A_Index% := row[3]
            
            ; Test storage for first row
            if (A_Index = 1) {
                MsgBox, 0, Test Storage, Direct test:`nGameId1: %GameId1%`nGameTitle1: %GameTitle1%`nEbootPath1: %EbootPath1%
            }
            
            ; Construct full paths from script directory
            rawIconPath := row[4]
            rawPicPath := row[5]
            
            ; Build full icon path
            if (rawIconPath != "") {
                cleanIconPath := LTrim(rawIconPath, "\/")
                fullIconPath := A_ScriptDir . "\" . cleanIconPath
                IconPath%A_Index% := fullIconPath
            } else {
                IconPath%A_Index% := ""
            }
            
            ; Build full pic path  
            if (rawPicPath != "") {
                cleanPicPath := LTrim(rawPicPath, "\/")
                fullPicPath := A_ScriptDir . "\" . cleanPicPath
                PicPath%A_Index% := fullPicPath
            } else {
                PicPath%A_Index% := ""
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






LaunchGame:
selectedRow := LV_GetNext()
if (!selectedRow) {
MsgBox, 48, No Selection, Please select a game from the list.
return
}

    ; Get game info using correct variable names
    gameId := GameId%selectedRow%
    gameTitle := GameTitle%selectedRow%
    ebootPath := EbootPath%selectedRow%
    
    ; Debug what we retrieved
    MsgBox, 0, Debug Retrieved, Row: %selectedRow%`nGameId: %gameId%`nTitle: %gameTitle%`nEboot: %ebootPath%

    if (gameId = "") {
        MsgBox, 16, Error, No game ID found for row %selectedRow%.
        return
    }

    if (ebootPath = "") {
        MsgBox, 16, Error, Could not find Eboot path for selected game.`nRow: %selectedRow%`nGameId: %gameId%`nTitle: %gameTitle%
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

ShowGameIcon(rowIndex) {
; Get the constructed full icon path - updated variable name
iconPath := IconPath%rowIndex%

    if (iconPath != "" && FileExist(iconPath)) {
        GuiControl,, GameIcon, %iconPath%
        GuiControl,, ImageStatus, Click icon for larger view
        CurrentSelectedRow := rowIndex
    } else {
        GuiControl,, GameIcon,
        if (iconPath != "") {
            GuiControl,, ImageStatus, Icon not found: %iconPath%
        } else {
            GuiControl,, ImageStatus, No icon path available
        }
        CurrentSelectedRow := rowIndex
    }
}

ShowLargeImage:
if (CurrentSelectedRow <= 0)
return

    ; Get the constructed full pic path - updated variable name
    picPath := PicPath%CurrentSelectedRow%

    if (picPath = "" || !FileExist(picPath)) {
        if (picPath != "") {
            MsgBox, 48, Image Not Found, Large image file not found:`n%picPath%
        } else {
            MsgBox, 48, Image Not Found, No large image path available for this game.
        }
        return
    }

    Gui, 2: New, +Resize +MaximizeBox, Game Image
    Gui, 2: Add, Picture, x10 y10, %picPath%
    Gui, 2: Show, w600 h400
return

UpdateFavoriteButton(rowIndex) {
isFavorite := FavoriteStatus%rowIndex%
if (isFavorite = 1) {
GuiControl,, Button9, Remove Favorite
} else {
GuiControl,, Button9, Add Favorite
}
}

ToggleFavorite:
selectedRow := LV_GetNext()
if (!selectedRow) {
MsgBox, 48, No Selection, Please select a game from the list.
return
}

    ; Updated variable names
    gameId := GameId%selectedRow%
    currentFavorite := FavoriteStatus%selectedRow%
    newFavorite := (currentFavorite = 1) ? 0 : 1

    StringReplace, escapedGameId, gameId, ', '', All
    sql := "UPDATE games SET Favorite = " . newFavorite . " WHERE GameId = '" . escapedGameId . "'"

    if !db.Exec(sql) {
        MsgBox, 16, Database Error, Failed to update favorite status
        return
    }

    FavoriteStatus%selectedRow% := newFavorite
    favoriteIcon := (newFavorite = 1) ? "★" : ""
    LV_Modify(selectedRow, Col1, favoriteIcon)
    UpdateFavoriteButton(selectedRow)

    statusText := (newFavorite = 1) ? "added to" : "removed from"
    gameTitle := GameTitle%selectedRow%
    MsgBox, 64, Success, %gameTitle% has been %statusText% favorites!
return

ClearSearch:
GuiControl,, SearchTerm
LV_Delete()
ClearImagePreview()

    ; Clear all arrays with updated names
    Loop, 50 {
        GameId%A_Index% := ""
        GameTitle%A_Index% := ""
        EbootPath%A_Index% := ""
        IconPath%A_Index% := ""
        PicPath%A_Index% := ""
        FavoriteStatus%A_Index% := ""
    }
return


















