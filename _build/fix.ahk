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
Gui, Add, Picture, vCurrentIcon x20 y270 w220 h100,
Gui, Add, Text, vIconStatus x20 y375 w200 h20, No icon loaded

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
    CurrentIcon0Path := row[3]
    CurrentIconBlob := row[4]

    ; Build the full path to the icon file
    if (CurrentIcon0Path != "") {
        CurrentIcon0Path := LTrim(CurrentIcon0Path, "\/")
        CurrentIconPath := A_ScriptDir . "\" . CurrentIcon0Path
    } else {
        CurrentIconPath := ""
    }

    ; Update GUI
    GuiControl,, SelectedGame, %CurrentGameId% - %CurrentGameTitle%
    GuiControl,, CurrentIconPath, %CurrentIconPath%

    ; Check if icon exists in database - handle both BLOB and Base64
    if (CurrentIconBlob != "" && CurrentIconBlob != "NULL") {
        if (IsObject(CurrentIconBlob)) {
            ; Real BLOB object
            iconText := "Yes (BLOB: " . CurrentIconBlob.Size . " bytes)"
            GuiControl,, IconInDB, %iconText%

            ; Show icon from BLOB
            tempFile := A_Temp . "\preview_icon_" . A_TickCount . ".png"
            file := FileOpen(tempFile, "w")
            if (file) {
                file.RawWrite(CurrentIconBlob.Blob, CurrentIconBlob.Size)
                file.Close()
                GuiControl,, CurrentIcon, %tempFile%
                GuiControl,, IconStatus, From database (BLOB)
                SetTimer, CleanupPreview, -2000
            }
        } else {
            ; Assume Base64 string
            iconText := "Yes (Base64: " . StrLen(CurrentIconBlob) . " chars)"
            GuiControl,, IconInDB, %iconText%

            ; Decode Base64 and show icon
            tempFile := A_Temp . "\preview_icon_" . A_TickCount . ".png"
            if (DecodeBase64ToFile(CurrentIconBlob, tempFile)) {
                GuiControl,, CurrentIcon, %tempFile%
                GuiControl,, IconStatus, From database (Base64)
                SetTimer, CleanupPreview, -2000
            } else {
                GuiControl,, IconStatus, Error decoding Base64
            }
        }
    } else {
        GuiControl,, IconInDB, No

        ; Try to show icon from file path
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

    SaveIconToDatabase(selectedIcon, CurrentGameId, CurrentGameTitle)
return

SaveIconToDatabase(iconPath, gameId, gameTitle) {
    GuiControl,, StatusText, Saving icon to database...

    ; Check file size
    FileGetSize, fileSize, %iconPath%
    if (fileSize > 500000) {
        MsgBox, 4, Large File, Warning: This file is quite large (%fileSize% bytes).`nContinue anyway?
        IfMsgBox, No
            return
    }

    ; Read file as binary and convert to Base64
    FileRead, iconBinary, *c %iconPath%
    if ErrorLevel {
        GuiControl,, StatusText, Error: Could not read file
        MsgBox, 16, File Error, Could not read icon file: %iconPath%
        return
    }

    ; Convert to Base64
    base64Data := EncodeBase64String(iconBinary)
    if (base64Data = "") {
        GuiControl,, StatusText, Error: Could not encode to Base64
        MsgBox, 16, Encoding Error, Could not convert file to Base64
        return
    }

    ; Escape single quotes in Base64 (just in case)
    StringReplace, base64Data, base64Data, ', '', All

    ; Prepare and execute SQL
    StringReplace, escapedGameId, gameId, ', '', All
    updateSql := "UPDATE games SET IconBlob = '" . base64Data . "' WHERE GameId = '" . escapedGameId . "'"

    if (db.Exec(updateSql)) {
        bytesOriginal := StrLen(iconBinary)
        statusText := "Success: Icon saved as Base64 (" . bytesOriginal . " bytes original)"
        GuiControl,, StatusText, %statusText%

        iconText := "Yes (Base64: " . StrLen(base64Data) . " chars)"
        GuiControl,, IconInDB, %iconText%

        ; Update preview
        GuiControl,, CurrentIcon, %iconPath%
        GuiControl,, IconStatus, Saved to database (Base64)

        MsgBox, 64, Success, Icon successfully saved to database as Base64!

        ; Refresh the game selection to show updated status
        Gosub, GameSelected

    } else {
        errMsg := db.ErrorMsg
        GuiControl,, StatusText, Error: Failed to save icon to database
        MsgBox, 16, Database Error, Failed to save icon to database:`n%errMsg%
    }
}

; Base64 encoding function
EncodeBase64String(inputData) {
    ; Get input size
    inputSize := StrLen(inputData)
    if (inputSize = 0)
        return ""

    ; Calculate required buffer size for Base64
    DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &inputData, "UInt", inputSize, "UInt", 0x1, "Ptr", 0, "UIntP", reqSize)

    ; Allocate buffer
    VarSetCapacity(base64Output, reqSize * 2, 0)

    ; Encode to Base64
    success := DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &inputData, "UInt", inputSize, "UInt", 0x1, "Str", base64Output, "UIntP", reqSize)

    if (success) {
        ; Remove any newlines/carriage returns that Windows might add
        StringReplace, base64Output, base64Output, `r`n, , All
        StringReplace, base64Output, base64Output, `r, , All
        StringReplace, base64Output, base64Output, `n, , All
        return base64Output
    }

    return ""
}

; Base64 decoding function
DecodeBase64ToFile(base64Data, outputFile) {
    if (base64Data = "" || outputFile = "")
        return false

    ; Calculate required buffer size
    dataSize := StrLen(base64Data)
    DllCall("Crypt32.dll\CryptStringToBinary", "Str", base64Data, "UInt", dataSize, "UInt", 0x1, "Ptr", 0, "UIntP", reqSize, "Ptr", 0, "Ptr", 0)

    ; Allocate buffer
    VarSetCapacity(decodedData, reqSize, 0)

    ; Decode Base64
    success := DllCall("Crypt32.dll\CryptStringToBinary", "Str", base64Data, "UInt", dataSize, "UInt", 0x1, "Ptr", &decodedData, "UIntP", reqSize, "Ptr", 0, "Ptr", 0)

    if (success) {
        ; Write to file
        file := FileOpen(outputFile, "w")
        if (file) {
            file.RawWrite(decodedData, reqSize)
            file.Close()
            return true
        }
    }

    return false
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

    ; Delete from database
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
