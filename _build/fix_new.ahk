AudioCapture:

; Prompt the user to confirm audio device setup
MsgBox, 52, Warning, Did you already set the audio devices in RPCS3 (CABLE Input/Output)?
IfMsgBox No
{
    ; Kill RPCS3 and exit
    Process, Close, rpcs3.exe
    MsgBox, 48, Info, RPCS3 was closed because it must use the correct audio devices.
    return
}
; If user clicks Yes, continue recording setup

if !ProcessExist("rpcs3.exe") {
    CustomTrayTip("Cannot Record, RPCS3 is not running.", 1)
    return
}

    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Input" 1, , Hide
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Output" 1, , Hide

    CustomTrayTip("Audio output set to CABLE Input, audio input set to CABLE Output.", 1)
    Sleep, 1500

    if !recording
    {
        FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
        FileCreateDir, %A_ScriptDir%\rpcl3_recordings
        outFile := A_ScriptDir "\rpcl3_recordings\rpcs3_audio_" ts ".wav"
        audioDevice := "CABLE Output (VB-Audio Virtual Cable)"

        ffArgs := "-f dshow -i audio=""" audioDevice """ -acodec pcm_s16le -ar 48000 -ac 2 """ outFile """"
        Run, % ffmpegExe " " ffArgs, , , ffmpegPID

    if ffmpegPID {
        recording := true
        GuiControl, +cFFCC66, AudioCapture
    } else {
        MsgBox, 48, Error, Could not start FFmpeg.
        return
    }
}
else
{
    if ffmpegPID
        Process, Close, %ffmpegPID%
        ControlSend,, q, ahk_pid %ffmpegPID%.

    recording := false
    GuiControl, +c808080, AudioCapture
    CustomTrayTip("Recording Stopped, Saved to: " . outFile, 1)
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    CustomTrayTip("Audio output set to default", 1)

    ; Get bitrate
    ; Get file size (in bytes)
    FileGetSize, fileSizeBytes, %outFile%

    ; Use FFmpeg to get duration
    ffmpegOutput := A_ScriptDir . "\ffmpeg_output.txt"
    RunWait, %ComSpec% /c ""%ffmpegExe%" -i "%outFile%" 2> "%ffmpegOutput%"", , Hide

    ; Read duration from FFmpeg output
    FileRead, ffOut, %ffmpegOutput%
    RegExMatch(ffOut, "Duration: (\d+):(\d+):(\d+)", d)
    if (d1 != "" && d2 != "" && d3 != "") {
        totalSeconds := d1 * 3600 + d2 * 60 + d3
        bitrate := Round((fileSizeBytes * 8) / (totalSeconds * 1000)) . " kbps"
    } else {
        bitrate := "Unknown"
    }

    ; Optional: delete temporary ffmpeg output file
    FileDelete, %ffmpegOutput%

    Run, %FileCreateDir%
}
return


SetAudio:
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found!
    return
}

if (!audioPrepared) {
    ; Prepare for recording
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Input" 1, , Hide
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Output" 2, , Hide
    ShowCustomMsgBox("Ready", "Recording devices set.`nLaunch RPCS3 and hit record.", 500, 300)
    Log("INFO", "Audio devices switched: Output = CABLE Input, Input = CABLE Output")
    audioPrepared := true
} else {
    ; Revert to default
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Microphone" 2, , Hide
    CustomTrayTip("Audio output/input set to default.", 1)
    Log("INFO", "Audio devices reverted to default.")
    audioPrepared := false
}
return