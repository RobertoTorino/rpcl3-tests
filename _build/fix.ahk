Looking at your AutoHotkey script, the issue with "Failed to save icon to database" in the SaveIconToDatabase() function appears to be related to how you're handling the BLOB data for SQLite.

Here are the most likely issues and solutions:

1. BLOB Array Structure Issue
The way you're creating the BLOB array might not be compatible with your SQLiteDB wrapper:

; Instead of this:
blobArray := []
blobArray[1] := {Addr: &iconData, Size: bytesRead}

; Try this approach:
blobArray := [{Addr: &iconData, Size: bytesRead}]
2. Memory Address Issue
The address of iconData might not be handled correctly. Try this alternative:

SaveIconToDatabase(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon to database...

    ; Check file size
    FileGetSize, fileSize, %iconPath%
    if (fileSize > 500000) {
        MsgBox, 4, Large File, Warning: This file is quite large (%fileSize% bytes).`nContinue anyway?
        IfMsgBox, No
            return
    }

    ; Read file as binary
    file := FileOpen(iconPath, "r")
    if (!file) {
        GuiControl,, StatusText, Error: Could not open file
        MsgBox, 16, File Error, Could not open icon file: %iconPath%
        return
    }

    fileLength := file.Length
    file.Pos := 0
    iconData := file.Read(fileLength)  ; Read as string/binary
    file.Close()

    if (!iconData) {
        GuiControl,, StatusText, Error: Could not read file data
        return
    }

    ; Prepare SQL with parameter
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = ? WHERE GameId = '" . escapedGameId . "'"

    ; Try different BLOB format
    blobData := [{Data: iconData, Size: fileLength}]

    if (db.StoreBLOB(updateSql, blobData)) {
        ; Success handling...
        statusText := "Success: Icon saved to database (" . fileLength . " bytes)"
        GuiControl,, StatusText, %statusText%
        GuiControl,, IconInDB, Yes (Size: %fileLength% bytes)
        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database
        MsgBox, 64, Success, Icon successfully saved to database!
    } else {
        errMsg := db.ErrorMsg
        GuiControl,, StatusText, Error: Failed to save icon to database
        MsgBox, 16, Database Error, Failed to save icon to database:`n%errMsg%
    }
}
3. Check Your SQLiteDB Wrapper Documentation
The exact format for BLOB parameters depends on your SQLiteDB.ahk wrapper. You might need to:

Check if StoreBLOB() expects a different parameter format
Try using Exec() instead with proper BLOB binding
Verify the SQLiteDB wrapper supports BLOB operations correctly
4. Alternative Approach Using Base64
If BLOB handling continues to fail, consider storing icons as Base64:

; Convert to Base64 and store as TEXT
FileRead, iconData, *c %iconPath%  ; Read as binary
base64Data := Base64Encode(iconData)  ; You'd need a Base64 function
updateSql := "UPDATE games SET IconBlob = '" . base64Data . "' WHERE GameId = '" . escapedGameId . "'"
5. Debug the SQLiteDB Wrapper
Add some debugging to see what's happening:

; Before the StoreBLOB call:
MsgBox, Debug, Data size: %fileLength%`nSQL: %updateSql%

; After the call:
if (!result) {
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode  ; If available
    MsgBox, Debug Error, Code: %errCode%`nMsg: %errMsg%
}
The most common issue is that the BLOB array format doesn't match what your SQLiteDB wrapper expects. Check the documentation for your specific SQLiteDB.ahk wrapper to see the correct format for BLOB parameters.

