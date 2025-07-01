; ─── music player. ────────────────────────────────────────────────────────────────────
ShowMusicPlayer:
    Gui, MusicPlayer:New
    Gui, MusicPlayer:+AlwaysOnTop +LabelMusicPlayer
    Gui, MusicPlayer:Font, s10 q5, Segoe UI

SetBatchLines, -1
SetTimer, UpdateTrackInfo, 500
SetTitleMatchMode, 2

ffmpeg :=  A_ScriptDir . "\rpcl3_tools\ffmpeg.exe"

baseDir := A_ScriptDir . "\rpcl3_recordings"
filePath := baseDir . "\" . filePath

if (playlist.Length()) {
    CurrentTrack := playlist[1]
    CurrentTrackName := GetFileName(CurrentTrack)
}
global playlist         := []
global currentIndex     := 1
global audioDir         := A_ScriptDir . "\rpcl3_recordings"
global playlistFile     := audioDir . "\rpcl3_playlist.m3u"
sortCol                 := 1
sortDir                 := "Asc"
global TestTrack        := audioDir . "\rpcl3_test.mp3"
playlist.Push(audioDir . "\rpcl3_test.mp3")
CurrentTrack            := filePath
CurrentTrackName        := GetFileName(filePath)
global LastMetaFile := ""

PlayCurrent()

title := "RPCL3 Music Player - " . Chr(169) . " " . A_YYYY . " - Philip"

Gui, +Resize
Gui, Font, s10 q5, Segoe UI
Gui, Margin, 15, 15
Gui, +HwndMyGuiHwnd
Gui, +AlwaysOnTop
Gui, +LastFound
Gui, Add, ListView, vTrackList gTrackClicked x0 y0 w515 h227 AltSubmit Grid, Name|Size|Bitrate|Type

Gui, Add, Progress, x0 y0 w515 h1 0x10 Disabled
Gui, ListView, TrackList             ; Set target ListView
LV_InsertCol(5, 0, "Full Path")      ; Insert hidden column
LV_ModifyCol(5, 0)                   ; Hide column (0 width)

Gui, Font, s9 q5, Segoe UI Emoji
Gui, Add, Progress, x0 y227 w515 h1 0x10 Disabled
Gui, Add, Text, gPlayPause                x0 y228 w100 h23 Border +Center +0x200, Play/Pause
Gui, Add, Text, gStopTrack              x100 y228 w75 h23 Border +Center +0x200, Stop
Gui, Add, Text, gNextTrack              x175 y228 w75 h23 Border +Center +0x200, Next
Gui, Add, Progress, x0 y250 w515 h1 0x10 Disabled

Gui, Add, ActiveX, x0 y250 w515 h180 vWMP, WMPlayer.OCX
player := WMP
WMP.uiMode := "full"
WMP.Enabled := true
WMP.settings.volume := 50

Gui, Font, norm s12 q5, Segoe UI Emoji
Gui, Add, Progress, x0 y430 w515 h1 0x10 Disabled
Gui, Add, Text, vCurrentTrack x2 y432 w515 +Left +0x200, Now playing: (TestTrack)
Gui, Add, Progress, x0 y458 w515 h1 0x10 Disabled

Gui, Font
CurrentTrack := FileExist(CurrentTrack) ? CurrentTrack : TestTrack
SplitPath, CurrentTrack, FileName
GuiControl,, CurrentTrack, Now playing: %FileName%

Gui, Show, w515 h482, %title%

Menu, Trackmenu, Add, Convert to MP3, OnConvertToMP3
Menu, Trackmenu, Add, Show in Explorer, OnShowInExplorer
Menu, Trackmenu, Add, Copy File Path, OnCopyPath
Menu, Trackmenu, Add, Rename File, OnRenameFile
Menu, Trackmenu, Add, Delete File, OnDeleteFile

GuiControl, +0x100, TrackList
GuiControl,, StatusBar, Converting to MP3...
GuiControl,, StatusBar, Ready.

player.settings.volume := 50
GuiControl,, VolumeSlider, % player.settings.volume

SB_SetText("Current path: " . filePath)

; Load playlist
EnsureDirExists()

LoadPlaylist()
global iniFile
currentIndex := 1

if (A_GuiEvent = "DoubleClick")
    LV_ModifyCol(A_EventInfo, "AutoHdr")

    IniWrite, %sortCol%, %iniFile%, SORT, Column
    IniWrite, %sortDir%, %iniFile%, SORT, Direction
    Log("DEBUG", "Load playlist: SortCol=" . sortCol . ", written to: " . iniFile)
    Log("DEBUG", "Load playlist: SortDir=" . sortDir . ", written to: " . iniFile)
return


OnShowInExplorer:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        Run, explorer.exe /select`, "%filePath%"
    }
return


OnCopyPath:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        Clipboard := filePath
        TrayTip, Copied, File path copied to clipboard., 1
    }
return


OnRenameFile:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        SplitPath, filePath, name, dir, ext, nameNoExt

        ; Get position of main window
        Gui +LastFound
        mainID := WinExist()
        WinGetPos, x, y, w, h, ahk_id %mainID%

        ; Decide where to show InputBox (e.g., to the right)
        inputX := x + w + 10     ; 10 pixels to the right of the main window
        inputY := y + 100        ; a bit lower than top

        ; Show InputBox at custom position
        InputBox, newName, Rename File, Enter a new file name (without extension):, , 300, 130, %inputX%, %inputY%, , , %nameNoExt%

        if ErrorLevel
            return

        newPath := dir . "\" . newName . "." . ext
        FileMove, %filePath%, %newPath%
        if !ErrorLevel {
            LV_Modify(row, "Col1", newName . "." . ext)
            LV_Modify(row, "Col5", newPath)
            Log("INFO", "File renamed to: " . newPath)
        } else {
            MsgBox, 16, Error, Failed to rename file.
            Log("ERROR", "Rename failed from " . filePath . " to " . newPath)
        }
    }
return


OnDeleteFile:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)

        ; Make sure file exists before asking
        if !FileExist(filePath) {
            MsgBox, 16, Error, File does not exist:`n%filePath%
            return
        }

        ; Show prompt on top
        Gui +OwnDialogs +AlwaysOnTop
        MsgBox, 52, Confirm Delete, Are you sure you want to delete this file?`n%filePath%
        Gui -AlwaysOnTop

        IfMsgBox Yes
        {
            FileRecycle, %filePath%
            LV_Delete(row)
            Log("INFO", "File deleted to recycle bin: " . filePath)
        }
    } else {
        MsgBox, 48, Info, Please select a file to delete.
    }
return


OnEditArtist:
    MsgBox, Title editor not yet implemented.
return


OnEditTitle:
    ; InputBox for title editing
    MsgBox, Title editor not yet implemented.
return


OnPlay:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5)
        PlayCurrent(filePath)
    }
return


OnPlayNext:
    MsgBox, On Play Next not yet implemented.
return


OnPlayAllFromHere:
    MsgBox, On PlayAll From Here not yet implemented.
return


ToolsMenu:
    MsgBox, Tools Menu not yet implemented.
return


ConvertMenu:
    ; InputBox for title editing
    MsgBox, Title editor not yet implemented.
return


MetadataMenu:
    ; InputBox for title editing
    MsgBox, Convert Menu not yet implemented.
return


EnsureDirExists() {
    global audioDir
    if !FileExist(audioDir)
        FileCreateDir, %audioDir%
}


LoadPlaylist() {
    global playlist, audioDir
    playlist := []

    Loop, Files, %audioDir%\*.*, R
    {
        SplitPath, A_LoopFileFullPath,,, ext
        StringLower, ext, ext
        if (ext = "mp3" || ext = "wav")
            playlist.Push(A_LoopFileFullPath)
    }

    RefreshListView()
}


SavePlaylist() {
    global playlist, playlistFile
    FileDelete, %playlistFile%
    for each, track in playlist
    Log("DEBUG", "Save Playlist track: " . track . playlistFile)
}


RefreshListView() {
    global playlist
    Gui, ListView, TrackList
    LV_Delete()  ; Clear all existing rows

    for index, path in playlist {
        SplitPath, path, name, dir, ext
        FileGetSize, sizeBytes, %path%
        sizeMB := Round(sizeBytes / 1048576, 2) . " MB"
        bitrate := GetBitrate(path)
        row := LV_Add("", name, sizeMB, bitrate, ext)
        LV_Modify(row, "Col5", path) ; Set hidden column with full path
    }

    LV_ModifyCol() ; Auto-size visible columns

        ; <-- Add your highlight code here:
        Loop, % LV_GetCount()
            LV_Modify(A_Index, "")  ; Reset all rows to normal

        LV_Modify(currentIndex, "cBlue") ; Highlight current row text color blue
        ; Or LV_Modify(currentIndex, "bYellow") to highlight background
}


GuiContextMenu:
    if (A_GuiControl = "TrackList") {
        Menu, TrackMenu, Show
    }
return


GetBitrate(file) {
    try {
        media := player.newMedia(file)
        return media.getItemInfo("Bitrate") . " kbps"
        Log("INFO", "Get bitrate, bitrate: " media.getItemInfo("Bitrate") . " kbps")
    } catch e {
        return "?"
        Log("WARNING", "Get bitrate, no bitrate info available.")
    }
}


PlaySelected:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5) ; Get full path from hidden column
        Log("DEBUG", "Play selected, file path from LV_GetText: " . filePath)
        MsgBox, 64, Debug, filePath = %filePath%
        Log("DEBUG", "Play selected, file path = " . filePath)
        currentIndex := row
        PlayCurrent(filePath)
        Log("DEBUG", "Trying to play: " . filePath)
    }
return


PlayCurrent(filePath := "") {
    global player, playlist, currentIndex, CurrentTrack

    if (filePath != "") {
        if !FileExist(filePath) {
            MsgBox, 16, Error, File not found:`n%filePath%
            Log("ERROR", "Play current, file not found: " . filePath)
            return
        }
        CurrentTrack := GetFileName(filePath)
    } else {
        if !(IsObject(playlist) && playlist.Length() >= currentIndex && currentIndex >= 1) {
            MsgBox, 16, Error, Playlist is empty or current index is invalid.
            Log("ERROR", "Play current, playlist is empty or current index is invalid.")
            return
        }
        filePath := playlist[currentIndex]
        CurrentTrack := GetFileName(filePath)
    }

    ; Dynamically update GUI track label
    GuiControl,, CurrentTrack, Now Playing: %CurrentTrack%


   ; Update ListView highlight:
   Loop, % LV_GetCount()
   LV_Modify(A_Index, "")  ; reset all rows
   LV_Modify(currentIndex, "cBlue") ; highlight current

    player.URL := filePath
    player.controls.play()
    Sleep, 500
}


; Helper function to extract filename from path
GetFileName(path) {
    SplitPath, path,,, ext, name_no_ext
    return name_no_ext . "." . ext
    Log("DEBUG", "Get file name, trying to play: " . track . filePath)
}


PlayPause() {
    global player
    if (player.playState = 2)
        player.controls.play()
    else if (player.playState = 3)
        player.controls.pause()
    else
        PlayCurrent()
}


StopTrack() {
    global player
    player.controls.stop()
}


NextTrack() {
    global currentIndex, playlist, MyGuiHwnd

    currentIndex++
    if (currentIndex > playlist.Length())
        currentIndex := 1

    PlayCurrent()

    Gui, ListView, TrackList

    ; Clear all previous selections
    Loop, % LV_GetCount() {
        LV_Modify(A_Index, "-Select")
    }

    ; Select and focus the current track only
    LV_Modify(currentIndex, "Select Focus")

    ; Set focus to ListView so selection stays blue
    ControlFocus, SysListView321, ahk_id %MyGuiHwnd%
}


AdjustVolume:
    GuiControlGet, VolumeSlider
    player.settings.volume := VolumeSlider
return


UpdateTrackInfo:
    if (player.currentMedia) {
        pos := Round(player.controls.currentPosition)
        dur := Round(player.currentMedia.duration)
        timeStr := FormatTime(pos) . " / " . FormatTime(dur)
        GuiControl,, TimeDisplay, %timeStr%
        if (dur > 0)
            GuiControl,, SeekSlider, % (pos * 100 // dur)
    }
return


SeekTrack:
    GuiControlGet, SeekSlider
    if (player.currentMedia) {
        dur := player.currentMedia.duration
        newPos := (SeekSlider / 100.0) * dur
        player.controls.currentPosition := newPos
    }
return


FormatTime(seconds) {
    return Format("{:02}:{:02}", seconds//60, Mod(seconds, 60))
}


GuiDropFiles:
    Loop, Parse, A_GuiEvent, `n
    {
        file := A_LoopField
        if (file ~= "\.(mp3|wav)$" && FileExist(file)) {
            playlist.Push(file)
        }
    }
    SavePlaylist()
    RefreshListView()
return


; Right-click menu to delete track
~RButton::
    MouseGetPos,,, hwnd, control
    if (control = "SysListView321") {
        Gui, ListView, TrackList
        LV_GetNext(RowNum, "Focused")
        if RowNum {
            LV_GetText(currentFile, RowNum, 5)  ; Get full path from Col5
            FileToDelete := playlist[RowNum]
            MsgBox, 4,, Remove this track from playlist?
            Log("DEBUG", "Delete track, remove this track from playlist?")
            IfMsgBox Yes
            {
                playlist.RemoveAt(RowNum)
                SavePlaylist()
                RefreshListView()
            }
        }
    }
return


TrayPlayPause:
PlayPause()
return


TrayStop:
StopTrack()
return


TrayNext:
NextTrack()
return


TrackClicked:
    if (A_GuiEvent = "ColClick") {
        if (A_EventInfo = sortCol)
            sortDir := (sortDir = "Asc") ? "Desc" : "Asc"
        else {
            sortCol := A_EventInfo
            sortDir := "Asc"
        }

        Gui, ListView, TrackList
        LV_ModifyCol(sortCol, sortDir)

        row := LV_GetNext()
        if row {
            currentIndex := row
            LV_GetText(currentFile, row, 5)
        }
    }
    else if (A_GuiEvent = "DoubleClick") {
        row := A_EventInfo
        LV_GetText(filePath, row, 5)
        Log("DEBUG", "File path from LV_GetText: " . filePath)
        if FileExist(filePath) {
            PlayCurrent(filePath)
        } else {
            MsgBox, 16, Error, File not found:n%filePath%
            Log("ERROR", "Track clicked, file not found from LV_GetText: " . filePath)
        }
    }
return


ConvertToMP3(filePath) {
    SplitPath, filePath, name, dir, ext, name_no_ext

    ; Check if already mp3 (case-insensitive)
    StringLower, extLower, ext
    if (extLower = "mp3") {
        ShowCustomMsgBox("Info", "File is already an MP3. Conversion skipped.", 1000, 300)
        Log("INFO", "Convert to MP3 skipped because file is already an mp3: " . filePath)
        return
    }

    if (!dir) {
        MsgBox, 16, Error, Could not extract directory from:`n%filePath%
        ShowCustomMsgBox("Error", "Could not extract directory from:"`n%filePath%, 1000, 300)
        Log("ERROR", "Convert to MP3, Could not extract directory from: " . filePath)
        return
    }

    ffmpeg := A_ScriptDir . "\rpcl3_tools\ffmpeg.exe"
    if !FileExist(ffmpeg) {
        MsgBox, 16, Error, ffmpeg.exe not found in /rpcl3_tools
        Log("ERROR", "Convert to MP3, ffmpeg.exe not found in /rpcl3_tools")
        return
    }

    baseOutput := dir . "\" . name_no_ext
    outputFile := baseOutput . ".mp3"
    Log("DEBUG", "Convert to MP3, converting: " . filePath . " -> " . outputFile)

    if FileExist(outputFile) {
        choice := ConfirmFileExists(outputFile)
        if (choice = "override") {
            FileDelete, %outputFile%
            Log("DEBUG", "Conversion succeeded: " . outputFile)
        } else if (choice = "append") {
            Loop {
                newFile := baseOutput . " (copy" . (A_Index > 1 ? " " A_Index : "") . ").mp3"
                if !FileExist(newFile) {
                    outputFile := newFile
                    break
                }
            }
        } else { ; skip or GUI closed
            MsgBox, 48, Cancelled, Conversion cancelled by user.
            Log("INFO", "Convert to MP3, conversion cancelled by user.")
            return
        }
    }

    StringReplace, filePathEsc, filePath, ", "", All
    StringReplace, outputFileEsc, outputFile, ", "", All

    RunWait, %ComSpec% /c ""%ffmpeg%" -y -i "%filePathEsc%" -codec:a libmp3lame -qscale:a 2 "%outputFileEsc%"", , Hide

    if FileExist(outputFile)
        ShowCustomMsgBox("Success", "MP3 saved to:`n" . outputFile, 1000, 300)
    else {
        MsgBox, 16, Error, Conversion failed.
        Log("ERROR", "Convert to MP3, conversion failed.")
    }
}


ConfirmFileExists(file) {
; Decide where to show InputBox (e.g., to the right)
inputX := x + w + 10     ; 10 pixels to the right of the main window
inputY := y + 100        ; a bit lower than top
    static guiID := "ConfirmFileExistsGui"
    Gui, %guiID%:New, +AlwaysOnTop +Owner +ToolWindow, Confirm Action
    Gui, %guiID%:Font, s10 cRed q5
    Gui, %guiID%:Add, Text,, MP3 already exists:
    Gui, Font
    Gui, %guiID%:Font, s10 q5
    SplitPath, file, nameOnly
    Gui, %guiID%:Add, Text,, %nameOnly%
    Gui, Font
    Gui, %guiID%:Add, Button, gOverride w100 Default, Override
    Gui, %guiID%:Add, Button, gAppendCopy w100, Append Copy
    Gui, %guiID%:Add, Button, gSkip w100, Skip
    Gui, %guiID%:Show,, File Exists

    choice := ""
    Gui, %guiID%: +OwnDialogs
    Gui, %guiID%: +LastFound
    Loop {
        Sleep, 50
        if (choice != "")
            break
        Gui, %guiID%:Submit, NoHide
    }

    Return choice

    Override:
        choice := "override"
        Gui, %guiID%:Destroy
        Return
    AppendCopy:
        choice := "append"
        Gui, %guiID%:Destroy
        Return
    Skip:
        choice := "skip"
        Gui, %guiID%:Destroy
        Return
        Log("DEBUG", "Trying to play: " . filePath)
}


currentIndex := row


OnConvertToMP3:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 5) ; Get full path from hidden column 5
        Log("DEBUG", "Selected row: " . row . ", File path: " . filePath)
        Log("DEBUG", "filePath raw from LV = '" . filePath . "'")

        if FileExist(filePath)
            ConvertToMP3(filePath)
        else
            MsgBox, 48, "Warning, File does not exist:`n" filePath
               Log("ERROR", "On convert to MP3, file does not exist: " . filePath)
    } else {
        MsgBox, 48, Warning, No file selected.
        MsgBox
        ShowCustomMsgBox("Warning", "No file selected.", 1000, 300)
        Log("WARNING", "On convert to MP3, trying to play: " . track . filePath)
    }
return


RefreshListView()
; ─── end music player. ────────────────────────────────────────────────────────────────────
