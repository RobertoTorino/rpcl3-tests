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

    ; Get search term
    searchTerm := Trim(SearchTerm)
    if (searchTerm = "") {
        MsgBox, 48, Input Required, Please enter a search term.
        return
    }

    ; Build filters array
    filters := []
    if (FilterFavorite)
        filters.Push("Favorite = 1")
    if (FilterPlayed)
        filters.Push("Played = 1")
    if (FilterPSN)
        filters.Push("PSN = 1")
    if (FilterArcadeGame)
        filters.Push("ArcadeGame = 1")

    ; Build WHERE clause - fix for AHK v1
    StringReplace, escapedTerm, searchTerm, ', '', All
    whereClause := "WHERE (GameTitle LIKE '%" . escapedTerm . "%' OR GameId LIKE '%" . escapedTerm . "%')"

    if (filters.MaxIndex() > 0)
        whereClause .= " AND " . Join(" AND ", filters)

    ; Execute query - INCLUDE Favorite column to match other functions
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games " . whereClause . " ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return


ShowAll:
    Gui, Submit, NoHide

    ; Build filters for Show All (no search term)
    filters := []
    if (FilterFavorite)
        filters.Push("Favorite = 1")
    if (FilterPlayed)
        filters.Push("Played = 1")
    if (FilterPSN)
        filters.Push("PSN = 1")
    if (FilterArcadeGame)
        filters.Push("ArcadeGame = 1")

    ; Build WHERE clause for Show All - same logic as Search but without search term
    if (filters.MaxIndex() > 0) {
        whereClause := "WHERE " . Join(" AND ", filters)
        sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games " . whereClause . " ORDER BY GameTitle LIMIT 50"
    } else {
        ; No filters at all - show everything - INCLUDE Favorite column
        sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games ORDER BY GameTitle LIMIT 50"
    }

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return


ShowFavorites:
    ; Show only favorite games - INCLUDE Favorite column
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE Favorite = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return


ShowPlayed:
    ; Show only played games - INCLUDE Favorite column
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE Played = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return


ShowPSN:
    ; Show only PSN games - INCLUDE Favorite column
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE PSN = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return


ShowArcade:
    ; Show only Arcade games - INCLUDE Favorite column
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE ArcadeGame = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
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



ListViewClick:
    ; Handle ListView selection change
    selectedRow := LV_GetNext()
    if (selectedRow > 0) {
        ShowGameIcon(selectedRow)
        UpdateFavoriteButton(selectedRow)
    } else {
        ClearImagePreview()
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


2GuiClose:
    Gui, 2: Destroy
return


ClearImagePreview() {
    GuiControl,, GameIcon, ; Clear the image
    GuiControl,, ImageStatus, Select a game to see its icon
    GuiControl,, Button9, Toggle Favorite  ; Reset button text
    CurrentSelectedRow := 0
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


; Helper function for joining array elements - for AHK v1
Join(sep, ByRef arr) {
out := ""
for index, val in arr
out .= (index > 1 ? sep : "") . val
return out
}


; Double-click on ListView item to launch
ResultsListDoubleClick:
    Gosub, LaunchGame
return


GuiClose:
ExitApp
