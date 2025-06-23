#SingleInstance Force
#NoEnv
#Include %A_ScriptDir%\tools\SQLiteDB.ahk

; Icon Manager Script
db := new SQLiteDB()
if !db.OpenDB(A_ScriptDir . "\games.db") {
    err := db.ErrorMsg
    MsgBox, 16, DB Error, Failed to open DB.`n%err%
    ExitApp
}

; Create Icon Manager GUI
Gui, Font, s10, Segoe UI

; Search/Select Game section
Gui, Add, GroupBox, x10 y10 w480 h100, Select Game
Gui, Add, Text, x20 y30, Search game:
Gui, Add, Edit, vSearchTerm x20 y50 w200 h20
Gui, Add, Button, gSearchGames x230 y50 w60 h20, Search
Gui, Add, ComboBox, vGameSelect x20 y75 w400 h200 gGameSelected, Select a game...

; Current Game Info section
Gui, Add, GroupBox, x10 y120 w480 h120, Current Game Info
Gui, Add, Text, x20 y140, Selected Game:
Gui, Add, Text, vSelectedGame x20 y155 w450 h20, None selected
Gui, Add, Text, x20 y175, Current Icon Path:
Gui, Add, Text, vCurrentIconPath x20 y190 w450 h20, -
Gui, Add, Text, x20 y205, Icon in Database:
Gui, Add, Text, vIconInDB x20 y220 w100 h20, Checking...

; Icon Preview section
Gui, Add, GroupBox, x10 y250 w240 h150, Current Icon Preview
Gui, Add, Picture, vCurrentIcon x20 y270 w320 h176,
Gui, Add, Text, vIconStatus x20 y340 w200 h20, No icon loaded

; Icon Actions section
Gui, Add, GroupBox, x260 y250 w230 h150, Icon Actions
Gui, Add, Button, gSaveExistingIcon x270 y270 w200 h30, Save Existing Icon to DB
Gui, Add, Button, gBrowseAndSaveIcon x270 y310 w200 h30, Browse & Save New Icon
Gui, Add, Button, gDeleteIcon x270 y350 w200 h30, Delete Icon from DB

; Progress section
Gui, Add, GroupBox, x10 y410 w480 h80, Status
Gui, Add, Text, vStatusText x20 y430 w450 h40, Ready. Select a game to manage its icon.

Gui, Show, w500 h500, Icon Manager
return

SearchGames:
    Gui, Submit, NoHide

    if (SearchTerm = "") {
        MsgBox, 48, Input Required, Please enter a search term.
        return
    }

    ; Search for games - fixed StrReplace for AHK v1
    StringReplace, searchTerm, SearchTerm, ', '', All
    sql := "SELECT GameId, GameTitle FROM games WHERE GameTitle LIKE '%" . searchTerm . "%' OR GameId LIKE '%" . searchTerm . "%' ORDER BY GameTitle LIMIT 20"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, Search failed
        return
    }

    ; Clear and populate combo box
    GuiControl,, GameSelect, |Select a game...

    if (result.RowCount = 0) {
        GuiControl,, StatusText, No games found matching "%SearchTerm%"
        return
    }

    ; Add games to combo box
    Loop, % result.RowCount {
        row := ""
        if result.GetRow(A_Index, row) {
            gameEntry := row[1] . " - " . row[2]
            GuiControl,, GameSelect, %gameEntry%
        }
    }

    statusText := "Found " . result.RowCount . " games. Select one from the dropdown."
    GuiControl,, StatusText, %statusText%
return

GameSelected:
    Gui, Submit, NoHide

    if (GameSelect = "Select a game..." || GameSelect = "") {
        return
    }

    ; Extract Game ID from selection (format: "GAMEID - Title")
    StringSplit, parts, GameSelect, %A_Space%-%A_Space%
    selectedGameId := parts1

    ; Get detailed game info - fixed StrReplace for AHK v1
    StringReplace, escapedGameId, selectedGameId, ', '', All
    sql := "SELECT GameId, GameTitle, Icon0, IconBlob FROM games WHERE GameId = '" . escapedGameId . "'"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, Failed to get game details
        return
    }

    if (result.RowCount = 0) {
        MsgBox, 16, Error, Game not found
        return
    }

    result.GetRow(1, row)
    CurrentGameId := row[1]
    CurrentGameTitle := row[2]
    CurrentIcon0Path := row[3]  ; This is the relative path from database
    CurrentIconBlob := row[4]

    ; Build the full path to the icon file
    if (CurrentIcon0Path != "") {
        ; Remove any leading slash or backslash and build full path
        CurrentIcon0Path := LTrim(CurrentIcon0Path, "\/")
        CurrentIconPath := A_ScriptDir . "\" . CurrentIcon0Path
    } else {
        CurrentIconPath := ""
    }

    ; Update GUI
    GuiControl,, SelectedGame, %CurrentGameId% - %CurrentGameTitle%
    GuiControl,, CurrentIconPath, %CurrentIconPath%

    ; Check if icon exists in database
    if (CurrentIconBlob != "" && IsObject(CurrentIconBlob)) {
        iconText := "Yes (Size: " . CurrentIconBlob.Size . " bytes)"
        GuiControl,, IconInDB, %iconText%

        ; Show icon from database
        tempFile := A_Temp . "\preview_icon_" . A_TickCount . ".png"
        file := FileOpen(tempFile, "w")
        if (file) {
            file.RawWrite(CurrentIconBlob.Blob, CurrentIconBlob.Size)
            file.Close()
            GuiControl,, CurrentIcon, %tempFile%
            GuiControl,, IconStatus, From database

            ; Cleanup temp file later
            SetTimer, CleanupPreview, -2000
        }
    } else {
        GuiControl,, IconInDB, No

        ; Try to show icon from constructed file path
        if (CurrentIconPath != "" && FileExist(CurrentIconPath)) {
            GuiControl,, CurrentIcon, %CurrentIconPath%
            statusText := "From file: " . CurrentIconPath
            GuiControl,, IconStatus, %statusText%
        } else {
            GuiControl,, CurrentIcon,
            if (CurrentIconPath != "") {
                statusText := "File not found: " . CurrentIconPath
                GuiControl,, IconStatus, %statusText%
            } else {
                GuiControl,, IconStatus, No icon path in database
            }
        }
    }

    GuiControl,, StatusText, Game selected: %CurrentGameTitle%
return

CleanupPreview:
    Loop, Files, %A_Temp%\preview_icon_*.png
    {
        FileDelete, %A_LoopFileFullPath%
    }
return

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
    MsgBox, 4, Confirm Save, Save the existing icon file to database?`n`nFile: %CurrentIconPath%`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    ; Read file and save to database
    SaveIconToDatabase(CurrentIconPath, CurrentGameId, CurrentGameTitle)
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
    MsgBox, 4, Confirm Save, Save this icon to database?`n`nFile: %selectedIcon%`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    ; Save selected file to database
    SaveIconToDatabase(selectedIcon, CurrentGameId, CurrentGameTitle)
return

SaveIconToDatabase(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon to database...

    ; Check file size (optional - warn if very large)
    FileGetSize, fileSize, %iconPath%
    if (fileSize > 500000) {  ; 500KB
        MsgBox, 4, Large File, Warning: This file is quite large (%fileSize% bytes).`nContinue anyway?
        IfMsgBox, No
            return
    }

    ; Prepare SQL first - fixed StrReplace for AHK v1
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = ? WHERE GameId = '" . escapedGameId . "'"

    ; Read file into memory
    file := FileOpen(iconPath, "r")
    if (!file) {
        GuiControl,, StatusText, Error: Could not open file
        MsgBox, 16, File Error, Could not open icon file: %iconPath%
        return
    }

    ; Read file data
    fileLength := file.Length
    VarSetCapacity(iconData, fileLength)
    bytesRead := file.RawRead(iconData, fileLength)
    file.Close()

    if (bytesRead != fileLength) {
        GuiControl,, StatusText, Error: Could not read file completely
        MsgBox, 16, Read Error, Could not read icon file completely`nExpected: %fileLength% bytes`nRead: %bytesRead% bytes
        return
    }

    ; Try different BLOB array formats
    ; Format 1: Simple array with address and size
    blobArray := [{Addr: &iconData, Size: bytesRead}]

    ; Debug info
    MsgBox, 4, Debug, Data size: %bytesRead%`nSQL: %updateSql%`nTry StoreBLOB?
    IfMsgBox, No
        return

    result := db.StoreBLOB(updateSql, blobArray)

    if (result) {
        statusText := "Success: Icon saved to database (" . bytesRead . " bytes)"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (Size: " . bytesRead . " bytes)"
        GuiControl,, IconInDB, %iconText%

        ; Update preview
        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database

        MsgBox, 64, Success, Icon successfully saved to database!

    } else {
        ; If first method fails, try alternative approaches

        ; Method 2: Try with just the data
        blobArray2 := [iconData]
        result2 := db.StoreBLOB(updateSql, blobArray2)

        if (result2) {
            statusText := "Success: Icon saved to database (" . bytesRead . " bytes) - Method 2"
            GuiControl,, StatusText, %statusText%
            iconText := "Yes (Size: " . bytesRead . " bytes)"
            GuiControl,, IconInDB, %iconText%
            GuiControl,, CurrentIcon, %iconPath%
            GuiControl,, IconStatus, Saved to database
            MsgBox, 64, Success, Icon successfully saved to database!
            return
        }

        ; Method 3: Try using regular Exec with binary data
        ; This might work if StoreBLOB is not properly implemented
        VarSetCapacity(binaryData, bytesRead)
        DllCall("RtlMoveMemory", "Ptr", &binaryData, "Ptr", &iconData, "UInt", bytesRead)

        ; Convert to Base64 as last resort
        base64 := EncodeBase64(&iconData, bytesRead)
        if (base64 != "") {
            base64Sql := "UPDATE games SET IconBlob = '" . base64 . "' WHERE GameId = '" . escapedGameId . "'"
            result3 := db.Exec(base64Sql)

            if (result3) {
                statusText := "Success: Icon saved as Base64 (" . bytesRead . " bytes)"
                GuiControl,, StatusText, %statusText%
                iconText := "Yes (Base64 - Size: " . bytesRead . " bytes)"
                GuiControl,, IconInDB, %iconText%
                GuiControl,, CurrentIcon, %iconPath%
                GuiControl,, IconStatus, Saved to database (Base64)
                MsgBox, 64, Success, Icon successfully saved to database as Base64!
                return
            }
        }

        ; If all methods fail, show error
        errMsg := db.ErrorMsg
        GuiControl,, StatusText, Error: Failed to save icon to database
        MsgBox, 16, Database Error, Failed to save icon to database:`n%errMsg%`n`nTried multiple methods but all failed.
    }
}

; Base64 encoding function for fallback
EncodeBase64(pData, dataSize) {
    ; Calculate required buffer size
    DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", pData, "UInt", dataSize, "UInt", 1, "Ptr", 0, "UIntP", reqSize)

    ; Allocate buffer
    VarSetCapacity(base64, reqSize * 2)

    ; Encode to Base64
    if DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", pData, "UInt", dataSize, "UInt", 1, "Str", base64, "UIntP", reqSize) {
        return base64
    }
    return ""
}

DeleteIcon:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Confirm deletion
    MsgBox, 4, Confirm Delete, Delete the icon from database?`n`nGame: %CurrentGameTitle%`n`nNote: This will only remove it from the database, not delete the original file.

    IfMsgBox, No
        return

    ; Delete from database - fixed StrReplace for AHK v1
    StringReplace, escapedGameId, CurrentGameId, ', '', All
    sql := "UPDATE games SET IconBlob = NULL WHERE GameId = '" . escapedGameId . "'"

    if (db.Exec(sql)) {
        GuiControl,, StatusText, Icon deleted from database
        GuiControl,, IconInDB, No

        ; Update preview to show file version if available
        if (CurrentIconPath != "" && FileExist(CurrentIconPath)) {
            GuiControl,, CurrentIcon, %CurrentIconPath%
            GuiControl,, IconStatus, From file (database version deleted)
        } else {
            GuiControl,, CurrentIcon,
            GuiControl,, IconStatus, No icon available
        }

        MsgBox, 64, Success, Icon deleted from database

    } else {
        errMsg := db.ErrorMsg
        GuiControl,, StatusText, Error: Failed to delete icon
        MsgBox, 16, Database Error, Failed to delete icon:`n%errMsg%
    }
return

GuiClose:
    ; Cleanup any temp files
    Loop, Files, %A_Temp%\preview_icon_*.png
    {
        FileDelete, %A_LoopFileFullPath%
    }
    db.CloseDB()
ExitApp
