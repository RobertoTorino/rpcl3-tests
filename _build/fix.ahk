SaveIconToDatabaseHex(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Testing UPDATE mechanism...

    ; First, let's test if UPDATE works at all with simple text
    StringReplace, escapedGameId, gameId, ', '', All
    testUpdateSql := "UPDATE games SET Icon0 = 'TEST_UPDATE_" . A_TickCount . "' WHERE GameId = '" . escapedGameId . "'"

    MsgBox, 4, Test UPDATE, First test simple UPDATE:`n%testUpdateSql%`n`nProceed?
    IfMsgBox, No
        return

    result1 := db.Exec(testUpdateSql)
    changes1 := db.Changes
    errMsg1 := db.ErrorMsg

    MsgBox, 0, Simple UPDATE Result, Result: %result1%`nChanges: %changes1%`nError: %errMsg1%

    if (changes1 = 0) {
        MsgBox, 16, UPDATE Failed, Even simple UPDATE failed - there might be a fundamental issue
        return
    }

    ; Now let's try updating IconBlob with NULL first
    nullUpdateSql := "UPDATE games SET IconBlob = NULL WHERE GameId = '" . escapedGameId . "'"

    MsgBox, 4, Test NULL UPDATE, Now test NULL UPDATE to IconBlob:`n%nullUpdateSql%`n`nProceed?
    IfMsgBox, No
        return

    result2 := db.Exec(nullUpdateSql)
    changes2 := db.Changes
    errMsg2 := db.ErrorMsg

    MsgBox, 0, NULL UPDATE Result, Result: %result2%`nChanges: %changes2%`nError: %errMsg2%

    if (changes2 = 0) {
        MsgBox, 16, BLOB UPDATE Failed, Cannot update IconBlob column - might be a column issue
        return
    }

    ; Now try with very simple hex data
    simpleHexSql := "UPDATE games SET IconBlob = X'48656C6C6F' WHERE GameId = '" . escapedGameId . "'"

    MsgBox, 4, Test Simple HEX, Now test simple HEX (Hello):`n%simpleHexSql%`n`nProceed?
    IfMsgBox, No
        return

    result3 := db.Exec(simpleHexSql)
    changes3 := db.Changes
    errMsg3 := db.ErrorMsg

    MsgBox, 0, Simple HEX Result, Result: %result3%`nChanges: %changes3%`nError: %errMsg3%

    if (changes3 > 0) {
        MsgBox, 64, HEX Works!, Simple HEX update worked! Now we can try with real icon data.
        Gosub, GameSelected  ; Refresh to see the change
    } else {
        MsgBox, 16, HEX Failed, Even simple HEX failed - HEX syntax might not be supported by your SQLite version

        ; Let's try alternative approach - insert as text
        MsgBox, 4, Try Base64, HEX failed. Try Base64 text instead?
        IfMsgBox, Yes
        {
            ; Read a small amount of file and convert to base64-like format
            FileRead, iconBinary, *c %iconPath%
            if (ErrorLevel) {
                MsgBox, 16, File Error, Could not read file
                return
            }

            ; Just take first 20 characters as test
            testData := SubStr(iconBinary, 1, 20)

            ; Simple encoding to avoid special characters - convert to numbers
            encodedData := ""
            testLen := StrLen(testData)
            Loop, %testLen% {
                charCode := Asc(SubStr(testData, A_Index, 1))
                encodedData .= charCode . ","
            }

            textUpdateSql := "UPDATE games SET IconBlob = '" . encodedData . "' WHERE GameId = '" . escapedGameId . "'"

            if (db.Exec(textUpdateSql)) {
                changes4 := db.Changes
                MsgBox, 64, Text Method Works, Saved as text! Changes: %changes4%
                Gosub, GameSelected
            } else {
                errMsg4 := db.ErrorMsg
                MsgBox, 16, All Methods Failed, Even text method failed: %errMsg4%
            }
        }
    }
}
