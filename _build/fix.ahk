SaveIconToDatabaseHex(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon as HEX...

    ; Read file as binary
    FileRead, iconBinary, *c %iconPath%
    if (ErrorLevel) {
        MsgBox, 16, File Error, Could not read file: %iconPath%
        return
    }

    ; Convert binary data to hex string manually
    hexString := ""
    iconLength := StrLen(iconBinary)

    ; Show progress for large files
    if (iconLength > 50000) {
        GuiControl,, StatusText, Converting to HEX... this may take a moment for large files
    }

    Loop, %iconLength% {
        charCode := Asc(SubStr(iconBinary, A_Index, 1))

        ; Manual hex conversion for AHK v1
        hex1 := charCode // 16
        hex2 := Mod(charCode, 16)

        ; Convert to hex characters
        if (hex1 < 10)
            hexChar1 := Chr(48 + hex1)  ; 0-9
        else
            hexChar1 := Chr(55 + hex1)  ; A-F

        if (hex2 < 10)
            hexChar2 := Chr(48 + hex2)  ; 0-9
        else
            hexChar2 := Chr(55 + hex2)  ; A-F

        hexString .= hexChar1 . hexChar2
    }

    ; Create SQL with hex literal
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = X'" . hexString . "' WHERE GameId = '" . escapedGameId . "'"

    GuiControl,, StatusText, Executing SQL update...

    if (db.Exec(updateSql)) {
        bytesOriginal := StrLen(iconBinary)
        statusText := "Success: Icon saved as HEX (" . bytesOriginal . " bytes)"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (Size: " . bytesOriginal . " bytes)"
        GuiControl,, IconInDB, %iconText%

        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database (HEX)

        MsgBox, 64, Success, Icon saved to database using HEX method!
        Gosub, GameSelected

    } else {
        errMsg := db.ErrorMsg
        GuiControl,, StatusText, Error: HEX method failed
        MsgBox, 16, Database Error, HEX method failed:`n%errMsg%
    }
}
Now, to test this, modify one of your existing buttons to use this method. Change the SaveIconToDatabase calls to SaveIconToDatabaseHex:

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
    MsgBox, 4, Confirm Save, Save the existing icon file to database using HEX method?`n`nFile: %CurrentIconPath%`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    ; Use HEX method instead
    SaveIconToDatabaseHex(CurrentIconPath, CurrentGameId, CurrentGameTitle)
return

BrowseAndSaveIcon:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Browse for icon file
    FileSelectFile, selectedIcon, 1, , Select icon file, Image Files (*.png; *.jpg; *.jpeg; *.bmp; *.gif)

    if (selectedIcon = "") {
        return
    }

    ; Confirm action
    MsgBox, 4, Confirm Save, Save this icon to database using HEX method?`n`nFile: %selectedIcon%`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    ; Use HEX method instead
    SaveIconToDatabaseHex(selectedIcon, CurrentGameId, CurrentGameTitle)
return
