#SingleInstance Force
#NoEnv
#Include SQLiteDB.ahk

; Simple test to update game title
db := new SQLiteDB()

; Try to open the database
if !db.OpenDB("games.db") {
    err := db.ErrorMsg
    MsgBox, 16, DB Error, Failed to open games.db`n%err%
    ExitApp
}

MsgBox, 64, DB Opened, Database opened successfully!

; First, let's see what games we have
MsgBox, 4, List Games, Show first 5 games in database?
IfMsgBox, Yes
{
    sql := "SELECT GameId, GameTitle FROM games LIMIT 5"
    if db.GetTable(sql, result) {
        gameList := "Games found:`n`n"
        Loop, % result.RowCount {
            if result.GetRow(A_Index, row) {
                gameId := row[1]
                gameTitle := row[2]
                gameList .= gameId . " - " . gameTitle . "`n"
            }
        }
        MsgBox, 0, Games List, %gameList%
    } else {
        errMsg := db.ErrorMsg
        MsgBox, 16, Query Failed, Failed to get games: %errMsg%
        ExitApp
    }
}

; Now let's try to update a specific game
InputBox, targetGameId, Game ID, Enter the GameId you want to test (e.g. BLUS30001):, , 300, 120

if (ErrorLevel || targetGameId = "") {
    MsgBox, 48, Cancelled, Test cancelled
    db.CloseDB()
    ExitApp
}

; First verify the game exists
checkSql := "SELECT GameTitle FROM games WHERE GameId = '" . targetGameId . "'"
if db.GetTable(checkSql, checkResult) {
    if (checkResult.RowCount = 0) {
        MsgBox, 16, Game Not Found, GameId '%targetGameId%' not found in database
        db.CloseDB()
        ExitApp
    } else {
        if checkResult.GetRow(1, checkRow) {
            currentTitle := checkRow[1]
            MsgBox, 0, Game Found, Current title: %currentTitle%
        }
    }
} else {
    errMsg := db.ErrorMsg
    MsgBox, 16, Check Failed, Could not check if game exists: %errMsg%
    db.CloseDB()
    ExitApp
}

; Now try the update
newTitle := "TEST UPDATED TITLE " . A_Now
updateSql := "UPDATE games SET GameTitle = '" . newTitle . "' WHERE GameId = '" . targetGameId . "'"

MsgBox, 4, Confirm Update, SQL: %updateSql%`n`nExecute this update?
IfMsgBox, No
{
    db.CloseDB()
    ExitApp
}

; Execute the update
MsgBox, 0, Executing, Executing update...

result := db.Exec(updateSql)
changes := db.Changes
errMsg := db.ErrorMsg
errCode := db.ErrorCode

; Show results
MsgBox, 0, Update Results, Result: %result%`nChanges: %changes%`nErrorMsg: %errMsg%`nErrorCode: %errCode%

if (changes > 0) {
    MsgBox, 64, Success!, Update successful! %changes% row(s) changed.

    ; Verify the change
    if db.GetTable(checkSql, verifyResult) {
        if verifyResult.GetRow(1, verifyRow) {
            updatedTitle := verifyRow[1]
            MsgBox, 0, Verification, New title: %updatedTitle%
        }
    }
} else {
    MsgBox, 16, Update Failed, Update failed or no rows affected
}

; Cleanup
db.CloseDB()
MsgBox, 0, Test Complete, Test complete. Database closed.
ExitApp
