; ─── music player. ────────────────────────────────────────────────────────────────────
ShowMusicPlayer:
    MusicPlayer_Init()
    MusicPlayer_CreateGUI()
    MusicPlayer_LoadPlaylist()
    Gui, MusicPlayer:Show, w515 h482, RPCL3 Music Player - © %A_YYYY% - Philip
return

MusicPlayer_Init() {
    global MusicPlayer_playlist, MusicPlayer_currentIndex, MusicPlayer_audioDir, MusicPlayer_playlistFile
    global MusicPlayer_sortCol, MusicPlayer_sortDir, MusicPlayer_TestTrack, MusicPlayer_CurrentTrack
    global MusicPlayer_CurrentTrackName, MusicPlayer_LastMetaFile, MusicPlayer_ffmpeg, MusicPlayer_iniFile
    global MusicPlayer_player, MusicPlayer_WMP, MusicPlayerHwnd

    MusicPlayer_playlist := []
    MusicPlayer_currentIndex := 1
    MusicPlayer_audioDir := A_ScriptDir . "\rpcl3_recordings"
    MusicPlayer_playlistFile := MusicPlayer_audioDir . "\rpcl3_playlist.m3u"
    MusicPlayer_sortCol := 1
    MusicPlayer_sortDir := "Asc"
    MusicPlayer_TestTrack := MusicPlayer_audioDir . "\rpcl3_test.mp3"
    MusicPlayer_CurrentTrack := ""
    MusicPlayer_CurrentTrackName := ""
    MusicPlayer_LastMetaFile := ""
    MusicPlayer_ffmpeg := A_ScriptDir . "\rpcl3_tools\ffmpeg.exe"
    MusicPlayer_iniFile := A_ScriptDir . "\rpcl3_settings.ini"

    ; Ensure directory exists
    if !FileExist(MusicPlayer_audioDir)
        FileCreateDir, %MusicPlayer_audioDir%

    ; Add test track to playlist if it exists
    if FileExist(MusicPlayer_TestTrack)
        MusicPlayer_playlist.Push(MusicPlayer_TestTrack)

    SetTimer, MusicPlayer_UpdateTrackInfo, 500
}

MusicPlayer_CreateGUI() {
    global MusicPlayer_playlist, MusicPlayer_currentIndex, MusicPlayer_audioDir, MusicPlayer_playlistFile
    global MusicPlayer_sortCol, MusicPlayer_sortDir, MusicPlayer_TestTrack, MusicPlayer_CurrentTrack
    global MusicPlayer_CurrentTrackName, MusicPlayer_LastMetaFile, MusicPlayer_ffmpeg, MusicPlayer_iniFile
    global MusicPlayer_player, MusicPlayer_WMP, MusicPlayerHwnd

    Gui, MusicPlayer:New, +AlwaysOnTop +LabelMusicPlayer_ +HwndMusicPlayerHwnd +Resize
    Gui, MusicPlayer:Font, s10 q5, Segoe UI
    Gui, MusicPlayer:Margin, 15, 15

    ; Main ListView
    Gui, MusicPlayer:Add, ListView, vMusicPlayer_TrackList gMusicPlayer_TrackClicked x0 y0 w515 h227 AltSubmit Grid, Name|Size|Bitrate|Type
    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    LV_InsertCol(5, 0, "Full Path")
    LV_ModifyCol(5, 0)

    ; Progress bars and buttons
    Gui, MusicPlayer:Add, Progress, x0 y0 w515 h1 0x10 Disabled
    Gui, MusicPlayer:Font, s9 q5, Segoe UI Emoji
    Gui, MusicPlayer:Add, Progress, x0 y227 w515 h1 0x10 Disabled
    Gui, MusicPlayer:Add, Text, gMusicPlayer_PlayPause x0 y228 w100 h23 Border +Center +0x200, Play/Pause
    Gui, MusicPlayer:Add, Text, gMusicPlayer_StopTrack x100 y228 w75 h23 Border +Center +0x200, Stop
    Gui, MusicPlayer:Add, Text, gMusicPlayer_NextTrack x175 y228 w75 h23 Border +Center +0x200, Next
    Gui, MusicPlayer:Add, Progress, x0 y250 w515 h1 0x10 Disabled

    ; Windows Media Player control
    Gui, MusicPlayer:Add, ActiveX, x0 y250 w515 h180 vMusicPlayer_WMP, WMPlayer.OCX
    MusicPlayer_player := MusicPlayer_WMP
    MusicPlayer_WMP.uiMode := "full"
    MusicPlayer_WMP.Enabled := true
    MusicPlayer_WMP.settings.volume := 50

    ; Track info display
    Gui, MusicPlayer:Font, norm s12 q5, Segoe UI Emoji
    Gui, MusicPlayer:Add, Progress, x0 y430 w515 h1 0x10 Disabled
    Gui, MusicPlayer:Add, Text, vMusicPlayer_CurrentTrack x2 y432 w515 +Left +0x200, Now playing: (TestTrack)
    Gui, MusicPlayer:Add, Progress, x0 y458 w515 h1 0x10 Disabled

    ; Create context menu
    Menu, MusicPlayer_TrackMenu, Add, Convert to MP3, MusicPlayer_OnConvertToMP3
    Menu, MusicPlayer_TrackMenu, Add, Show in Explorer, MusicPlayer_OnShowInExplorer
    Menu, MusicPlayer_TrackMenu, Add, Copy File Path, MusicPlayer_OnCopyPath
    Menu, MusicPlayer_TrackMenu, Add, Rename File, MusicPlayer_OnRenameFile
    Menu, MusicPlayer_TrackMenu, Add, Delete File, MusicPlayer_OnDeleteFile

    ; Set initial track if available
    if FileExist(MusicPlayer_TestTrack) {
        MusicPlayer_CurrentTrack := MusicPlayer_TestTrack
        SplitPath, MusicPlayer_CurrentTrack, FileName
        GuiControl, MusicPlayer:, MusicPlayer_CurrentTrack, Now playing: %FileName%
    }
}

MusicPlayer_LoadPlaylist() {
    global MusicPlayer_playlist, MusicPlayer_audioDir

    MusicPlayer_playlist := []

    Loop, Files, %MusicPlayer_audioDir%\*.*, R
    {
        SplitPath, A_LoopFileFullPath,,, ext
        StringLower, ext, ext
        if (ext = "mp3" || ext = "wav")
            MusicPlayer_playlist.Push(A_LoopFileFullPath)
    }

    MusicPlayer_RefreshListView()
}

MusicPlayer_RefreshListView() {
    global MusicPlayer_playlist, MusicPlayer_currentIndex

    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    LV_Delete()

    for index, path in MusicPlayer_playlist {
        SplitPath, path, name, dir, ext
        FileGetSize, sizeBytes, %path%
        sizeMB := Round(sizeBytes / 1048576, 2) . " MB"
        bitrate := MusicPlayer_GetBitrate(path)
        row := LV_Add("", name, sizeMB, bitrate, ext)
        LV_Modify(row, "Col5", path)
    }

    LV_ModifyCol()

    ; Highlight current track
    Loop, % LV_GetCount()
        LV_Modify(A_Index, "")
    if (MusicPlayer_currentIndex <= LV_GetCount())
        LV_Modify(MusicPlayer_currentIndex, "cBlue")
}

MusicPlayer_GetBitrate(file) {
    global MusicPlayer_player

    try {
        media := MusicPlayer_player.newMedia(file)
        return media.getItemInfo("Bitrate") . " kbps"
    } catch e {
        return "?"
    }
}

MusicPlayer_PlayCurrent(filePath := "") {
    global MusicPlayer_playlist, MusicPlayer_currentIndex, MusicPlayer_CurrentTrack, MusicPlayer_player

    if (filePath != "") {
        if !FileExist(filePath) {
            MsgBox, 16, Error, File not found:`n%filePath%
            return
        }
        MusicPlayer_CurrentTrack := MusicPlayer_GetFileName(filePath)
    } else {
        if !(IsObject(MusicPlayer_playlist) && MusicPlayer_playlist.Length() >= MusicPlayer_currentIndex && MusicPlayer_currentIndex >= 1) {
            MsgBox, 16, Error, Playlist is empty or current index is invalid.
            return
        }
        filePath := MusicPlayer_playlist[MusicPlayer_currentIndex]
        MusicPlayer_CurrentTrack := MusicPlayer_GetFileName(filePath)
    }

    GuiControl, MusicPlayer:, MusicPlayer_CurrentTrack, Now Playing: %MusicPlayer_CurrentTrack%

    ; Update ListView highlight
    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    Loop, % LV_GetCount()
        LV_Modify(A_Index, "")
    LV_Modify(MusicPlayer_currentIndex, "cBlue")

    MusicPlayer_player.URL := filePath
    MusicPlayer_player.controls.play()
    Sleep, 500
}

MusicPlayer_GetFileName(path) {
    SplitPath, path,,, ext, name_no_ext
    return name_no_ext . "." . ext
}

MusicPlayer_ConvertToMP3(filePath) {
    global MusicPlayer_ffmpeg

    SplitPath, filePath, name, dir, ext, name_no_ext

    StringLower, extLower, ext
    if (extLower = "mp3") {
        MsgBox, 64, Info, File is already an MP3. Conversion skipped.
        return
    }

    if (!dir) {
        MsgBox, 16, Error, Could not extract directory from:`n%filePath%
        return
    }

    if !FileExist(MusicPlayer_ffmpeg) {
        MsgBox, 16, Error, ffmpeg.exe not found in /rpcl3_tools
        return
    }

    baseOutput := dir . "\" . name_no_ext
    outputFile := baseOutput . ".mp3"

    if FileExist(outputFile) {
        choice := MusicPlayer_ConfirmFileExists(outputFile)
        if (choice = "override") {
            FileDelete, %outputFile%
        } else if (choice = "append") {
            Loop {
                newFile := baseOutput . " (copy" . (A_Index > 1 ? " " A_Index : "") . ").mp3"
                if !FileExist(newFile) {
                    outputFile := newFile
                    break
                }
            }
        } else {
            MsgBox, 48, Cancelled, Conversion cancelled by user.
            return
        }
    }

    StringReplace, filePathEsc, filePath, ", "", All
    StringReplace, outputFileEsc, outputFile, ", "", All

    RunWait, %ComSpec% /c ""%MusicPlayer_ffmpeg%" -y -i "%filePathEsc%" -codec:a libmp3lame -qscale:a 2 "%outputFileEsc%"", , Hide

    if FileExist(outputFile)
        MsgBox, 64, Success, MP3 saved to:`n%outputFile%
    else
        MsgBox, 16, Error, Conversion failed.
}

MusicPlayer_ConfirmFileExists(file) {
    static choice := ""
    choice := ""

    Gui, MusicPlayerConfirm:New, +AlwaysOnTop +Owner +ToolWindow +LabelMusicPlayerConfirm_, Confirm Action
    Gui, MusicPlayerConfirm:Font, s10 cRed q5
    Gui, MusicPlayerConfirm:Add, Text,, MP3 already exists:
    Gui, MusicPlayerConfirm:Font, s10 q5
    SplitPath, file, nameOnly
    Gui, MusicPlayerConfirm:Add, Text,, %nameOnly%
    Gui, MusicPlayerConfirm:Add, Button, gMusicPlayerConfirm_Override w100 Default, Override
    Gui, MusicPlayerConfirm:Add, Button, gMusicPlayerConfirm_AppendCopy w100, Append Copy
    Gui, MusicPlayerConfirm:Add, Button, gMusicPlayerConfirm_Skip w100, Skip
    Gui, MusicPlayerConfirm:Show,, File Exists

    Loop {
        Sleep, 50
        if (choice != "")
            break
    }

    Gui, MusicPlayerConfirm:Destroy
    return choice
}

; ═══════════════════════════════════════════════════════════════════════════════════════
; EVENT HANDLERS
; ═══════════════════════════════════════════════════════════════════════════════════════

MusicPlayer_GuiClose:
    SetTimer, MusicPlayer_UpdateTrackInfo, Off
    Gui, MusicPlayer:Destroy
return

MusicPlayer_GuiContextMenu:
    if (A_GuiControl = "MusicPlayer_TrackList") {
        Menu, MusicPlayer_TrackMenu, Show
    }
return

MusicPlayer_TrackClicked:
    global MusicPlayer_sortCol, MusicPlayer_sortDir, MusicPlayer_currentIndex

    if (A_GuiEvent = "ColClick") {
        if (A_EventInfo = MusicPlayer_sortCol)
            MusicPlayer_sortDir := (MusicPlayer_sortDir = "Asc") ? "Desc" : "Asc"
        else {
            MusicPlayer_sortCol := A_EventInfo
            MusicPlayer_sortDir := "Asc"
        }

        Gui, MusicPlayer:ListView, MusicPlayer_TrackList
        LV_ModifyCol(MusicPlayer_sortCol, MusicPlayer_sortDir)

        row := LV_GetNext()
        if row {
            MusicPlayer_currentIndex := row
            LV_GetText(currentFile, row, 5)
        }
    }
    else if (A_GuiEvent = "DoubleClick") {
        row := A_EventInfo
        LV_GetText(filePath, row, 5)
        if FileExist(filePath) {
            MusicPlayer_currentIndex := row
            MusicPlayer_PlayCurrent(filePath)
        } else {
            MsgBox, 16, Error, File not found:`n%filePath%
        }
    }
return

MusicPlayer_PlayPause:
    global MusicPlayer_player

    if (MusicPlayer_player.playState = 2)
        MusicPlayer_player.controls.play()
    else if (MusicPlayer_player.playState = 3)
        MusicPlayer_player.controls.pause()
    else
        MusicPlayer_PlayCurrent()
return

MusicPlayer_StopTrack:
    global MusicPlayer_player

    MusicPlayer_player.controls.stop()
return

MusicPlayer_NextTrack:
    global MusicPlayer_currentIndex, MusicPlayer_playlist, MusicPlayerHwnd

    MusicPlayer_currentIndex++
    if (MusicPlayer_currentIndex > MusicPlayer_playlist.Length())
        MusicPlayer_currentIndex := 1

    MusicPlayer_PlayCurrent()

    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    Loop, % LV_GetCount() {
        LV_Modify(A_Index, "-Select")
    }
    LV_Modify(MusicPlayer_currentIndex, "Select Focus")
    ControlFocus, SysListView321, ahk_id %MusicPlayerHwnd%
return

MusicPlayer_UpdateTrackInfo:
    global MusicPlayer_player

    Gui, MusicPlayer:Default
    if (MusicPlayer_player.currentMedia) {
        pos := Round(MusicPlayer_player.controls.currentPosition)
        dur := Round(MusicPlayer_player.currentMedia.duration)
        timeStr := MusicPlayer_FormatTime(pos) . " / " . MusicPlayer_FormatTime(dur)
        ; Update time display if you add it later
    }
return

MusicPlayer_FormatTime(seconds) {
    return Format("{:02}:{:02}", seconds//60, Mod(seconds, 60))
}

; Context Menu Handlers
MusicPlayer_OnConvertToMP3:
    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        if FileExist(filePath)
            MusicPlayer_ConvertToMP3(filePath)
        else
            MsgBox, 48, Warning, File does not exist:`n%filePath%
    } else {
        MsgBox, 48, Warning, No file selected.
    }
return

MusicPlayer_OnShowInExplorer:
    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        Run, explorer.exe /select`, "%filePath%"
    }
return

MusicPlayer_OnCopyPath:
    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        Clipboard := filePath
        TrayTip, Copied, File path copied to clipboard., 1
    }
return

MusicPlayer_OnRenameFile:
    global MusicPlayerHwnd

    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        SplitPath, filePath, name, dir, ext, nameNoExt

        WinGetPos, x, y, w, h, ahk_id %MusicPlayerHwnd%
        inputX := x + w + 10
        inputY := y + 100

        InputBox, newName, Rename File, Enter a new file name (without extension):, , 300, 130, %inputX%, %inputY%, , , %nameNoExt%

        if ErrorLevel
            return

        newPath := dir . "\" . newName . "." . ext
        FileMove, %filePath%, %newPath%
        if !ErrorLevel {
            LV_Modify(row, "Col1", newName . "." . ext)
            LV_Modify(row, "Col5", newPath)
        } else {
            MsgBox, 16, Error, Failed to rename file.
        }
    }
return

MusicPlayer_OnDeleteFile:
    Gui, MusicPlayer:ListView, MusicPlayer_TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)

        if !FileExist(filePath) {
            MsgBox, 16, Error, File does not exist:`n%filePath%
            return
        }

        Gui, MusicPlayer:+OwnDialogs +AlwaysOnTop
        MsgBox, 52, Confirm Delete, Are you sure you want to delete this file?`n%filePath%
        Gui, MusicPlayer:-AlwaysOnTop

        IfMsgBox Yes
        {
            FileRecycle, %filePath%
            LV_Delete(row)
        }
    } else {
        MsgBox, 48, Info, Please select a file to delete.
    }
return

; Confirm dialog button handlers
MusicPlayerConfirm_Override:
    choice := "override"
return

MusicPlayerConfirm_AppendCopy:
    choice := "append"
return

MusicPlayerConfirm_Skip:
    choice := "skip"
return

MusicPlayerConfirm_GuiClose:
    choice := "skip"
return

MusicPlayer_GuiDropFiles:
    global MusicPlayer_playlist

    Loop, Parse, A_GuiEvent, `n
    {
        file := A_LoopField
        if (file ~= "\.(mp3|wav)$" && FileExist(file)) {
            MusicPlayer_playlist.Push(file)
        }
    }
    MusicPlayer_RefreshListView()
return

; ─── end music player. ────────────────────────────────────────────────────────────────────
