#Persistent
#SingleInstance force
SetBatchLines, -1
SetTitleMatchMode, 2

; ═══════════════════════════════════════════════════════════════════════════════════════
; INITIALIZATION
; ═══════════════════════════════════════════════════════════════════════════════════════

; Global variables
playlist := []
currentIndex := 1
audioDir := A_ScriptDir . "\rpcl3_recordings"
playlistFile := audioDir . "\rpcl3_playlist.m3u"
sortCol := 1
sortDir := "Asc"
TestTrack := audioDir . "\rpcl3_test.mp3"
CurrentTrack := ""
CurrentTrackName := ""
MusicLogFile := A_ScriptDir . "\rpcl3_music_player.log"
MusicIniFile := A_ScriptDir . "\rpcl3_music_player.ini"
LastMetaFile := ""
ffmpeg := A_ScriptDir . "\tools\ffmpeg.exe"
player := ""
MyGuiHwnd := ""
isPlaying := false
isPaused := false
isShuffleMode := false

; Initialize application
Gosub, Init

; ═══════════════════════════════════════════════════════════════════════════════════════
; MAIN FUNCTIONS
; ═══════════════════════════════════════════════════════════════════════════════════════

Init:
    ; Check dependencies
    Gosub, CheckDependencies

    ; Ensure directories exist
    Gosub, EnsureDirExists

    ; Load settings
    Gosub, LoadSettings

    ; Create GUI
    Gosub, CreateGUI

    ; Load playlist
    Gosub, LoadPlaylist

    ; Start timer for track info updates
    SetTimer, UpdateTrackInfo, 500

    ; Show GUI
    title := "RPCL3 Music Player - " . Chr(169) . " " . A_YYYY . " - Philip"
    Gui, Show, w515 h500, %title%

    Log("INFO", "Music Player initialized successfully")
return

CheckDependencies:
    ; Check if ffmpeg exists
    if !FileExist(ffmpeg) {
        MsgBox, 48, Warning, ffmpeg.exe not found in /tools folder.`nMP3 conversion will not be available.
        Log("WARNING", "ffmpeg.exe not found: " . ffmpeg)
    }

    ; Test if test track exists
    if !FileExist(TestTrack) {
        Log("INFO", "No test track found")
    } else {
        playlist.Push(TestTrack)
        CurrentTrack := TestTrack
        CurrentTrackName := GetFileName(TestTrack)
    }
return

LoadSettings:
    ; Load sort preferences
    IniRead, sortCol, %MusicIniFile%, Sort, Column, 1
    IniRead, sortDir, %MusicIniFile%, Sort, Direction, Asc
    IniRead, currentIndex, %MusicIniFile%, State, CurrentIndex, 1

    Log("DEBUG", "Settings loaded: SortCol=" . sortCol . ", SortDir=" . sortDir)
return

CreateGUI:
    Gui, Add, ListView, vTrackList gTrackClicked x0 y0 w515 h227 AltSubmit Grid, Name|Size|Bitrate|Type|Duration
    Gui, ListView, TrackList
    LV_InsertCol(6, 0, "Full Path")
    LV_ModifyCol(6, 0)

    ; Control buttons
    Gui, Add, Text, gPlayPause x0 y228 w80 h25 Border +Center +0x200 vPlayPauseBtn, ▶ Play
    Gui, Add, Text, gStopTrack x80 y228 w60 h25 Border +Center +0x200, ⏹ Stop
    Gui, Add, Text, gPrevTrack x140 y228 w60 h25 Border +Center +0x200, ⏮ Prev
    Gui, Add, Text, gNextTrack x200 y228 w60 h25 Border +Center +0x200, ⏭ Next
    Gui, Add, Text, gShuffleMode x260 y228 w60 h25 Border +Center +0x200 vShuffleBtn, 🔀 Shuffle
    Gui, Add, Text, gViewLogs x415 y228 w50 h25 Border +Center +0x200, Logs
    Gui, Add, Text, gClearLogs x465 y228 w50 h25 Border +Center +0x200, Clear

    ; Volume control
    Gui, Add, Text, x0 y260 w40 h20, Volume:
    Gui, Add, Slider, vVolumeSlider gAdjustVolume x40 y260 w200 h20 Range0-100 TickInterval10, 50
    Gui, Add, Text, vVolumeDisplay x245 y260 w30 h20, 50`%

    ; Progress bar
    Gui, Add, Text, x0 y285 w40 h20, Progress:
    Gui, Add, Slider, vSeekSlider gSeekTrack x40 y285 w475 h20 Range0-100, 0

    ; Windows Media Player control
    Gui, Add, ActiveX, x0 y310 w515 h120 vWMP, WMPlayer.OCX
    player := WMP
    WMP.uiMode := "none"
    WMP.Enabled := true
    WMP.settings.volume := 50

    ; Current track display
    Gui, Add, Text, vCurrentTrack x2 y435 w350 h20 +Left +0x200, Now playing: (None)
    Gui, Add, Text, vTimeDisplay x2 y455 w150 h20 +Left, 00:00 / 00:00
    Gui, Add, Text, vShuffleStatus x300 y455 w100 h20 +Left,

    ; Status bar
    Gui, Add, StatusBar, vStatusBar
    SB_SetText("Ready")

    ; Context menu
    Gosub, CreateContextMenu

    ; Get GUI handle
    Gui, +LastFound +HwndMyGuiHwnd

    Log("DEBUG", "GUI created successfully")
return

CreateContextMenu:
    Menu, TrackMenu, Add, ▶ Play Track, OnPlay
    Menu, TrackMenu, Add
    Menu, TrackMenu, Add, 🔄 Convert to MP3, OnConvertToMP3
    Menu, TrackMenu, Add, 📁 Show in Explorer, OnShowInExplorer
    Menu, TrackMenu, Add, 📋 Copy File Path, OnCopyPath
    Menu, TrackMenu, Add
    Menu, TrackMenu, Add, ✏ Rename File, OnRenameFile
    Menu, TrackMenu, Add, 🗑 Delete File, OnDeleteFile
    Menu, TrackMenu, Add
    Menu, TrackMenu, Add, ℹ Track Info, OnTrackInfo
return

; ═══════════════════════════════════════════════════════════════════════════════════════
; PLAYLIST MANAGEMENT
; ═══════════════════════════════════════════════════════════════════════════════════════

LoadPlaylist:
    playlist := []

    ; Load audio files from directory
    Loop, Files, %audioDir%\*.*, R
    {
        SplitPath, A_LoopFileFullPath,,, ext
        StringLower, ext, ext
        if (ext = "mp3" || ext = "wav" || ext = "flac" || ext = "m4a" || ext = "wma")
            playlist.Push(A_LoopFileFullPath)
    }

    ; Sort playlist
    Gosub, SortPlaylist

    ; Refresh display
    Gosub, RefreshListView

    ; Update status
    SB_SetText("Loaded " . playlist.Length() . " audio files")
    Log("INFO", "Playlist loaded: " . playlist.Length() . " files")
return

SortPlaylist:
    ; Simple alphabetical sort by filename
    if (playlist.Length() > 1) {
        Loop, % playlist.Length() - 1 {
            outerLoop := A_Index
            Loop, % playlist.Length() - outerLoop {
                innerLoop := A_Index
                SplitPath, % playlist[innerLoop], name1
                SplitPath, % playlist[innerLoop + 1], name2
                if (name1 > name2) {
                    temp := playlist[innerLoop]
                    playlist[innerLoop] := playlist[innerLoop + 1]
                    playlist[innerLoop + 1] := temp
                }
            }
        }
    }
return

RefreshListView:
    Gui, ListView, TrackList
    LV_Delete()

    if (playlist.Length() = 0) {
        LV_Add("", "No audio files found", "", "", "", "")
        return
    }

    for index, path in playlist {
        if FileExist(path) {
            SplitPath, path, name, dir, ext
            FileGetSize, sizeBytes, %path%
            sizeMB := Round(sizeBytes / 1048576, 2) . " MB"
            bitrate := GetBitrate(path)
            duration := GetDuration(path)

            row := LV_Add("", name, sizeMB, bitrate, ext, duration)
            LV_Modify(row, "Col6", path)
        }
    }

    ; Auto-size columns
    LV_ModifyCol()

    ; Highlight current track
    Gosub, HighlightCurrentTrack
return

HighlightCurrentTrack:
    ; Reset all rows
    Loop, % LV_GetCount()
        LV_Modify(A_Index, "")

    ; Highlight current track
    if (currentIndex > 0 && currentIndex <= LV_GetCount())
        LV_Modify(currentIndex, "cBlue")
return

; ═══════════════════════════════════════════════════════════════════════════════════════
; PLAYBACK CONTROL
; ═══════════════════════════════════════════════════════════════════════════════════════

PlayCurrent:
    if (currentIndex < 1 || currentIndex > playlist.Length()) {
        Log("ERROR", "Invalid currentIndex: " . currentIndex)
        return
    }

    filePath := playlist[currentIndex]

    if !FileExist(filePath) {
        MsgBox, 16, Error, File not found:`n%filePath%
        Log("ERROR", "File not found: " . filePath)
        return
    }

    ; Update current track info
    CurrentTrack := GetFileName(filePath)
    GuiControl,, CurrentTrack, Now Playing: %CurrentTrack%

    ; Update player
    player.URL := filePath
    player.controls.play()

    isPlaying := true
    isPaused := false

    ; Update button text
    GuiControl,, PlayPauseBtn, ⏸ Pause

    ; Highlight in list
    Gosub, HighlightCurrentTrack

    ; Update status
    SB_SetText("Playing: " . CurrentTrack)

    Log("INFO", "Playing: " . filePath)
return

PlayPause:
    if (player.playState = 3) {
        player.controls.pause()
        isPaused := true
        isPlaying := false
        GuiControl,, PlayPauseBtn, ▶ Play
        SB_SetText("Paused: " . CurrentTrack)
        Log("INFO", "Playback paused")
    } else {
        if (isPaused) {
            player.controls.play()
        } else {
            if (playlist.Length() > 0) {
                if (currentIndex < 1 || currentIndex > playlist.Length())
                    currentIndex := 1
                Gosub, PlayCurrent
            }
        }
        isPaused := false
        isPlaying := true
        GuiControl,, PlayPauseBtn, ⏸ Pause
        SB_SetText("Playing: " . CurrentTrack)
        Log("INFO", "Playback resumed/started")
    }
return

StopTrack:
    player.controls.stop()
    isPlaying := false
    isPaused := false

    GuiControl,, PlayPauseBtn, ▶ Play
    GuiControl,, CurrentTrack, Stopped
    GuiControl,, TimeDisplay, 00:00 / 00:00
    GuiControl,, SeekSlider, 0

    SB_SetText("Stopped")
    Log("INFO", "Playback stopped")
return

NextTrack:
    if (playlist.Length() = 0)
        return

    if (isShuffleMode) {
        Random, currentIndex, 1, % playlist.Length()
    } else {
        currentIndex++
        if (currentIndex > playlist.Length())
            currentIndex := 1
    }

    Gosub, PlayCurrent

    ; Update ListView selection
    Gui, ListView, TrackList
    Loop, % LV_GetCount()
        LV_Modify(A_Index, "-Select")
    LV_Modify(currentIndex, "Select Focus")
return

PrevTrack:
    if (playlist.Length() = 0)
        return

    if (isShuffleMode) {
        Random, currentIndex, 1, % playlist.Length()
    } else {
        currentIndex--
        if (currentIndex < 1)
            currentIndex := playlist.Length()
    }

    Gosub, PlayCurrent

    ; Update ListView selection
    Gui, ListView, TrackList
    Loop, % LV_GetCount()
        LV_Modify(A_Index, "-Select")
    LV_Modify(currentIndex, "Select Focus")
return

ShuffleMode:
    isShuffleMode := !isShuffleMode

    if (isShuffleMode) {
        GuiControl,, ShuffleBtn, 🔀 ON
        GuiControl,, ShuffleStatus, Shuffle: ON
        Log("INFO", "Shuffle mode enabled")
    } else {
        GuiControl,, ShuffleBtn, 🔀 Shuffle
        GuiControl,, ShuffleStatus, Shuffle: OFF
        Log("INFO", "Shuffle mode disabled")
    }

    SetTimer, ClearShuffleStatus, 2000
return

ClearShuffleStatus:
    if (!isShuffleMode)
        GuiControl,, ShuffleStatus,
    SetTimer, ClearShuffleStatus, Off
return

; ═══════════════════════════════════════════════════════════════════════════════════════
; UTILITY FUNCTIONS
; ═══════════════════════════════════════════════════════════════════════════════════════

GetBitrate(file) {
    try {
        media := player.newMedia(file)
        bitrate := media.getItemInfo("Bitrate")
        return bitrate ? bitrate . " kbps" : "?"
    } catch e {
        return "?"
    }
}

GetDuration(file) {
    try {
        media := player.newMedia(file)
        duration := media.duration
        return duration ? FormatTime(Round(duration)) : "?"
    } catch e {
        return "?"
    }
}

GetFileName(path) {
    SplitPath, path,,, ext, name_no_ext
    return name_no_ext . "." . ext
}

FormatTime(seconds) {
    minutes := seconds // 60
    seconds := Mod(seconds, 60)
    return Format("{:02d}:{:02d}", minutes, seconds)
}

EnsureDirExists:
    if !FileExist(audioDir)
        FileCreateDir, %audioDir%
return

; ═══════════════════════════════════════════════════════════════════════════════════════
; EVENT HANDLERS
; ═══════════════════════════════════════════════════════════════════════════════════════

TrackClicked:
    if (A_GuiEvent = "DoubleClick") {
        row := A_EventInfo
        if (row > 0) {
            LV_GetText(filePath, row, 6)
            if FileExist(filePath) {
                currentIndex := row
                Gosub, PlayCurrent
            }
        }
    }
    else if (A_GuiEvent = "ColClick") {
        ; Handle column sorting
        if (A_EventInfo = sortCol)
            sortDir := (sortDir = "Asc") ? "Desc" : "Asc"
        else {
            sortCol := A_EventInfo
            sortDir := "Asc"
        }

        ; Save sort preferences
        IniWrite, %sortCol%, %MusicIniFile%, Sort, Column
        IniWrite, %sortDir%, %MusicIniFile%, Sort, Direction

        ; Apply sort
        Gosub, LoadPlaylist
    }
return

GuiContextMenu:
    if (A_GuiControl = "TrackList") {
        Menu, TrackMenu, Show
    }
return

AdjustVolume:
    GuiControlGet, VolumeSlider
    player.settings.volume := VolumeSlider
    GuiControl,, VolumeDisplay, %VolumeSlider%`%
    Log("DEBUG", "Volume adjusted to: " . VolumeSlider)
return

SeekTrack:
    GuiControlGet, SeekSlider
    if (player.currentMedia) {
        dur := player.currentMedia.duration
        if (dur > 0) {
            newPos := (SeekSlider / 100.0) * dur
            player.controls.currentPosition := newPos
        }
    }
return

UpdateTrackInfo:
    if (player.currentMedia && isPlaying) {
        pos := Round(player.controls.currentPosition)
        dur := Round(player.currentMedia.duration)

        if (dur > 0) {
            timeStr := FormatTime(pos) . " / " . FormatTime(dur)
            GuiControl,, TimeDisplay, %timeStr%

            progress := Round((pos / dur) * 100)
            GuiControl,, SeekSlider, %progress%

            ; Check if track ended
            if (pos >= dur - 1) {
                SetTimer, CheckTrackEnd, 1000
            }
        }
    }
return

CheckTrackEnd:
    if (player.playState = 1) {  ; Stopped state
        SetTimer, CheckTrackEnd, Off
        Gosub, NextTrack
    }
return

GuiDropFiles:
    Loop, Parse, A_GuiEvent, `n
    {
        file := A_LoopField
        SplitPath, file,,, ext
        StringLower, ext, ext
        if (ext = "mp3" || ext = "wav" || ext = "flac" || ext = "m4a" || ext = "wma") {
            ; Copy file to audio directory
            SplitPath, file, fileName
            newPath := audioDir . "\" . fileName
            FileCopy, %file%, %newPath%
            Log("INFO", "File added: " . newPath)
        }
    }
    Gosub, LoadPlaylist
return

ViewLogs:
    if FileExist(MusicLogFile)
        Run, notepad.exe "%MusicLogFile%"
    else
        MsgBox, 48, Info, No log file found.
return

ClearLogs:
    FileDelete, %MusicLogFile%
    SB_SetText("Log file cleared")
    Log("INFO", "Log file cleared")
return

GuiClose:
    ; Save current state
    IniWrite, %currentIndex%, %MusicIniFile%, State, CurrentIndex
    Log("INFO", "Music Player shutting down")
    ExitApp

; ═══════════════════════════════════════════════════════════════════════════════════════
; CONTEXT MENU HANDLERS
; ═══════════════════════════════════════════════════════════════════════════════════════

OnPlay:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 6)
        currentIndex := row
        Gosub, PlayCurrent
    }
return

OnConvertToMP3:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 6)
        if FileExist(filePath)
            Gosub, ConvertToMP3
    }
return

OnShowInExplorer:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 6)
        Run, explorer.exe /select`, "%filePath%"
    }
return

OnCopyPath:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 6)
        Clipboard := filePath
        TrayTip, Copied, File path copied to clipboard., 2, 1
    }
return

OnRenameFile:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 6)
        SplitPath, filePath, name, dir, ext, nameNoExt

        InputBox, newName, Rename File, Enter new filename (without extension):, , 300, 130, , , , , %nameNoExt%
        if !ErrorLevel {
            newPath := dir . "\" . newName . "." . ext
            FileMove, %filePath%, %newPath%
            if !ErrorLevel {
                Gosub, LoadPlaylist
                Log("INFO", "File renamed: " . filePath . " -> " . newPath)
            }
        }
    }
return

OnDeleteFile:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 6)

        MsgBox, 52, Confirm Delete, Are you sure you want to delete this file?`n`n%filePath%
        IfMsgBox Yes
        {
            FileRecycle, %filePath%
            Gosub, LoadPlaylist
            Log("INFO", "File deleted: " . filePath)
        }
    }
return

OnTrackInfo:
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (row) {
        LV_GetText(filePath, row, 6)
        if FileExist(filePath) {
            FileGetSize, size, %filePath%
            FileGetTime, modified, %filePath%

            info := "File: " . GetFileName(filePath) . "`n"
            info .= "Path: " . filePath . "`n"
            info .= "Size: " . Round(size/1024/1024, 2) . " MB`n"
            info .= "Modified: " . modified . "`n"
            info .= "Bitrate: " . GetBitrate(filePath) . "`n"
            info .= "Duration: " . GetDuration(filePath)

            MsgBox, 64, Track Information, %info%
        }
    }
return

; ═══════════════════════════════════════════════════════════════════════════════════════
; CONVERSION FUNCTIONS
; ═══════════════════════════════════════════════════════════════════════════════════════

ConvertToMP3:
    if !FileExist(ffmpeg) {
        MsgBox, 16, Error, ffmpeg.exe not found in /tools folder.
        return
    }

    ; Get the selected file path
    Gui, ListView, TrackList
    row := LV_GetNext()
    if (!row) return

    LV_GetText(filePath, row, 6)
    SplitPath, filePath, name, dir, ext, name_no_ext

    ; Check if already MP3
    StringLower, extLower, ext
    if (extLower = "mp3") {
        MsgBox, 64, Info, File is already an MP3.
        return
    }

    outputFile := dir . "\" . name_no_ext . ".mp3"

    ; Check if output file exists
    if FileExist(outputFile) {
        MsgBox, 52, File Exists, Output file already exists. Overwrite?
        IfMsgBox No
            return
        FileDelete, %outputFile%
    }

    ; Show progress
    SB_SetText("Converting to MP3...")

    ; Convert
    RunWait, %ComSpec% /c ""%ffmpeg%" -i "%filePath%" -codec:a libmp3lame -b:a 192k "%outputFile%"", , Hide

    if FileExist(outputFile) {
        SB_SetText("Conversion successful!")
        Gosub, LoadPlaylist
        Log("INFO", "Converted: " . filePath . " -> " . outputFile)
    } else {
        SB_SetText("Conversion failed!")
        Log("ERROR", "Conversion failed: " . filePath)
    }

    SetTimer, ClearStatus, 3000
return

ClearStatus:
    SB_SetText("Ready")
    SetTimer, ClearStatus, Off
return

; ═══════════════════════════════════════════════════════════════════════════════════════
; LOGGING FUNCTION
; ═══════════════════════════════════════════════════════════════════════════════════════

Log(level, msg) {
    static inLog := false

    if (inLog) return
    inLog := true

    try {
        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        logEntry := "[" . timestamp . "] [" . level . "] " . msg . "`n"
        FileAppend, %logEntry%, %MusicLogFile%
    } catch e {
        SB_SetText("Log error: " . e.message)
    }

    inLog := false
}
