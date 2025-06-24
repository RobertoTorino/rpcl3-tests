SaveIconToDatabaseHex(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon as HEX...

    ; Read file size first
    FileGetSize, fileSize, %iconPath%
    if (ErrorLevel) {
        MsgBox, 16, File Error, Could not get file size: %iconPath%
        return
    }

    ; Open file in binary mode
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
        ; Read one byte at a time
        byte := file.ReadUChar()  ; Read unsigned char (0-255)

        ; Convert byte to 2-digit hex
        hex1 := byte // 16
        hex2 := Mod(byte, 16)

        ; Convert to hex characters (0-9, A-F)
        hexDigits := "0123456789ABCDEF"
        hexChar1 := SubStr(hexDigits, hex1 + 1, 1)
        hexChar2 := SubStr(hexDigits, hex2 + 1, 1)

        hexString .= hexChar1 . hexChar2
    }

    file.Close()

    ; Debug the hex string
    hexLen := StrLen(hexString)
    hexPreview := SubStr(hexString, 1, 50) . "..."
    MsgBox, 4, Debug HEX, Hex Preview: %hexPreview%`n`nHex length: %hexLen%`nTest size: %testSize% bytes`n`nProceed?
    IfMsgBox, No
        return

    ; Create SQL
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = X'" . hexString . "' WHERE GameId = '" . escapedGameId . "'"

    GuiControl,, StatusText, Executing SQL update...

    ; Clear previous errors and execute
    db.ErrorMsg := ""
    db.ErrorCode := 0

    result := db.Exec(updateSql)

    ; Get results
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode
    changes := db.Changes

    MsgBox, 0, Exec Result, Result: %result%`nErrorMsg: %errMsg%`nErrorCode: %errCode%`nChanges: %changes%

    ; Check for success - if no error and changes > 0
    if (errMsg = "" && errCode = 0 && changes > 0) {
        GuiControl,, StatusText, Success: Icon saved as HEX (%testSize% bytes)
        MsgBox, 64, Success, Icon saved using HEX method!
        Gosub, GameSelected
    } else if (changes = 0) {
        MsgBox, 48, No Changes, SQL executed but no rows were updated. Check if GameId exists.
    } else {
        GuiControl,, StatusText, Error: HEX method failed
        if (errMsg != "") {
            MsgBox, 16, Database Error, HEX method failed:`nError: %errMsg%`nCode: %errCode%
        } else {
            MsgBox, 16, Database Error, HEX method failed - no error details but result was: %result%
        }
    }
}
