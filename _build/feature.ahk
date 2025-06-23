Step 1: Add the "Have" Column to Your Database
First, you'll need to add the "Have" column to your existing database. You can do this by running this SQL command once (you can add it temporarily to your script or use a database management tool):

; Add this near the top of your script, after the database connection - run once to add the column
sql := "ALTER TABLE games ADD COLUMN Have INTEGER DEFAULT 0"
if !db.Exec(sql) {
    ; Column might already exist, ignore error
}
Step 2: Modify the Quick Access Buttons Section
Replace this section in your GUI:

; Quick access buttons section
Gui, Add, GroupBox, x10 y10 w380 h60, Quick Access
Gui, Add, Button, gShowAll x20 y30 w60 h20, Show All
Gui, Add, Button, gShowFavorites x85 y30 w60 h20, Favorites
Gui, Add, Button, gShowPlayed x150 y30 w50 h20, Played
Gui, Add, Button, gShowPSN x205 y30 w40 h20, PSN
Gui, Add, Button, gShowArcade x250 y30 w50 h20, Arcade
With this (to make room for the "Have" button):

; Quick access buttons section
Gui, Add, GroupBox, x10 y10 w380 h80, Quick Access
Gui, Add, Button, gShowAll x20 y30 w60 h20, Show All
Gui, Add, Button, gShowFavorites x85 y30 w60 h20, Favorites
Gui, Add, Button, gShowPlayed x150 y30 w50 h20, Played
Gui, Add, Button, gShowPSN x205 y30 w40 h20, PSN
Gui, Add, Button, gShowArcade x250 y30 w50 h20, Arcade
Gui, Add, Button, gShowHave x320 y30 w40 h20, Have
Step 3: Adjust Other GUI Elements
Since the Quick Access section is now taller, adjust the Y positions of elements below it:

; Search section - change y80 to y100
Gui, Add, GroupBox, x10 y100 w380 h60, Search
Gui, Add, Text, x20 y120, Game title or ID:
Gui, Add, Edit, vSearchTerm x120 y117 w180 h20
Gui, Add, Button, gSearch x310 y117 w70 h23, Search

; Results section - change y150 to y170
Gui, Add, GroupBox, x10 y170 w380 h220, Results
Gui, Add, ListView, vResultsList x20 y190 w360 h170 Grid -Multi AltSubmit gListViewClick, *|Game ID|Title

; Update the total games counter position
Gui, Add, Text, vTotalGamesCounter x310 y52 w70 h16 +Right, Total: 0

; Image preview section - change y380 to y400
Gui, Add, GroupBox, x10 y400 w380 h100, Game Preview
Gui, Add, Picture, vGameIcon x20 y420 w64 h64 gShowLargeImage,
Gui, Add, Text, vImageStatus x95 y420, Select a game to see its icon

; Action buttons - change y positions accordingly
Gui, Add, Button, gToggleFavorite x95 y450 w90 h25, Toggle Favorite
Gui, Add, Button, gLaunchGame x200 y420 w80 h30, Launch
Gui, Add, Button, gClearSearch x290 y420 w80 h30, Clear

; Adjust main window height
Gui, Show, w400 h520, Game Search Launcher
Step 4: Add the ShowHave Function
Add this function after your other "Show" functions:

ShowHave:
    sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite FROM games WHERE Have = 1 ORDER BY GameTitle LIMIT 50"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, % "Query failed:`n" . db.ErrorMsg
        return
    }

    PopulateResults(result)
return
Step 5: Update SQL Queries to Include Have Column (Optional)
If you want to store and display the "Have" status in your arrays (similar to favorites), you can modify your queries to include the Have column. For example, in your search function:

sql := "SELECT GameId, GameTitle, Eboot, Icon0, Pic1, Favorite, Have FROM games " . whereClause . " ORDER BY GameTitle LIMIT 50"
And add a global array for Have status:

Global G_HaveStatus := []
Then in your PopulateResults function, you would store and handle the Have status similar to how you handle favorites.

Step 6: Add the Database Column (One-time Setup)
Add this code temporarily at the beginning of your script (after the database connection) to add the column if it doesn't exist:

; One-time database update - add Have column
sql := "PRAGMA table_info(games)"
if db.GetTable(sql, tableInfo) {
    hasHaveColumn := false
    Loop, % tableInfo.RowCount {
        row := ""
        if tableInfo.GetRow(A_Index, row) {
            if (row[2] = "Have") {
                hasHaveColumn := true
                break
            }
        }
    }

    if (!hasHaveColumn) {
        sql := "ALTER TABLE games ADD COLUMN Have INTEGER DEFAULT 0"
        if !db.Exec(sql) {
            MsgBox, 16, Database Error, Failed to add Have column
        }
    }
}
After running your script once with this code, you can remove it as the column will be permanently added to your database.

The "Have" button will now work just like your other filter buttons (PSN, Played, etc.) and show only games where the Have column is set to 1.
