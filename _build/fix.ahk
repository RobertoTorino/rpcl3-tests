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


Run this debug version and tell me:

What values you see in the first debug message (file size, memory address, etc.)
What the StoreBLOB result shows (result value, error message, error code)
Also, let me try an alternative approach using the prepared statement method instead of StoreBLOB. Looking at your SQLiteDB class, I notice it has a _Statement class that might work better:

SaveIconToDatabaseAlternative(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon to database (alternative method)...

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
        return
    }

    ; Prepare SQL
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = ? WHERE GameId = '" . escapedGameId . "'"

    ; Use prepared statement approach
    stmt := ""
    if (!db.Prepare(updateSql, stmt)) {
        errMsg := db.ErrorMsg
        MsgBox, 16, Prepare Error, Failed to prepare statement:`n%errMsg%
        return
    }

    ; Bind the BLOB data
    if (!stmt.Bind(1, "Blob", &iconData, bytesRead)) {
        errMsg := stmt.ErrorMsg
        MsgBox, 16, Bind Error, Failed to bind BLOB:`n%errMsg%
        stmt.Free()
        return
    }

    ; Execute the statement
    if (stmt.Step()) {
        statusText := "Success: Icon saved to database (" . bytesRead . " bytes) via prepared statement"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (Size: " . bytesRead . " bytes)"
        GuiControl,, IconInDB, %iconText%

        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database

        MsgBox, 64, Success, Icon successfully saved to database via prepared statement!

        stmt.Free()
        Gosub, GameSelected

    } else {
        errMsg := stmt.ErrorMsg
        GuiControl,, StatusText, Error: Failed to execute statement
        MsgBox, 16, Execute Error, Failed to execute statement:`n%errMsg%
        stmt.Free()
    }
}
Try both approaches and let me know what error messages you get.
The prepared statement method might work better since it uses the native SQLite binding functions directly.


---



---------------------------
Debug Info
---------------------------
File Size: 77970 bytes
Memory Address: 50224784
SQL: UPDATE games SET IconBlob = ? WHERE GameId = 'BLUS30001'

BlobArray[1].Addr: 50224784
BlobArray[1].Size: 77970

Proceed with StoreBLOB?
---------------------------
Yes   No
---------------------------
---------------------------
StoreBLOB Result
---------------------------
Result:
ErrorMsg:
ErrorCode:
---------------------------
OK
---------------------------
---------------------------
Database Error
---------------------------
Failed to save icon to database:
ErrorMsg:
ErrorCode:
---------------------------
OK
---------------------------

