Step 1: Add Global Array for Have Status
Add this to your global array declarations at the top:

; Global array declarations - ADD THIS SECTION
Global G_GameIds := []
Global G_GameTitles := []
Global G_EbootPaths := []
Global G_IconPaths := []
Global G_PicPaths := []
Global G_FavoriteStatus := []
Global G_HaveStatus := []  ; ADD THIS LINE
Global CurrentSelectedRow := 0
Step 2: Update Action Buttons Section
Replace your action buttons section with this (adds the Toggle Have button):

; Action buttons
Gui, Add, Button, gToggleFavorite x95 y450 w80 h25, Toggle Favorite
Gui, Add, Button, gToggleHave x180 y450 w80 h25, Toggle Have
Gui, Add, Button, gLaunchGame x270 y420 w80 h30, Launch
Gui, Add, Button, gClearSearch x270 y450 w80 h30, Clear
Step 3: Update All SQL Queries to Include Have Column
Update all your "Show" functions to include the Have column:

ShowAll:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowFavorites:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games WHERE Favorite = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowPlayed:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games WHERE Played = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowPSN:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games WHERE PSN = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowArcade:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games WHERE ArcadeGame = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return

ShowHave:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games WHERE Have = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return
Step 4: Update Search Function
Search:
    Gui, Submit, NoHide

    searchTerm := Trim(SearchTerm)
    if (searchTerm = "") {
        MsgBox, 48, Input Required, Please enter a search term.
        return
    }

    StringReplace, escapedTerm, searchTerm, ', '', All
    whereClause := "WHERE (GameTitle LIKE '%" . escapedTerm . "%' OR GameId LIKE '%" . escapedTerm . "%')"

    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games " . whereClause . " ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return
Step 5: Update PopulateResults Function
Replace your PopulateResults function with this updated version:

PopulateResults(result) {
    ; Make sure we're working with global arrays
    Global G_GameIds, G_GameTitles, G_EbootPaths, G_IconPaths, G_PicPaths, G_FavoriteStatus, G_HaveStatus

    ; Clear ListView
    LV_Delete()

    ; Extract result row count first
    resultRowCount := result.RowCount

    if (resultRowCount = 0) {
        LV_Add("", "", "No results found", "")
        ; Update counter to show 0 games
        GuiControl,, GameCounter, Games: 0
        ClearImagePreview()
        return
    }

    ; Clear and reinitialize arrays
    G_GameIds := []
    G_GameTitles := []
    G_EbootPaths := []
    G_IconPaths := []
    G_PicPaths := []
    G_FavoriteStatus := []
    G_HaveStatus := []

    ; Add results to ListView and store data
    Loop, %resultRowCount% {
        row := ""
        if result.GetRow(A_Index, row) {
            ; Store data in arrays (1-based indexing)
            G_GameIds[A_Index] := row[1]
            G_GameTitles[A_Index] := row[2]
            G_EbootPaths[A_Index] := row[3]
            G_FavoriteStatus[A_Index] := row[6]
            G_HaveStatus[A_Index] := row[7]  ; ADD THIS LINE

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

            ; Add row to ListView
            favoriteIcon := (row[6] = 1) ? "*" : ""
            LV_Add("", favoriteIcon, row[1], row[2])
        }
    }

    ; Update game counter display
    gameCount := G_GameIds.MaxIndex()
    if (gameCount = "") {
        gameCount := 0
    }
    GuiControl,, GameCounter, Games: %gameCount%

    ; Auto-resize columns
    LV_ModifyCol(1, 25)
    LV_ModifyCol(2, "AutoHdr")
    LV_ModifyCol(3, "AutoHdr")

    ClearImagePreview()
}
Step 6: Update Functions that Handle Button Updates
Update the UpdateFavoriteButton function to also handle the Have button:

UpdateFavoriteButton(rowIndex) {
    if (G_FavoriteStatus.MaxIndex() < rowIndex) {
        GuiControl,, Button9, Toggle Favorite  ; Adjust button number as needed
        GuiControl,, Button10, Toggle Have     ; Adjust button number as needed
        return
    }

    isFavorite := G_FavoriteStatus[rowIndex]
    if (isFavorite = 1) {
        GuiControl,, Button9, Remove Favorite
    } else {
        GuiControl,, Button9, Add Favorite
    }

    isHave := G_HaveStatus[rowIndex]
    if (isHave = 1) {
        GuiControl,, Button10, Remove Have
    } else {
        GuiControl,, Button10, Add Have
    }
}
Step 7: Add the ToggleHave Function
Add this new function:

ToggleHave:
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
    currentHave := G_HaveStatus[selectedRow]
    newHave := (currentHave = 1) ? 0 : 1

    StringReplace, escapedGameId, gameId, ', '', All
    sql := "UPDATE games SET Have = " . newHave . " WHERE GameId = '" . escapedGameId . "'"

    if !db.Exec(sql) {
        MsgBox, 16, Database Error, Failed to update have status
        return
    }

    G_HaveStatus[selectedRow] := newHave
    UpdateFavoriteButton(selectedRow)  ; This will now update both buttons

    statusText := (newHave = 1) ? "marked as owned" : "unmarked as owned"
    gameTitle := G_GameTitles[selectedRow]
    MsgBox, 64, Success, %gameTitle% has been %statusText%!
return
Step 8: Update ClearImagePreview Function
ClearImagePreview() {
    GuiControl,, GameIcon,
    GuiControl,, ImageStatus, Select a game to see its icon
    GuiControl,, Button9, Toggle Favorite
    GuiControl,, Button10, Toggle Have     ; ADD THIS LINE
    CurrentSelectedRow := 0
}
Step 9: Update ClearSearch Function
ClearSearch:
    GuiControl,, SearchTerm
    LV_Delete()
    ClearImagePreview()

    ; Reset game counter
    GuiControl,, GameCounter, Games: 0

    ; Clear arrays
    G_GameIds := []
    G_GameTitles := []
    G_EbootPaths := []
    G_IconPaths := []
    G_PicPaths := []
    G_FavoriteStatus := []
    G_HaveStatus := []  ; ADD THIS LINE
return
Now you'll have both a "Have" filter button and a "Toggle Have" button that work just like the favorite system. Users can mark games as owned/not owned, and filter to show only owned games.
