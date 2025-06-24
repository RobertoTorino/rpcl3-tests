Let's try creating the BLOB array exactly as expected, but with some debug output:

SaveIconWithCorrectBlobFormat(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Trying correct BLOB format...

    ; Read file data
    file := FileOpen(iconPath, "r")
    if (!file) {
        MsgBox, 16, File Error, Could not open file: %iconPath%
        return
    }

    ; Read small test amount
    testSize := 100
    VarSetCapacity(iconData, testSize)
    bytesRead := file.RawRead(iconData, testSize)
    file.Close()

    ; Create BLOB array exactly as the class expects
    blobArray := {}
    blobArray[1] := {Addr: &iconData, Size: bytesRead}

    ; Debug the blob array structure
    addr := blobArray[1].Addr
    size := blobArray[1].Size

    MsgBox, 0, Debug BLOB Array, Address: %addr%`nSize: %size%`nBytes read: %bytesRead%`n`nAddr exists: %!!addr%`nSize exists: %!!size%

    ; Prepare SQL
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = ? WHERE GameId = '" . escapedGameId . "'"

    MsgBox, 4, Ready to Store, SQL: %updateSql%`n`nCall StoreBLOB?
    IfMsgBox, No
        return

    ; Clear errors
    db.ErrorMsg := ""
    db.ErrorCode := 0

    ; Call StoreBLOB with debug
    MsgBox, 0, Calling StoreBLOB, About to call db.StoreBLOB()...

    result := db.StoreBLOB(updateSql, blobArray)

    ; Get all possible error information
    errMsg := db.ErrorMsg
    errCode := db.ErrorCode
    changes := db.Changes

    MsgBox, 0, StoreBLOB Complete, StoreBLOB returned: %result%`nErrorMsg: '%errMsg%'`nErrorCode: %errCode%`nChanges: %changes%

    ; The StoreBLOB method should return True on success
    ; Let's check what we actually got
    if (result == true || result == 1 || result == "1") {
        MsgBox, 64, BLOB Success, StoreBLOB succeeded! Result was: %result%
        GuiControl,, StatusText, Success: BLOB saved
        Gosub, GameSelected
    } else if (errMsg != "") {
        MsgBox, 16, BLOB Error, StoreBLOB failed with error: %errMsg%
    } else if (changes = 0) {
        MsgBox, 48, No Changes, StoreBLOB executed but made no changes
    } else {
        MsgBox, 16, BLOB Unknown, StoreBLOB result unclear`nResult: %result%`nType: %typeof(result)%
    }
}
And modify one of your buttons to test this:

SaveExistingIcon:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    if (CurrentIconPath = "" || !FileExist(CurrentIconPath)) {
        MsgBox, 48, No File, No existing icon file found for this game.`n`nExpected location: %CurrentIconPath%
        return
    }

    ; Confirm action
    MsgBox, 4, Confirm Save, Try the corrected BLOB format method?`n`nFile: %CurrentIconPath%`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    SaveIconWithCorrectBlobFormat(CurrentIconPath, CurrentGameId, CurrentGameTitle)
return
This will give us detailed debug information about exactly what's happening in the StoreBLOB call. If this still doesn't work, we'll know that your SQLiteDB class has some other specific requirement or bug in its BLOB handling.

The alternative would be to store the icons as Base64 text (which we know works since regular text updates work), but let's try this corrected BLOB format first.

