ffmpeg.exe not found in /rpcl3_tools folder.
MP3 conversion will not be available.

ffmpeg.exe not found in /rpcl3_tools folder.
MP3 conversion will not be available.

Error:  The same variable cannot be used for more than one control.
Specifically: vTrackList gTrackClicked x0 y0 w515 h227 AltSubmit Grid
	Line#
	083: }
	084: Return
	088: IniRead,sortCol,%MusicIniFile%,Sort,Column,1
	089: IniRead,sortDir,%MusicIniFile%,Sort,Direction,Asc
	090: IniRead,currentIndex,%MusicIniFile%,State,CurrentIndex,1
	092: Log("DEBUG", "Settings loaded: SortCol=" . sortCol . ", SortDir=" . sortDir)
	093: Return
--->	096: Gui,Add,ListView,vTrackList gTrackClicked x0 y0 w515 h227 AltSubmit Grid,Name|Size|Bitrate|Type|Duration
	097: Gui,ListView,TrackList
	098: LV_InsertCol(6, 0, "Full Path")
	099: LV_ModifyCol(6, 0)
	102: Gui,Add,Text,gPlayPause x0 y228 w80 h25 Border +Center +0x200 vPlayPauseBtn,Play
	103: Gui,Add,Text,gStopTrack x80 y228 w60 h25 Border +Center +0x200,Stop
	104: Gui,Add,Text,gPrevTrack x140 y228 w60 h25 Border +Center +0x200,Prev
	105: Gui,Add,Text,gNextTrack x200 y228 w60 h25 Border +Center +0x200,Next

