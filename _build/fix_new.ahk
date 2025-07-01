I get this error:
Could not access audio devices. Make sure CABLE is installed.
It is definitely installed I can set it manually without problems.


I now have this, top of my script:
audioPrepared := false

My gui:
Gui, Add, Button, gSetAudio             x115 y350 w90 h51, SET AUDIO DEVICE

CheckCurrentAudioDevice() {
    RunWait, %ComSpec% /c nircmd.exe savefile "temp_audio.txt" getdefaultsounddevice, , Hide
    FileRead, currentDevice, temp_audio.txt
    FileDelete, temp_audio.txt
    return currentDevice
}


CheckAudioSystem() {
    RunWait, %ComSpec% /c nircmd.exe win show class Shell_TrayWnd, , Hide
    if ErrorLevel {
        MsgBox, 48, Warning, Could not access audio devices. Make sure CABLE is installed.
        return false
    }
    return true
}


SetAudio:
    if !FileExist(nircmd) {
        MsgBox, 16, Error, nircmd.exe not found!
        return
    }
    if !CheckAudioSystem() {
        return
    }
    if (!audioPrepared) {
        ; Prepare for recording
        RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Input" 1, , Hide
        Sleep, 200
        RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Output" 2, , Hide
        Sleep, 200

        ; Notify applications of audio device change
        DllCall("winmm.dll\waveOutMessage", "UInt", -1, "UInt", 0x3CD, "UPtr", 0, "UPtr", 0)

        ShowCustomMsgBox("Ready", "Recording devices set.`nLaunch RPCS3 and hit record.", 500, 300)
        Log("INFO", "Audio devices switched: Output = CABLE Input, Input = CABLE Output")
        audioPrepared := true

    } else {
        ; Revert to default
        RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
        Sleep, 200
        RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Microphone" 2, , Hide
        Sleep, 200

        ; Notify applications of audio device change
        DllCall("winmm.dll\waveOutMessage", "UInt", -1, "UInt", 0x3CD, "UPtr", 0, "UPtr", 0)

        CustomTrayTip("Audio output/input set to default.", 1)
        Log("INFO", "Audio devices reverted to default.")
        audioPrepared := false
    }
return
