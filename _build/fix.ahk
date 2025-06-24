The issue is that the GetTable method is failing. Let's simplify this and use a method that we know works (since your main search functionality works). Let me fix this:

SaveIconToDatabaseHex(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon as HEX...

    ; Read file and convert to hex
    FileGetSize, fileSize, %iconPath%
    if (ErrorLevel) {
        MsgBox, 16, File Error, Could not get file size: %iconPath%
        return
    }

    file := FileOpen(iconPath, "r")
    if (!file) {
        MsgBox, 16, File Error, Could not open file: %iconPath%
        return
    }

    ; For testing, read only first 50 bytes
    testSize := (fileSize > 50) ? 50 : fileSize

    ; Read bytes and convert to proper hex
    hexString := ""
    Loop, %testSize% {
        byte := file.ReadUChar()

        hex1 := byte // 16
        hex2 := Mod(byte, 16)

        hexDigits := "0123456789ABCDEF"
        hexChar1 := SubStr(hexDigits, hex1 + 1, 1)
        hexChar2 := SubStr(hexDigits, hex2 + 1, 1)

        hexString .= hexChar1 . hexChar2
    }

    file.Close()

    ; Create SQL - let's try without escaping first
    updateSql := "UPDATE games SET IconBlob = X'" . hexString . "' WHERE GameId = '" . gameId . "'"

    ; Show debug info
    MsgBox, 4, Debug Info, GameId: %gameId%`nGameTitle: %gameTitle%`nHex length: %StrLen(hexString)%`n`nSQL: %updateSql%`n`nProceed?
    IfMsgBox, No
        return

    GuiControl,, StatusText, Executing SQL update...

    ; Execute the update
    result := db.Exec(updateSql)
    changes := db.Changes
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode

    ; Show all results
    MsgBox, 0, Exec Results, Result: %result%`nChanges: %changes%`nErrorMsg: %errMsg%`nErrorCode: %errCode%

    ; Try to determine success differently - check if we have a real result value
    if (result = 1 || result = true || (errMsg = "" && errCode = 0)) {
        if (changes > 0) {
            GuiControl,, StatusText, SUCCESS: %changes% row(s) updated with HEX data
            MsgBox, 64, Success, Icon saved successfully! %changes% row(s) updated.
            Gosub, GameSelected
        } else {
            ; Even if changes=0, if no error occurred, the SQL was valid
            MsgBox, 48, Warning, SQL executed without error but 0 rows updated.`nThis might mean the GameId doesn't match exactly.`n`nTry refreshing the game selection and try again.
        }
    } else {
        MsgBox, 16, Database Error, Update failed:`nResult: %result%`nError: %errMsg%`nCode: %errCode%
    }
}
Let's also try a direct test. Add this button to your GUI to test the exact same SQL that works in your game selection:

; Add this button for testing
Gui, Add, Button, gTestDirectSQL x20 y380 w100 h25, Test SQL

TestDirectSQL:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Use the exact same SQL format as your working GameSelected function
    StringReplace, escapedGameId, CurrentGameId, ', '', All
    testSQL := "SELECT GameId, GameTitle FROM games WHERE GameId = '" . escapedGameId . "'"

    MsgBox, 0, Test SQL, Testing SQL: %testSQL%

    if !db.GetTable(testSQL, result) {
        errMsg := db.ErrorMsg
        MsgBox, 16, SQL Test Failed, SQL test failed: %errMsg%
        return
    }

    if (result.RowCount = 0) {
        MsgBox, 48, No Results, SQL executed but found 0 rows
        return
    }

    ; Show the result
    if result.GetRow(1, row) {
        foundId := row[1]
        foundTitle := row[2]
        MsgBox, 64, SQL Test Success, Found game:`nID: %foundId%`nTitle: %foundTitle%
    }
return
Try both:

First run the Test SQL button to make sure we can query the current game
Then try the modified HEX method
This will help us see if there's a difference between how the working code queries vs our update attempts.

Type a message...
ChatDPG can make mistakes; verify important information.
