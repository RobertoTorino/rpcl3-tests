With this logic below to find a game in the database, I have to construct the correct runcommand to write to the inifile:
IniWrite, %runCommand%, %A_ScriptDir%\rpcl3.ini, RUN_GAME, RunCommand
The endresult should look like this example: RunCommand=rpcs3.exe --no-gui --fullscreen "games/Ridge Racer 7 [BLUS30001]/PS3_GAME/USRDIR/EBOOT.BIN"
This path, which is different for every game, is always in the Eboot column in the database, rpcs3.exe is always in the script directory.
The code so far:
RunGame:
    global iniFile, rpcs3Exe

    ; Kill any existing RPCS3 processes
    RunWait, taskkill /im %rpcs3Exe% /F,, Hide
    Sleep, 1000

    ; Make sure we can access global arrays
    Global G_GameIds, G_GameTitles, G_EbootPaths

    selectedRow := LV_GetNext()
    if (!selectedRow) {
        MsgBox, 48, No Selection, Please select a game from the list.
        return
    }

    ; Debug: Check array status first
    G_GameIds_MaxIndex := G_GameIds.MaxIndex()
    G_GameTitles_MaxIndex := G_GameTitles.MaxIndex()
    G_EbootPaths_MaxIndex := G_EbootPaths.MaxIndex()

    ; Check if G_GameIds exists (will be blank if undefined)
    arrayExists := (G_GameIds_MaxIndex != "") ? "Yes" : "No"

    ; Show debug info about arrays
    ;MsgBox, 0, Array Debug, Selected Row: %selectedRow%`nG_GameIds MaxIndex: %G_GameIds_MaxIndex%`nG_GameTitles MaxIndex: %G_GameTitles_MaxIndex%`nG_EbootPaths MaxIndex: %G_EbootPaths_MaxIndex%`nArrays Exist: %arrayExists%
    Log("DEBUG"
        , "Selected Row: " . selectedRow
        . "`nG_GameIds MaxIndex: " . G_GameIds_MaxIndex
        . "`nG_GameTitles MaxIndex: " . G_GameTitles_MaxIndex
        . "`nG_EbootPaths MaxIndex: " . G_EbootPaths_MaxIndex
        . "`nArrays Exist: " . arrayExists)

    ; Check if arrays exist and have data
    if (G_GameIds_MaxIndex = "" || G_GameIds_MaxIndex < selectedRow) {
    ;MsgBox, 16, No Data, Arrays not populated or insufficient data.`nSelected Row: %selectedRow%`nArray Size: %G_GameIds_MaxIndex%`n`nPlease perform a search first to populate the data.
    Log("DEBUG"
        , "Selected Row: " . selectedRow
        . "`nG_GameIds MaxIndex: " . G_GameIds_MaxIndex
        . "`nG_GameTitles MaxIndex: " . G_GameTitles_MaxIndex
        . "`nG_EbootPaths MaxIndex: " . G_EbootPaths_MaxIndex
        . "`nArrays Exist: " . arrayExists
        . "`nPlease perform a search first to populate the data.")

    return
    }

    ; Get game info from global arrays
    gameId := G_GameIds[selectedRow]
    gameTitle := G_GameTitles[selectedRow]
    ebootPath := G_EbootPaths[selectedRow]

    ; Debug what we retrieved
    ;MsgBox, 0, Debug Retrieved, Row: %selectedRow%`nArray Size: %G_GameIds_MaxIndex%`nGameId: %gameId%`nTitle: %gameTitle%`nEboot: %ebootPath%
    Log("DEBUG"
        , "Retrieved row data:"
        . "`nRow: " . selectedRow
        . "`nArray Size: " . G_GameIds_MaxIndex
        . "`nGameId: " . gameId
        . "`nTitle: " . gameTitle
        . "`nEboot: " . ebootPath)

    if (gameId = "") {
        MsgBox, 16, Error, No game ID found for row %selectedRow%.
        return
    }

    if (ebootPath = "") {
        MsgBox, 16, Error, Could not find Eboot path for selected game.`nRow: %selectedRow%`nGameId: %gameId%`nTitle: %gameTitle%
        return
    }

    ; Confirm launch
    MsgBox, 4, Confirm Launch, Launch this game?`n`nGame ID: %gameId%`nTitle: %gameTitle%`nEboot: %ebootPath%

    IfMsgBox, Yes

    ; Get RunCommand from INI
    IniRead, runCommand, %iniFile%, RUN_GAME, RunCommand
    if (runCommand = "ERROR" or runCommand = "") {
        MsgBox, 16, Error, Failed to read RunCommand from INI.
        return
    }
    Log("DEBUG", "Read from INI: " . runCommand)

    ; Wrap the entire command in quotes for cmd.exe safety
    fullRunCmd := ComSpec . " /c " . Chr(34) . runCommand . Chr(34)

    Log("DEBUG", "Running command: " . fullRunCmd)

    ; Actually run the command
    Run, %fullRunCmd%, , , newPID

    ; Check if RPCS3 started
    Sleep, 2000
    Process, Exist, %rpcs3Exe%
    if (!ErrorLevel) {
        MsgBox, 16, Error, Failed to launch RPCS3:`n%runCommand%
        Log("ERROR", "RPCS3 failed to launch.")
        SB_SetText("ERROR: RPCS3 did not launch.", 2)
        return
    }
    if (!muteSound)
    SoundPlay, %A_ScriptDir%\media\rpcl3_good_morning.wav, 1
    Log("DEBUG", "Started RPCS3 with command from INI.")
    SB_SetText("Good Morning! Your Game Started.", 2)
    UpdateStatusBar("Good Morning! Your Game Started. ", 3)
return