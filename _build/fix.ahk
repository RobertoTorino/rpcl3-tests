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

; Create icons folder if it doesn't exist
IconsFolder := A_ScriptDir . "\rpcs3_icons"
FileCreateDir, %IconsFolder%

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
Gui, Add, Text, x20 y205, Icon in rpcs3_icons:
Gui, Add, Text, vIconInFolder x20 y220 w100 h20, Checking...

; Icon Preview section
Gui, Add, GroupBox, x10 y250 w240 h150, Current Icon Preview
Gui, Add, Picture, vCurrentIcon x20 y270 w220 h100,
Gui, Add, Text, vIconStatus x20 y375 w200 h20, No icon loaded

; Icon Actions section
Gui, Add, GroupBox, x260 y250 w230 h150, Icon Actions
Gui, Add, Button, gCopyExistingIcon x270 y270 w200 h30, Copy Existing Icon to Folder
Gui, Add, Button, gBrowseAndCopyIcon x270 y310 w200 h30, Browse & Copy New Icon
Gui, Add, Button, gDeleteIconFromFolder x270 y350 w200 h30, Delete Icon from Folder

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

    ; Search for games
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

    ; Get detailed game info
    StringReplace, escapedGameId, selectedGameId, ', '', All
    sql := "SELECT GameId, GameTitle, Icon0 FROM games WHERE GameId = '" . escapedGameId . "'"

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

    ; Build the full path to the original icon file
    if (CurrentIcon0Path != "") {
        CurrentIcon0Path := LTrim(CurrentIcon0Path, "\/")
        CurrentIconPath := A_ScriptDir . "\" . CurrentIcon0Path
    } else {
        CurrentIconPath := ""
    }

    ; Check for icon in rpcs3_icons folder
    IconInFolder := IconsFolder . "\" . CurrentGameId . ".png"

    ; Update GUI
    GuiControl,, SelectedGame, %CurrentGameId% - %CurrentGameTitle%
    GuiControl,, CurrentIconPath, %CurrentIconPath%

    ; Check if icon exists in rpcs3_icons folder
    if FileExist(IconInFolder) {
        GuiControl,, IconInFolder, Yes
        GuiControl,, CurrentIcon, %IconInFolder%
        GuiControl,, IconStatus, From rpcs3_icons folder
    } else {
        GuiControl,, IconInFolder, No

        ; Try to show icon from original file path
        if (CurrentIconPath != "" && FileExist(CurrentIconPath)) {
            GuiControl,, CurrentIcon, %CurrentIconPath%
            statusText := "From original location: " . CurrentIconPath
            GuiControl,, IconStatus, %statusText%
        } else {
            GuiControl,, CurrentIcon,
            if (CurrentIconPath != "") {
                statusText := "Original not found: " . CurrentIconPath
                GuiControl,, IconStatus, %statusText%
            } else {
                GuiControl,, IconStatus, No icon path in database
            }
        }
    }

    GuiControl,, StatusText, Game selected: %CurrentGameTitle%
return

CopyExistingIcon:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    if (CurrentIconPath = "" || !FileExist(CurrentIconPath)) {
        MsgBox, 48, No File, No existing icon file found for this game.`n`nExpected location: %CurrentIconPath%
        return
    }

    ; Confirm action
    MsgBox, 4, Confirm Copy, Copy the existing icon file to rpcs3_icons folder?`n`nFrom: %CurrentIconPath%`nTo: %CurrentGameId%.png`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    CopyIconToFolder(CurrentIconPath, CurrentGameId, CurrentGameTitle)
return

BrowseAndCopyIcon:
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
    MsgBox, 4, Confirm Copy, Copy this icon to rpcs3_icons folder?`n`nFrom: %selectedIcon%`nTo: %CurrentGameId%.png`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    CopyIconToFolder(selectedIcon, CurrentGameId, CurrentGameTitle)
return

CopyIconToFolder(sourcePath, gameId, gameTitle) {
    GuiControl,, StatusText, Copying icon to rpcs3_icons folder...

    ; Create destination path
    destPath := IconsFolder . "\" . gameId . ".png"

    ; Copy the file
    FileCopy, %sourcePath%, %destPath%, 1  ; 1 = overwrite existing

    if (ErrorLevel) {
        GuiControl,, StatusText, Error: Failed to copy icon file
        MsgBox, 16, Copy Error, Failed to copy icon file to:`n%destPath%`n`nError: %ErrorLevel%
        return
    }

    ; Success
    statusText := "Success: Icon copied to " . gameId . ".png"
    GuiControl,, StatusText, %statusText%

    GuiControl,, IconInFolder, Yes
    GuiControl,, CurrentIcon, %destPath%
    GuiControl,, IconStatus, Copied to rpcs3_icons folder

    MsgBox, 64, Success, Icon successfully copied to rpcs3_icons folder as %gameId%.png!

    ; Refresh display
    Gosub, GameSelected
}

DeleteIconFromFolder:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Check if icon exists in folder
    IconInFolder := IconsFolder . "\" . CurrentGameId . ".png"
    if !FileExist(IconInFolder) {
        MsgBox, 48, No Icon, No icon found in rpcs3_icons folder for this game.
        return
    }

    ; Confirm deletion
    MsgBox, 4, Confirm Delete, Delete the icon from rpcs3_icons folder?`n`nFile: %IconInFolder%`nGame: %CurrentGameTitle%`n`nNote: This will not delete the original file.

    IfMsgBox, No
        return

    ; Delete the file
    FileDelete, %IconInFolder%

    if (ErrorLevel) {
        GuiControl,, StatusText, Error: Failed to delete icon file
        MsgBox, 16, Delete Error, Failed to delete icon file:`n%IconInFolder%`n`nError: %ErrorLevel%
        return
    }

    ; Success
    GuiControl,, StatusText, Icon deleted from rpcs3_icons folder
    GuiControl,, IconInFolder, No

    ; Update preview to show original if available
    if (CurrentIconPath != "" && FileExist(CurrentIconPath)) {
        GuiControl,, CurrentIcon, %CurrentIconPath%
        GuiControl,, IconStatus, From original location (folder version deleted)
    } else {
        GuiControl,, CurrentIcon,
        GuiControl,, IconStatus, No icon available
    }

    MsgBox, 64, Success, Icon deleted from rpcs3_icons folder

    ; Refresh display
    Gosub, GameSelected
return

GuiClose:
    db.CloseDB()
ExitApp
