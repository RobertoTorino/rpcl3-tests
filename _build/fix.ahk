SaveIconToDatabaseHex(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon as HEX...

    ; Read file as binary
    FileRead, iconBinary, *c %iconPath%
    if (ErrorLevel) {
        MsgBox, 16, File Error, Could not read file: %iconPath%
        return
    }

    ; For debugging, let's try with a very small portion first
    ; Take only first 100 bytes for testing
    testLength := StrLen(iconBinary)
    if (testLength > 100) {
        testBinary := SubStr(iconBinary, 1, 100)
        testLength := 100
    } else {
        testBinary := iconBinary
    }

    ; Convert to hex
    hexString := ""

    Loop, %testLength% {
        charCode := Asc(SubStr(testBinary, A_Index, 1))

        ; Manual hex conversion
        hex1 := charCode // 16
        hex2 := Mod(charCode, 16)

        if (hex1 < 10)
            hexChar1 := Chr(48 + hex1)
        else
            hexChar1 := Chr(55 + hex1)

        if (hex2 < 10)
            hexChar2 := Chr(48 + hex2)
        else
            hexChar2 := Chr(55 + hex2)

        hexString .= hexChar1 . hexChar2
    }

    ; Debug the SQL before executing
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = X'" . hexString . "' WHERE GameId = '" . escapedGameId . "'"

    ; Show the SQL for debugging (truncated)
    sqlPreview := SubStr(updateSql, 1, 200) . "..."
    hexLen := StrLen(hexString)
    MsgBox, 4, Debug SQL, SQL Preview: %sqlPreview%`n`nHex length: %hexLen%`nTest data length: %testLength%`n`nProceed?
    IfMsgBox, No
        return

    GuiControl,, StatusText, Executing SQL update...

    ; Clear previous errors
    db.ErrorMsg := ""
    db.ErrorCode := 0

    result := db.Exec(updateSql)

    ; Get detailed error info
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode
    changes := db.Changes

    MsgBox, 0, Exec Result, Result: %result%`nErrorMsg: %errMsg%`nErrorCode: %errCode%`nChanges: %changes%

    if (result) {
        GuiControl,, StatusText, Success: Icon saved as HEX (test with %testLength% bytes)
        MsgBox, 64, Success, Icon saved using HEX method (test data)!
        Gosub, GameSelected

    } else {
        GuiControl,, StatusText, Error: HEX method failed
        if (errMsg != "") {
            MsgBox, 16, Database Error, HEX method failed:`nError: %errMsg%`nCode: %errCode%
        } else {
            MsgBox, 16, Database Error, HEX method failed with no specific error message
        }
    }
}
And the simple test function:

; Add this button to your GUI for testing
Gui, Add, Button, gSimpleTest x370 y380 w100 h25, Simple Test

SimpleTest:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Test 1: Check if the column exists and what type it is
    sql1 := "SELECT sql FROM sqlite_master WHERE type='table' AND name='games'"
    if db.GetTable(sql1, result1) {
        if result1.GetRow(1, row) {
            createSql := row[1]
            MsgBox, 0, Table Definition, %createSql%
        }
    }

    ; Test 2: Try inserting a simple hex value
    StringReplace, escapedGameId, CurrentGameId, ', '', All
    testSql := "UPDATE games SET IconBlob = X'48656C6C6F' WHERE GameId = '" . escapedGameId . "'"

    MsgBox, 4, Test Simple HEX, Try simple HEX update?`nSQL: %testSql%`n(This will set IconBlob to "Hello" in hex)
    IfMsgBox, Yes
    {
        if db.Exec(testSql) {
            changes := db.Changes
            MsgBox, 64, Test Success, Simple HEX insert worked! Changes: %changes%
            Gosub, GameSelected
        } else {
            errMsg := db.ErrorMsg
            MsgBox, 16, Test Failed, Simple HEX failed: %errMsg%
        }
    }
return
The key AHK v1 syntax fixes:

Removed parentheses around conditions in if statements
Used proper IfMsgBox syntax
Fixed variable references in MsgBox
