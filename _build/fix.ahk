#SingleInstance Force
#NoEnv
#Include %A_ScriptDir%\tools\SQLiteDB.ahk

db := new SQLiteDB()
if !db.OpenDB(A_ScriptDir . "\games.db") {
    err := db.ErrorMsg
    MsgBox, 16, DB Error, Failed to open DB.`n%err%
    ExitApp
}

; Create integrated GUI
Gui, Font, s10, Segoe UI

; Quick access buttons section
Gui, Add, GroupBox, x10 y10 w380 h60, Quick Access
Gui, Add, Button, gShowAll x20 y30 w60 h20, Show All
Gui, Add, Button, gShowFavorites x85 y30 w60 h20, Favorites
Gui, Add, Button, gShowPlayed x150 y30 w50 h20, Played
Gui, Add, Button, gShowPSN x205 y30 w40 h20, PSN
Gui, Add, Button, gShowArcade x250 y30 w50 h20, Arcade

; Search section
Gui, Add, GroupBox, x10 y80 w380 h60, Search
Gui, Add, Text, x20 y100, Game title or ID:
Gui, Add, Edit, vSearchTerm x120 y97 w180 h20
Gui, Add, Button, gSearch x310 y97 w70 h23, Search

; Results section - ListView with favorite star column
Gui, Add, GroupBox, x10 y150 w380 h220, Results
Gui, Add, ListView, vResultsList x20 y170 w360 h170 Grid -Multi AltSubmit gListViewClick, ★|Game ID|Title
LV_ModifyCol(1, 25)  ; Star column
LV_ModifyCol(2, 80)  ; Game ID
LV_ModifyCol(3, 255) ; Title

; Image preview section
Gui, Add, GroupBox, x10 y380 w380 h100, Game Preview
Gui, Add, Picture, vGameIcon x20 y400 w64 h64 gShowLargeImage, ; Small icon preview
Gui, Add, Text, vImageStatus x95 y400, Select a game to see its icon

; Action buttons
Gui, Add, Button, gToggleFavorite x95 y430 w90 h25, Toggle Favorite
Gui, Add, Button, gLaunchGame x200 y400 w80 h30, Launch
Gui, Add, Button, gClearSearch x290 y400 w80 h30, Clear

Gui, Show, w400 h490, Game Search Launcher
return

Search:
    Gui, Submit, NoHide

    searchTerm := Trim(SearchTerm)
    if (searchTerm = "") {
        MsgBox, 48, Input Required, Please enter a search term.
        return
    }

    StringReplace, escapedTerm, searchTerm, ', '', All
    whereClause := "WHERE (GameTitle LIKE '%" . escapedTerm . "%' OR GameId LIKE '%" . escapedTerm . "%')"

    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games " . whereClause . " ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowAll:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowFavorites:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE Favorite = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowPlayed:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE Played = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowPSN:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE PSN = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowArcade:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE ArcadeGame = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

PopulateResults(result) {
    ; Clear ListView
    LV_Delete()

    if (result.RowCount = 0) {
        LV_Add("", "", "No results found", "")
        ClearImagePreview()
        return
    }

    ; Initialize arrays
    G_GameIds := []
    G_GameTitles := []
    G_EbootPaths := []
    G_IconPaths := []
    G_PicPaths := []
    G_FavoriteStatus := []

    ; Add results to ListView and store data
    Loop, % result.RowCount {
        row := ""
        if result.GetRow(A_Index, row) {
            ; Store data in arrays (1-based indexing)
            G_GameIds[A_Index] := row[1]
            G_GameTitles[A_Index] := row[2]
            G_EbootPaths[A_Index] := row[3]
            G_FavoriteStatus[A_Index] := row[6]

            ; Construct full paths
            rawIconPath := row[4]
            rawPicPath := row[5]

            if (rawIconPath != "") {
                cleanIconPath := LTrim(rawIconPath, "\/")
                G_IconPaths[A_Index] := A_ScriptDir . "\" . cleanIconPath
            } else {
                G_IconPaths[A_Index] := ""
            }

            if (rawPicPath != "") {
                cleanPicPath := LTrim(rawPicPath, "\/")
                G_PicPaths[A_Index] := A_ScriptDir . "\" . cleanPicPath
            } else {
                G_PicPaths[A_Index] := ""
            }

            ; Test storage for first row
            if (A_Index = 1) {
                MsgBox, 0, Test Array Storage, Array test:`nG_GameIds[1]: %G_GameIds[1]%`nG_GameTitles[1]: %G_GameTitles[1]%`nG_EbootPaths[1]: %G_EbootPaths[1]%
            }

            ; Add row to ListView
            favoriteIcon := (row[6] = 1) ? "★" : ""
            LV_Add("", favoriteIcon, row[1], row[2])
        }
    }

    ; Auto-resize columns
    LV_ModifyCol(1, 25)
    LV_ModifyCol(2, "AutoHdr")
    LV_ModifyCol(3, "AutoHdr")

    ClearImagePreview()
}

ListViewClick:
    selectedRow := LV_GetNext()
    if (selectedRow > 0) {
        ShowGameIcon(selectedRow)
        UpdateFavoriteButton(selectedRow)
    } else {
        ClearImagePreview()
    }
return

ShowGameIcon(rowIndex) {
    if (G_IconPaths.MaxIndex() < rowIndex) {
        GuiControl,, GameIcon,
        GuiControl,, ImageStatus, No data for this row
        return
    }

    iconPath := G_IconPaths[rowIndex]

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

UpdateFavoriteButton(rowIndex) {
    if (G_FavoriteStatus.MaxIndex() < rowIndex) {
        GuiControl,, Button9, Toggle Favorite
        return
    }

    isFavorite := G_FavoriteStatus[rowIndex]
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

    if (G_GameIds.MaxIndex() < selectedRow) {
        MsgBox, 48, No Data, No data found for selected row.
        return
    }

    gameId := G_GameIds[selectedRow]
    currentFavorite := G_FavoriteStatus[selectedRow]
    newFavorite := (currentFavorite = 1) ? 0 : 1

    StringReplace, escapedGameId, gameId, ', '', All
    sql := "UPDATE games SET Favorite = " . newFavorite . " WHERE GameId = '" . escapedGameId . "'"

    if !db.Exec(sql) {
        MsgBox, 16, Database Error, Failed to update favorite status
        return
    }

    G_FavoriteStatus[selectedRow] := newFavorite
    favoriteIcon := (newFavorite = 1) ? "★" : ""
    LV_Modify(selectedRow, Col1, favoriteIcon)
    UpdateFavoriteButton(selectedRow)

    statusText := (newFavorite = 1) ? "added to" : "removed from"
    gameTitle := G_GameTitles[selectedRow]
    MsgBox, 64, Success, %gameTitle% has been %statusText% favorites!
return

ShowLargeImage:
    if (CurrentSelectedRow <= 0 || G_PicPaths.MaxIndex() < CurrentSelectedRow)
        return

    picPath := G_PicPaths[CurrentSelectedRow]

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

2GuiClose:
    Gui, 2: Destroy
return

ClearImagePreview() {
    GuiControl,, GameIcon,
    GuiControl,, ImageStatus, Select a game to see its icon
    GuiControl,, Button9, Toggle Favorite
    CurrentSelectedRow := 0
}

LaunchGame:
    selectedRow := LV_GetNext()
    if (!selectedRow) {
        MsgBox, 48, No Selection, Please select a game from the list.
        return
    }

    ; Check if data exists for this row
    if (G_GameIds.MaxIndex() < selectedRow) {
        MsgBox, 16, No Data, No data found for row %selectedRow%.`nArray size: %G_GameIds.MaxIndex()%`nTry refreshing your search.
        return
    }

    ; Get game info from global arrays
    gameId := G_GameIds[selectedRow]
    gameTitle := G_GameTitles[selectedRow]
    ebootPath := G_EbootPaths[selectedRow]

    ; Debug what we retrieved
    MsgBox, 0, Debug Retrieved, Row: %selectedRow%`nArray Size: %G_GameIds.MaxIndex()%`nGameId: %gameId%`nTitle: %gameTitle%`nEboot: %ebootPath%

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

ClearSearch:
    GuiControl,, SearchTerm
    LV_Delete()
    ClearImagePreview()

    ; Clear arrays
    G_GameIds := []
    G_GameTitles := []
    G_EbootPaths := []
    G_IconPaths := []
    G_PicPaths := []
    G_FavoriteStatus := []
return

ResultsListDoubleClick:
    Gosub, LaunchGame
return

GuiClose:
ExitApp
