Verbeterde versie van je SetAudio functie:
ahk
; Voeg dit toe aan het begin van je script
audioPrepared := false

SetAudio:
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found!
    return
}

if (!audioPrepared) {
    ; Prepare for recording - wacht even tussen commando's
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Input" 1, , Hide
    Sleep, 200
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "CABLE Output" 2, , Hide
    Sleep, 200

    ; Check of RPCS3 draait en waarschuw gebruiker
    if ProcessExist("rpcs3.exe") {
        MsgBox, 68, Audio Switch, Audio devices set to CABLE.`n`nRPCS3 is running. You may need to restart RPCS3 or change audio settings manually in RPCS3 for it to detect the new devices.`n`nDo you want to continue?
        IfMsgBox No
        {
            ; Revert audio settings
            RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
            Sleep, 200
            RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Microphone" 2, , Hide
            return
        }
    }

    ShowCustomMsgBox("Ready", "Recording devices set.`nOutput: CABLE Input`nInput: CABLE Output", 500, 300)
    Log("INFO", "Audio devices switched: Output = CABLE Input, Input = CABLE Output")
    audioPrepared := true

} else {
    ; Revert to default
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    Sleep, 200
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Microphone" 2, , Hide
    Sleep, 200

    CustomTrayTip("Audio devices reverted to default.", 1)
    Log("INFO", "Audio devices reverted to default: Output = Speakers, Input = Microphone")
    audioPrepared := false
}
return
Voor RPCS3 audio device detectie:
Je hebt een paar opties:

Optie 1: Restart RPCS3 automatisch
ahk
SetAudioWithRestart:
if ProcessExist("rpcs3.exe") {
    MsgBox, 68, Restart Required, RPCS3 needs to restart to detect new audio devices.`n`nRestart RPCS3 now?
    IfMsgBox Yes
    {
        Process, Close, rpcs3.exe
        ; Wacht tot proces volledig afgesloten is
        while ProcessExist("rpcs3.exe") {
            Sleep, 100
        }
        Sleep, 1000

        ; Verander audio devices
        Gosub, SetAudio

        ; Start RPCS3 opnieuw (pas het pad aan naar jouw RPCS3 locatie)
        Run, "C:\Path\To\Your\rpcs3.exe"
    }
} else {
    Gosub, SetAudio
}
return
Optie 2: Verstuur een Windows audio device change notification
ahk
; Voeg dit toe na het wisselen van audio devices
DllCall("winmm.dll\waveOutMessage", "UInt", -1, "UInt", 0x3CD, "UPtr", 0, "UPtr", 0)
Extra verbeteringen:
Voeg error checking toe:
ahk
; Check of de audio devices bestaan voordat je ze instelt
RunWait, %ComSpec% /c nircmd.exe win show class Shell_TrayWnd, , Hide
if ErrorLevel {
    MsgBox, 48, Warning, Could not access audio devices. Make sure CABLE is installed.
    return
}
Voeg een helper functie toe om te checken welke audio device actief is:
ahk
CheckCurrentAudioDevice() {
    RunWait, %ComSpec% /c nircmd.exe savefile "temp_audio.txt" getdefaultsounddevice, , Hide
    FileRead, currentDevice, temp_audio.txt
    FileDelete, temp_audio.txt
    return currentDevice
}
Het belangrijkste probleem is dat audioPrepared niet geïnitialiseerd wordt. Zorg ervoor dat je audioPrepared := false toevoegt aan het begin van je script, dan zou de toggle-functionaliteit correct moeten werken.
