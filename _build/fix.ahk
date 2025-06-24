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

; Create icons folder if it doesn't exist - CORRECTED NAME
IconsFolder := A_ScriptDir . "\rpcl3_icons"
FileCreateDir, %IconsFolder%

; Create Icon Manager GUI
Gui, Font, s10, Segoe UI

; Search/Select Game section
Gui, Add, GroupBox, x10 y10 w480 h130, Select Game
Gui, Add, Text, x20 y30, Search game:
Gui, Add, Edit, vSearchTerm x20 y50 w200 h20
Gui, Add, Button, gSearchGames x230 y50 w60 h20, Search
Gui, Add, Button, gShowAllGames x300 y50 w80 h20, Show All Games
Gui, Add, ComboBox, vGameSelect x20 y75 w400 h200 gGameSelected, Select a game...
Gui, Add, Button, gShowGameList x20 y105 w150 h20, Show Full Game List

; Current Game Info section
Gui, Add, GroupBox, x10 y150 w480 h120, Current Game Info
Gui, Add, Text, x20 y170, Selected Game:
Gui, Add, Text, vSelectedGame x20 y185 w450 h20, None selected
Gui, Add, Text, x20 y205, Current Icon Path:
Gui, Add, Text, vCurrentIconPath x20 y220 w450 h20, -
Gui, Add, Text, x20 y235, Icon in rpcl3_icons:
Gui, Add, Text, vIconInFolder x20 y250 w200 h20, Checking...

; Icon Preview section
Gui, Add, GroupBox, x10 y280 w240 h150, Current Icon Preview
Gui, Add, Picture, vCurrentIcon x20 y300 w220 h100,
Gui, Add, Text, vIconStatus x20 y405 w200 h20, No icon loaded

; Icon Actions section
Gui, Add, GroupBox, x260 y280 w230 h150, Icon Actions
Gui, Add, Button, gCopyExistingIcon x270 y300 w200 h30, Copy Existing Icon to Folder
Gui, Add, Button, gBrowseAndCopyIcon x270 y340 w200 h30, Browse & Copy New Icon
Gui, Add, Button, gDeleteIconFromFolder x270 y380 w200 h30, Delete Icon from Folder

; Progress section
Gui, Add, GroupBox, x10 y440 w480 h80, Status
Gui, Add, Text, vStatusText x20 y460 w450 h40, Ready. Select a game to manage its icon.

Gui, Show, w500 h530, Icon Manager
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

ShowAllGames:
    ; Load all games into the combo box
    sql := "SELECT GameId, GameTitle FROM games ORDER BY GameTitle"

    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, Failed to load all games
        return
    }

    ; Clear and populate combo box
    GuiControl,, GameSelect, |Select a game...

    if (result.RowCount = 0) {
        GuiControl,, StatusText, No games found in database
        return
    }

    ; Add all games to combo box
    Loop, % result.RowCount {
        row := ""
        if result.GetRow(A_Index, row) {
            gameEntry := row[1] . " - " . row[2]
            GuiControl,, GameSelect, %gameEntry%
        }
    }

    statusText := "Loaded " . result.RowCount . " games. Select one from the dropdown."
    GuiControl,, StatusText, %statusText%
return

ShowGameList:
    ; Create a new window with full game list
    Gui, GameList:New, +Resize, Game List
    Gui, GameList:Font, s10, Segoe UI

    ; Get all games
    sql := "SELECT GameId, GameTitle FROM games ORDER BY GameTitle"
    if !db.GetTable(sql, result) {
        MsgBox, 16, Query Error, Failed to load games for list
        return
    }

    ; Create listview
    Gui, GameList:Add, Text, x10 y10, Select a game to view its icon:
    Gui, GameList:Add, ListView, x10 y30 w600 h400 gGameListSelect vGameListView, Game ID|Game Title

    ; Add preview area
    Gui, GameList:Add, GroupBox, x620 y10 w200 h300, Icon Preview
    Gui, GameList:Add, Picture, x630 y30 w180 h180 vGameListIcon
    Gui, GameList:Add, Text, x630 y220 w180 h20 vGameListIconStatus, No game selected
    Gui, GameList:Add, Text, x630 y240 w180 h60 vGameListIconPath,

    ; Add games to listview
    Loop, % result.RowCount {
        row := ""
        if result.GetRow(A_Index, row) {
            gameId := row[1]
            gameTitle := row[2]
            LV_Add("", gameId, gameTitle)
        }
    }

    ; Auto-size columns
    LV_ModifyCol(1, "AutoHdr")
    LV_ModifyCol(2, "AutoHdr")

    ; Show the window
    Gui, GameList:Show, w830 h450
return

GameListSelect:
    if (A_GuiEvent = "Normal") {
        ; Get selected game
        selectedRow := LV_GetNext()
        if (selectedRow = 0)
            return

        ; Get game info
        LV_GetText(selectedGameId, selectedRow, 1)
        LV_GetText(selectedGameTitle, selectedRow, 2)

        ; Check for icon in rpcl3_icons folder
        iconPath := IconsFolder . "\" . selectedGameId . ".PNG"

        if FileExist(iconPath) {
            FileGetSize, iconSize, %iconPath%
            GuiControl, GameList:, GameListIcon, %iconPath%
            GuiControl, GameList:, GameListIconStatus, Found (%iconSize% bytes)
            GuiControl, GameList:, GameListIconPath, %iconPath%
        } else {
            GuiControl, GameList:, GameListIcon,
            GuiControl, GameList:, GameListIconStatus, No icon in rpcl3_icons
            GuiControl, GameList:, GameListIconPath, Looking for: %iconPath%
        }
    }
return

GameListGuiClose:
    Gui, GameList:Destroy
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

    ; Check for icon in rpcl3_icons folder (with uppercase .PNG)
    IconInFolder := IconsFolder . "\" . CurrentGameId . ".PNG"

    ; Update GUI
    GuiControl,, SelectedGame, %CurrentGameId% - %CurrentGameTitle%
    GuiControl,, CurrentIconPath, %CurrentIconPath%

    ; Check if icon exists in rpcl3_icons folder
    if FileExist(IconInFolder) {
        FileGetSize, iconSize, %IconInFolder%
        GuiControl,, IconInFolder, Yes (%iconSize% bytes)
        GuiControl,, CurrentIcon, %IconInFolder%
        GuiControl,, IconStatus, From rpcl3_icons folder
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
    MsgBox, 4, Confirm Copy, Copy the existing icon file to rpcl3_icons folder?`n`nFrom: %CurrentIconPath%`nTo: %CurrentGameId%.PNG`nGame: %CurrentGameTitle%

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
    MsgBox, 4, Confirm Copy, Copy this icon to rpcl3_icons folder?`n`nFrom: %selectedIcon%`nTo: %CurrentGameId%.PNG`nGame: %CurrentGameTitle%

    IfMsgBox, No
        return

    CopyIconToFolder(selectedIcon, CurrentGameId, CurrentGameTitle)
return

CopyIconToFolder(sourcePath, gameId, gameTitle) {
    GuiControl,, StatusText, Copying icon to rpcl3_icons folder...

    ; Create destination path with uppercase .PNG extension
    destPath := IconsFolder . "\" . gameId . ".PNG"

    ; First, let's see what the actual paths are
    scriptDir := A_ScriptDir
    debugMsg := "Script Directory: " . scriptDir
    debugMsg .= "`nIconsFolder Variable: " . IconsFolder
    debugMsg .= "`nSource: " . sourcePath
    debugMsg .= "`nDestination: " . destPath

    MsgBox, 0, Path Debug, %debugMsg%

    ; Check if the script directory exists and is writable
    if !FileExist(A_ScriptDir) {
        MsgBox, 16, Script Dir Error, Script directory does not exist: %A_ScriptDir%
        return
    }

    ; Try to create the folder with full error checking
    MsgBox, 4, Create Folder, About to create folder: %IconsFolder%`n`nProceed?
    IfMsgBox, No
        return

    ; Method 1: Try FileCreateDir
    FileCreateDir, %IconsFolder%
    createError := ErrorLevel

    ; Check if it was created
    folderExists := FileExist(IconsFolder)

    checkMsg := "FileCreateDir ErrorLevel: " . createError
    checkMsg .= "`nFolder exists after create: " . folderExists
    checkMsg .= "`nChecking path: " . IconsFolder
    MsgBox, 0, Create Result, %checkMsg%

    ; If FileCreateDir failed, try alternative method
    if (!folderExists) {
        MsgBox, 4, Try Alternative, FileCreateDir failed. Try alternative method using RunWait?
        IfMsgBox, Yes
        {
            ; Use Windows mkdir command
            RunWait, cmd.exe /c mkdir "%IconsFolder%", , Hide

            ; Check again
            folderExists := FileExist(IconsFolder)
            MsgBox, 0, Alternative Result, Folder exists after mkdir: %folderExists%
        }
    }

    ; Final check
    if !FileExist(IconsFolder) {
        finalMsg := "Could not create rpcl3_icons folder"
        finalMsg .= "`nPath attempted: " . IconsFolder
        finalMsg .= "`nScript directory: " . A_ScriptDir
        finalMsg .= "`nScript directory exists: " . FileExist(A_ScriptDir)
        MsgBox, 16, Folder Creation Failed, %finalMsg%
        return
    }

    MsgBox, 64, Folder Success, Folder created successfully! Proceeding with file copy...

    ; Continue with the rest of the copy process...
    ; Check source file
    sourceExists := FileExist(sourcePath)
    if (!sourceExists) {
        MsgBox, 16, Source Error, Source file does not exist: %sourcePath%
        return
    }

    ; Delete destination if it exists
    if FileExist(destPath) {
        FileDelete, %destPath%
    }

    ; Copy the file
    FileCopy, %sourcePath%, %destPath%, 1

    ; Check if copy was successful
    if (ErrorLevel) {
        GuiControl,, StatusText, Error: Failed to copy icon file
        errorMsg := "Failed to copy icon file"
        errorMsg .= "`nSource: " . sourcePath
        errorMsg .= "`nDestination: " . destPath
        errorMsg .= "`nErrorLevel: " . ErrorLevel
        MsgBox, 16, Copy Error, %errorMsg%
        return
    }

    ; Verify the file was actually copied
    if !FileExist(destPath) {
        MsgBox, 16, Copy Verification Failed, Copy reported success but destination file not found: %destPath%
        return
    }

    ; Get file sizes to verify copy
    FileGetSize, sourceSize, %sourcePath%
    FileGetSize, destSize, %destPath%

    ; Success
    statusText := "Success: Icon copied to " . gameId . ".PNG (" . destSize . " bytes)"
    GuiControl,, StatusText, %statusText%

    GuiControl,, IconInFolder, Yes (%destSize% bytes)
    GuiControl,, CurrentIcon, %destPath%
    GuiControl,, IconStatus, Copied to rpcl3_icons folder

    successMsg := "Icon successfully copied to rpcl3_icons folder as " . gameId . ".PNG!"
    successMsg .= "`nSize: " . destSize . " bytes"
    MsgBox, 64, Success, %successMsg%

    ; Refresh display
    Gosub, GameSelected
}



DeleteIconFromFolder:
    if (CurrentGameId = "") {
        MsgBox, 48, No Selection, Please select a game first.
        return
    }

    ; Check if icon exists in folder (uppercase .PNG)
    IconInFolder := IconsFolder . "\" . CurrentGameId . ".PNG"
    if !FileExist(IconInFolder) {
        MsgBox, 48, No Icon, No icon found in rpcl3_icons folder for this game.`nLooking for: %IconInFolder%
        return
    }

    ; Confirm deletion
    MsgBox, 4, Confirm Delete, Delete the icon from rpcl3_icons folder?`n`nFile: %IconInFolder%`nGame: %CurrentGameTitle%`n`nNote: This will not delete the original file.

    IfMsgBox, No
        return

    ; Delete the file
    FileDelete, %IconInFolder%

    if (ErrorLevel) {
        GuiControl,, StatusText, Error: Failed to delete icon file
        MsgBox, 16, Delete Error, Failed to delete icon file:`n%IconInFolder%`n`nError: %ErrorLevel%
        return
    }

    ; Verify deletion
    if FileExist(IconInFolder) {
        MsgBox, 16, Delete Failed, File still exists after delete attempt
        return
    }

    ; Success
    GuiControl,, StatusText, Icon deleted from rpcl3_icons folder
    GuiControl,, IconInFolder, No

    ; Update preview to show original if available
    if (CurrentIconPath != "" && FileExist(CurrentIconPath)) {
        GuiControl,, CurrentIcon, %CurrentIconPath%
        GuiControl,, IconStatus, From original location (folder version deleted)
    } else {
        GuiControl,, CurrentIcon,
        GuiControl,, IconStatus, No icon available
    }

    MsgBox, 64, Success, Icon deleted from rpcl3_icons folder
return

GuiClose:
    db.CloseDB()
ExitApp
