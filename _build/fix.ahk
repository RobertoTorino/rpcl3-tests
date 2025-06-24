LoadTotalGames() {
    ; First, let's verify the database connection is working
    MsgBox, 0, Debug DB, Database handle exists: %!!db%

    ; Test if we can run any query at all
    testSql := "SELECT 1"
    if !db.GetTable(testSql, testResult) {
        errMsg := db.ErrorMsg
        GuiControl,, TotalGames, Total games: DB connection error - %errMsg%
        MsgBox, 16, DB Connection Test Failed, Basic query failed: %errMsg%
        return
    } else {
        MsgBox, 0, DB Connection Test, Basic query (SELECT 1) worked fine
    }

    ; Test if the games table exists
    tableTestSql := "SELECT name FROM sqlite_master WHERE type='table' AND name='games'"
    if !db.GetTable(tableTestSql, tableResult) {
        errMsg := db.ErrorMsg
        GuiControl,, TotalGames, Total games: Table check error - %errMsg%
        MsgBox, 16, Table Check Failed, Table existence check failed: %errMsg%
        return
    }

    if (tableResult.RowCount = 0) {
        GuiControl,, TotalGames, Total games: Table 'games' does not exist
        MsgBox, 16, Table Not Found, Table 'games' does not exist in the database
        return
    } else {
        MsgBox, 0, Table Check, Table 'games' exists in database
    }

    ; Try a simple SELECT to see if we can access the table
    simpleSql := "SELECT GameId FROM games LIMIT 1"
    if !db.GetTable(simpleSql, simpleResult) {
        errMsg := db.ErrorMsg
        GuiControl,, TotalGames, Total games: Cannot access table - %errMsg%
        MsgBox, 16, Table Access Failed, Cannot access games table: %errMsg%
        return
    } else {
        MsgBox, 0, Table Access, Can access games table successfully
    }

    ; Now try the count query with different variations
    countSql := "SELECT COUNT(GameId) FROM games"
    MsgBox, 0, Debug Count Query, About to execute: %countSql%

    if !db.GetTable(countSql, countResult) {
        errMsg := db.ErrorMsg
        GuiControl,, TotalGames, Total games: Count query failed - %errMsg%
        MsgBox, 16, Count Query Failed, Count query failed: %errMsg%

        ; Try alternative count query
        MsgBox, 4, Try Alternative, Try COUNT(*) instead?
        IfMsgBox, Yes
        {
            altCountSql := "SELECT COUNT(*) FROM games"
            if !db.GetTable(altCountSql, altResult) {
                altErrMsg := db.ErrorMsg
                GuiControl,, TotalGames, Total games: Both count queries failed
                MsgBox, 16, Alternative Failed, COUNT(*) also failed: %altErrMsg%
                return
            } else {
                countResult := altResult
                MsgBox, 0, Alternative Worked, COUNT(*) query worked!
            }
        } else {
            return
        }
    }

    ; Check the result
    rowCount := countResult.RowCount
    MsgBox, 0, Count Result Debug, Query returned %rowCount% rows

    if (countResult.RowCount = 0) {
        GuiControl,, TotalGames, Total games: No results from count query
        MsgBox, 16, No Results, Count query returned no results
        return
    }

    if countResult.GetRow(1, row) {
        totalCount := row[1]
        MsgBox, 0, Final Count, Total count retrieved: %totalCount%
        GuiControl,, TotalGames, Total games in database: %totalCount%
    } else {
        GuiControl,, TotalGames, Total games: Error getting count value
        MsgBox, 16, Row Error, Could not retrieve count value from result
    }
}
