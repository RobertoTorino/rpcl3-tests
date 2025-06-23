SaveIconToDatabase(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon to database...

    ; Check file size
    FileGetSize, fileSize, %iconPath%
    if (fileSize > 500000) {  ; 500KB
        MsgBox, 4, Large File, Warning: This file is quite large (%fileSize% bytes).`nContinue anyway?
        IfMsgBox, No
            return
    }

    ; Read file data
    file := FileOpen(iconPath, "r")
    if (!file) {
        GuiControl,, StatusText, Error: Could not open file
        MsgBox, 16, File Error, Could not open icon file: %iconPath%
        return
    }

    fileLength := file.Length
    VarSetCapacity(iconData, fileLength)
    bytesRead := file.RawRead(iconData, fileLength)
    file.Close()

    if (bytesRead != fileLength) {
        GuiControl,, StatusText, Error: Could not read file completely
        MsgBox, 16, Read Error, Could not read icon file completely`nExpected: %fileLength% bytes`nRead: %bytesRead% bytes
        return
    }

    ; Prepare SQL
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = ? WHERE GameId = '" . escapedGameId . "'"

    ; Create BLOB array - debug the values
    blobArray := []
    blobArray[1] := {Addr: &iconData, Size: bytesRead}

    ; Debug information
    addr := &iconData
    MsgBox, 4, Debug Info, File Size: %bytesRead% bytes`nMemory Address: %addr%`nSQL: %updateSql%`n`nBlobArray[1].Addr: %addr%`nBlobArray[1].Size: %bytesRead%`n`nProceed with StoreBLOB?
    IfMsgBox, No
        return

    ; Clear any previous errors
    db.ErrorMsg := ""
    db.ErrorCode := 0

    result := db.StoreBLOB(updateSql, blobArray)

    ; Debug the result
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode

    MsgBox, 0, StoreBLOB Result, Result: %result%`nErrorMsg: %errMsg%`nErrorCode: %errCode%

    if (result) {
        statusText := "Success: Icon saved to database (" . bytesRead . " bytes)"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (Size: " . bytesRead . " bytes)"
        GuiControl,, IconInDB, %iconText%

        ; Update preview
        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database

        MsgBox, 64, Success, Icon successfully saved to database!

        ; Refresh display
        Gosub, GameSelected

    } else {
        GuiControl,, StatusText, Error: Failed to save icon to database
        MsgBox, 16, Database Error, Failed to save icon to database:`nErrorMsg: %errMsg%`nErrorCode: %errCode%
    }
}


ChatDPG
I see the issue! The StoreBLOB method is returning an empty result (not True or 1), which means it's not explicitly returning True on success. Looking at your SQLiteDB class, the StoreBLOB method returns True on success, but it seems like it might be returning an empty value instead.

Let me fix this by checking the result more carefully:

SaveIconToDatabase(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon to database...

    ; Check file size
    FileGetSize, fileSize, %iconPath%
    if (fileSize > 500000) {  ; 500KB
        MsgBox, 4, Large File, Warning: This file is quite large (%fileSize% bytes).`nContinue anyway?
        IfMsgBox, No
            return
    }

    ; Read file data
    file := FileOpen(iconPath, "r")
    if (!file) {
        GuiControl,, StatusText, Error: Could not open file
        MsgBox, 16, File Error, Could not open icon file: %iconPath%
        return
    }

    fileLength := file.Length
    VarSetCapacity(iconData, fileLength)
    bytesRead := file.RawRead(iconData, fileLength)
    file.Close()

    if (bytesRead != fileLength) {
        GuiControl,, StatusText, Error: Could not read file completely
        MsgBox, 16, Read Error, Could not read icon file completely`nExpected: %fileLength% bytes`nRead: %bytesRead% bytes
        return
    }

    ; Prepare SQL
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = ? WHERE GameId = '" . escapedGameId . "'"

    ; Create BLOB array
    blobArray := []
    blobArray[1] := {Addr: &iconData, Size: bytesRead}

    ; Clear any previous errors
    db.ErrorMsg := ""
    db.ErrorCode := 0

    result := db.StoreBLOB(updateSql, blobArray)

    ; Check if there were any errors (even if result is empty)
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode

    ; If no error message and no error code, consider it successful
    if (errMsg = "" && errCode = 0) {
        statusText := "Success: Icon saved to database (" . bytesRead . " bytes)"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (Size: " . bytesRead . " bytes)"
        GuiControl,, IconInDB, %iconText%

        ; Update preview
        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database

        MsgBox, 64, Success, Icon successfully saved to database!

        ; Refresh display
        Gosub, GameSelected

    } else {
        ; There was an error
        GuiControl,, StatusText, Error: Failed to save icon to database
        if (errMsg != "") {
            MsgBox, 16, Database Error, Failed to save icon to database:`n%errMsg%
        } else if (errCode != 0) {
            MsgBox, 16, Database Error, Failed to save icon to database:`nError Code: %errCode%
        } else {
            MsgBox, 16, Database Error, Failed to save icon to database:`nUnknown error (no error message or code)
        }
    }
}


Since your debug shows that ErrorMsg and ErrorCode are both empty, which typically means success, let's check if the data was actually saved. The issue might be that the StoreBLOB method completed successfully but didn't return True explicitly.

Try this version and see if it reports success. If it does report success, we should check if the data was actually written to the database by refreshing the game selection to see if the icon appears.

If that doesn't work, let's also try the prepared statement approach as it might be more reliable:

; Add this as an alternative function to test
SaveIconToDatabasePrepared(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon to database (prepared statement)...

    ; Read file data
    file := FileOpen(iconPath, "r")
    if (!file) {
        GuiControl,, StatusText, Error: Could not open file
        MsgBox, 16, File Error, Could not open icon file: %iconPath%
        return
    }

    fileLength := file.Length
    VarSetCapacity(iconData, fileLength)
    bytesRead := file.RawRead(iconData, fileLength)
    file.Close()

    ; Prepare SQL
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = ? WHERE GameId = '" . escapedGameId . "'"

    ; Use prepared statement
    stmt := ""
    if (!db.Prepare(updateSql, stmt)) {
        errMsg := db.ErrorMsg
        MsgBox, 16, Prepare Error, Failed to prepare statement:`n%errMsg%
        return
    }

    ; Bind BLOB parameter (parameter 1, type "Blob", data address, data size)
    if (!stmt.Bind(1, "Blob", &iconData, bytesRead)) {
        errMsg := stmt.ErrorMsg
        MsgBox, 16, Bind Error, Failed to bind BLOB:`n%errMsg%
        stmt.Free()
        return
    }

    ; Execute
    if (stmt.Step()) {
        statusText := "Success: Icon saved via prepared statement (" . bytesRead . " bytes)"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (Size: " . bytesRead . " bytes)"
        GuiControl,, IconInDB, %iconText%

        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database

        MsgBox, 64, Success, Icon saved via prepared statement!

        stmt.Free()
        Gosub, GameSelected

    } else {
        errMsg := stmt.ErrorMsg
        MsgBox, 16, Execute Error, Failed to execute:`n%errMsg%
        stmt.Free()
    }
}
