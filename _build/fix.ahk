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
            EbootPaths%A_Index% := row[3]  ; This was missing before!

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




-----

LaunchGame:
    ; Get selected row
    selectedRow := LV_GetNext()
    if (!selectedRow) {
        MsgBox, 48, No Selection, Please select a game from the list.
        return
    }

    ; Get game info from stored arrays instead of ListView
    gameId := GameIds%selectedRow%
    gameTitle := GameTitles%selectedRow%

    ; Get the stored Eboot path
    ebootPath := EbootPaths%selectedRow%

    if (ebootPath = "") {
        MsgBox, 16, Error, Could not find Eboot path for selected game.`nRow: %selectedRow%`nGameId: %gameId%
        return
    }

    ; Confirm launch
    msg := "Launch this game?`n`nGame ID: " . gameId . "`nTitle: " . gameTitle
    MsgBox, 4, Confirm Launch, %msg%

    IfMsgBox, Yes
    {
        runCommand := "rpcs3.exe --no-gui --fullscreen """ ebootPath """"
        IniWrite, %runCommand%, %A_ScriptDir%\launcher.ini, RUN_GAME, RunCommand
        MsgBox, 64, Success, Game launch command written to INI:`n%runCommand%
    }
return


---

ClearSearch:
    ; Clear search field and results
    GuiControl,, SearchTerm
    LV_Delete()
    ClearImagePreview()

    ; Clear stored paths - include all arrays
    Loop, 50 {
        GameIds%A_Index% := ""
        GameTitles%A_Index% := ""
        EbootPaths%A_Index% := ""
        IconPaths%A_Index% := ""
        PicPaths%A_Index% := ""
        FavoriteStatus%A_Index% := ""
    }
return

---


