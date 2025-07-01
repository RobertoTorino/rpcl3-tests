ShowMusicPlayer:
    MusicPlayer_Init()
    MusicPlayer_CreateGUI()
    MusicPlayer_LoadPlaylist()
    Gui, MusicPlayer:Show, w515 h482, RPCL3 Music Player
return

MusicPlayer_Init() {
    global
    MusicPlayer_playlist := []
    MusicPlayer_currentIndex := 1
    MusicPlayer_audioDir := A_ScriptDir . "\rpcl3_recordings"
    MusicPlayer_playlistFile := MusicPlayer_audioDir . "\rpcl3_playlist.m3u"
    ; ... other initialization

    SetTimer, MusicPlayer_UpdateTrackInfo, 500
}

MusicPlayer_CreateGUI() {
    Gui, MusicPlayer:New, +AlwaysOnTop +LabelMusicPlayer_ +HwndMusicPlayerHwnd
    Gui, MusicPlayer:Font, s10 q5, Segoe UI

    ; Rest of your GUI creation code...
    ; Make sure all controls have unique names if needed

    ; Create context menu with unique name
    Menu, MusicPlayer_TrackMenu, Add, Convert to MP3, MusicPlayer_OnConvertToMP3
    Menu, MusicPlayer_TrackMenu, Add, Delete File, MusicPlayer_OnDeleteFile
    ; ... other menu items
}

; All your event handlers with proper prefixes
MusicPlayer_GuiClose:
    SetTimer, MusicPlayer_UpdateTrackInfo, Off
    Gui, MusicPlayer:Destroy
return

MusicPlayer_GuiContextMenu:
    if (A_GuiControl = "TrackList") {
        Menu, MusicPlayer_TrackMenu, Show
    }
return

MusicPlayer_OnConvertToMP3:
    ; Your existing code but make sure to reference MusicPlayer GUI
    Gui, MusicPlayer:ListView, TrackList
    ; ... rest of your existing code
return

MusicPlayer_UpdateTrackInfo:
    Gui, MusicPlayer:Default
    ; Your existing timer code
return
