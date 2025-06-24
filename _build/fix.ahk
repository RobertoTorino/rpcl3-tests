; Add this test function to debug the database
TestDatabaseConnection() {
    ; Test 1: Check if we can do a simple SELECT
    sql1 := "SELECT COUNT(*) FROM games"
    if (db.GetTable(sql1, result1)) {
        result1.GetRow(1, row)
        gameCount := row[1]
        MsgBox, 0, Test 1, Games table accessible. Count: %gameCount%
    } else {
        MsgBox, 16, Test 1 Failed, Cannot access games table: %db.ErrorMsg%
        return
    }

    ; Test 2: Check table structure
    sql2 := "PRAGMA table_info(games)"
    if (db.GetTable(sql2, result2)) {
        MsgBox, 0, Test 2, Table structure query successful. Columns: %result2.RowCount%
        columnInfo := ""
        Loop, % result2.RowCount {
            result2.GetRow(A_Index, row)
            columnInfo .= row[2] . " (" . row[3] . "), "  ; name (type)
        }
        MsgBox, 0, Column Info, %columnInfo%
    } else {
        MsgBox, 16, Test 2 Failed, Cannot get table info: %db.ErrorMsg%
        return
    }

    ; Test 3: Check if we can do a simple UPDATE without BLOB
    StringReplace, escapedGameId, CurrentGameId, ', '', All
    sql3 := "UPDATE games SET Icon0 = 'test_update' WHERE GameId = '" . escapedGameId . "'"
    if (db.Exec(sql3)) {
        MsgBox, 0, Test 3, Simple UPDATE works. Changes: %db.Changes%
    } else {
        MsgBox, 16, Test 3 Failed, Simple UPDATE failed: %db.ErrorMsg%
        return
    }

    ; Test 4: Try to prepare a simple statement
    sql4 := "SELECT GameId FROM games WHERE GameId = ?"
    stmt := ""
    if (db.Prepare(sql4, stmt)) {
        MsgBox, 0, Test 4, Simple prepare statement works
        stmt.Free()
    } else {
        MsgBox, 16, Test 4 Failed, Simple prepare failed: %db.ErrorMsg%
        return
    }

    MsgBox, 0, All Tests, All basic database tests passed
}
Add a button to test this:

; Add this button in your GUI section
Gui, Add, Button, gTestDB x270 y380 w100 h25, Test DB

; Add this label
TestDB:
    TestDatabaseConnection()
return
Also, let's try a completely different approach using direct SQL execution with hex encoding:

SaveIconToDatabaseHex(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon as HEX...

    ; Read file as binary
    FileRead, iconBinary, *c %iconPath%
    if (ErrorLevel) {
        MsgBox, 16, File Error, Could not read file: %iconPath%
        return
    }

    ; Convert binary data to hex string
    hexString := ""
    Loop, % StrLen(iconBinary) {
        byte := Asc(SubStr(iconBinary, A_Index, 1))
        hexString .= Format("{:02X}", byte)
    }

    ; Create SQL with hex literal
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = X'" . hexString . "' WHERE GameId = '" . escapedGameId . "'"

    if (db.Exec(updateSql)) {
        bytesOriginal := StrLen(iconBinary)
        statusText := "Success: Icon saved as HEX (" . bytesOriginal . " bytes)"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (HEX: " . bytesOriginal . " bytes)"
        GuiControl,, IconInDB, %iconText%

        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved as HEX

        MsgBox, 64, Success, Icon saved as HEX literal!
        Gosub, GameSelected

    } else {
        errMsg := db.ErrorMsg
        GuiControl,, StatusText, Error: HEX method failed
        MsgBox, 16, Database Error, HEX method failed:`n%errMsg%
    }
}
Try these steps:

First run the database test to make sure everything basic is working
If the tests pass, try the HEX method which uses SQLite's X'hexdata' syntax to insert binary data
The HEX method is often more reliable because it doesn't rely on memory pointers or BLOB binding - it just creates a SQL string with the binary data encoded as hexadecimal.

Let me know what the database tests show and if the HEX method works!
