 Add this test function to debug the database - AHK v1 compatible
TestDatabaseConnection() {
    ; Test 1: Check if we can do a simple SELECT
    sql1 := "SELECT COUNT(*) FROM games"
    if (db.GetTable(sql1, result1)) {
        if result1.GetRow(1, row) {
            gameCount := row[1]
            MsgBox, 0, Test 1, Games table accessible. Count: %gameCount%
        } else {
            MsgBox, 16, Test 1 Failed, Cannot get row from games table
            return
        }
    } else {
        errMsg := db.ErrorMsg
        MsgBox, 16, Test 1 Failed, Cannot access games table: %errMsg%
        return
    }

    ; Test 2: Check table structure
    sql2 := "PRAGMA table_info(games)"
    if (db.GetTable(sql2, result2)) {
        rowCount := result2.RowCount
        MsgBox, 0, Test 2, Table structure query successful. Columns: %rowCount%
        columnInfo := ""
        Loop, %rowCount% {
            if result2.GetRow(A_Index, row) {
                columnName := row[2]
                columnType := row[3]
                columnInfo .= columnName . " (" . columnType . "), "
            }
        }
        MsgBox, 0, Column Info, %columnInfo%
    } else {
        errMsg := db.ErrorMsg
        MsgBox, 16, Test 2 Failed, Cannot get table info: %errMsg%
        return
    }

    ; Test 3: Check if we can do a simple UPDATE without BLOB
    if (CurrentGameId = "") {
        MsgBox, 48, Test 3 Skipped, No game selected - cannot test UPDATE
    } else {
        StringReplace, escapedGameId, CurrentGameId, ', '', All
        sql3 := "UPDATE games SET Icon0 = 'test_update' WHERE GameId = '" . escapedGameId . "'"
        if (db.Exec(sql3)) {
            changes := db.Changes
            MsgBox, 0, Test 3, Simple UPDATE works. Changes: %changes%
        } else {
            errMsg := db.ErrorMsg
            MsgBox, 16, Test 3 Failed, Simple UPDATE failed: %errMsg%
            return
        }
    }

    ; Test 4: Try to prepare a simple statement
    sql4 := "SELECT GameId FROM games WHERE GameId = ?"
    stmt := ""
    if (db.Prepare(sql4, stmt)) {
        MsgBox, 0, Test 4, Simple prepare statement works
        stmt.Free()
    } else {
        errMsg := db.ErrorMsg
        MsgBox, 16, Test 4 Failed, Simple prepare failed: %errMsg%
        return
    }

    MsgBox, 0, All Tests, All basic database tests passed
}
Also, here's the corrected HEX method for AHK v1:

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
    iconLength := StrLen(iconBinary)
    Loop, %iconLength% {
        charCode := Asc(SubStr(iconBinary, A_Index, 1))
        ; Convert to hex - AHK v1 doesn't have Format function
        hexByte := ""
        if (charCode < 16)
            hexByte := "0"
        hexByte .= DEC2Hex(charCode)
        hexString .= hexByte
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

; Helper function to convert decimal to hex (AHK v1)
DEC2Hex(dec) {
    Static hexDigits := "0123456789ABCDEF"
    if (dec = 0)
        return "0"

    result := ""
    while (dec > 0) {
        remainder := Mod(dec, 16)
        result := SubStr(hexDigits, remainder + 1, 1) . result
        dec := dec // 16
    }
    return result
}
And add the test button to your GUI:

; Add this button in your GUI section (in the Icon Actions section)
Gui, Add, Button, gTestDB x270 y380 w100 h25, Test DB

; Add this label
TestDB:
    TestDatabaseConnection()
return
