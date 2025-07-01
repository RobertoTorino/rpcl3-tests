---------------------------
rpcl3.ahk
---------------------------
Error:  A control's variable must be global or static.

Specifically: vMusicPlayer_TrackList

	Line#
	3804: MusicPlayer_playlist.Push(MusicPlayer_TestTrack)
	3806: SetTimer,MusicPlayer_UpdateTrackInfo,500
	3807: }
	3809: {
	3815: Gui,MusicPlayer:New,+AlwaysOnTop +LabelMusicPlayer_ +HwndMusicPlayerHwnd +Resize
	3816: Gui,MusicPlayer:Font,s10 q5,Segoe UI
	3817: Gui,MusicPlayer:Margin,15,15
--->	3820: Gui,MusicPlayer:Add,ListView,vMusicPlayer_TrackList,Name|Size|Bitrate|Type
	3821: Gui,MusicPlayer:ListView,MusicPlayer_TrackList
	3822: LV_InsertCol(5, 0, "Full Path")
	3823: LV_ModifyCol(5, 0)
	3826: Gui,MusicPlayer:Add,Progress,x0 y0 w515 h1 0x10 Disabled
	3827: Gui,MusicPlayer:Font,s9 q5,Segoe UI Emoji
	3828: Gui,MusicPlayer:Add,Progress,x0 y227 w515 h1 0x10 Disabled
	3829: Gui,MusicPlayer:Add,Text,gMusicPlayer_PlayPause x0 y228 w100 h23 Border +Center +0x200,Play/Pause

The current thread will exit.
---------------------------
OK
---------------------------
