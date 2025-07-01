1. DllCall voor audio device change notification
Plaats dit direct na elke setdefaultsounddevice commando in je SetAudio functie:

ahk
SetAudio:
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found!
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
2. Error checking voor audio devices
Dit kan je op twee plekken plaatsen:

Optie A: Aan het begin van SetAudio functie
ahk
SetAudio:
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found!
    return
}

; Check of audio system toegankelijk is
RunWait, %ComSpec% /c nircmd.exe win show class Shell_TrayWnd, , Hide
if ErrorLevel {
    MsgBox, 48, Warning, Could not access audio devices. Make sure CABLE is installed.
    return
}

if (!audioPrepared) {
    ; rest van je code...
}
Optie B: Als aparte functie die je aanroept
ahk
; Plaats dit ergens bovenaan je script bij andere functies
CheckAudioSystem() {
    RunWait, %ComSpec% /c nircmd.exe win show class Shell_TrayWnd, , Hide
    if ErrorLevel {
        MsgBox, 48, Warning, Could not access audio devices. Make sure CABLE is installed.
        return false
    }
    return true
}

; Dan in SetAudio:
SetAudio:
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found!
    return
}

if !CheckAudioSystem() {
    return
}

; rest van je code...
3. CheckCurrentAudioDevice functie
Plaats deze functie bovenaan je script bij andere functies (niet binnen een label):

ahk
; Plaats dit bovenaan je script, na je variabelen maar voor je labels
CheckCurrentAudioDevice() {
    RunWait, %ComSpec% /c nircmd.exe savefile "temp_audio.txt" getdefaultsounddevice, , Hide
    FileRead, currentDevice, temp_audio.txt
    FileDelete, temp_audio.txt
    return currentDevice
}

; Je kunt deze functie dan gebruiken in SetAudio:
SetAudio:
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found!
    return
}

; Optioneel: check huidige device
currentDevice := CheckCurrentAudioDevice()
; MsgBox, Current device: %currentDevice%  ; Voor debugging

if (!audioPrepared) {
    ; rest van je code...
}
Complete gestructureerde layout:
ahk
; === VARIABELEN ===
audioPrepared := false
; andere variabelen...

; === FUNCTIES ===
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

; === LABELS ===
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

    ShowCustomMsgBox("Ready", "Recording devices set.", 500, 300)
    audioPrepared := true

} else {
    ; Revert to default
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Speakers" 1, , Hide
    Sleep, 200
    RunWait, %ComSpec% /c nircmd.exe setdefaultsounddevice "Microphone" 2, , Hide
    Sleep, 200

    ; Notify applications of audio device change
    DllCall("winmm.dll\waveOutMessage", "UInt", -1, "UInt", 0x3CD, "UPtr", 0, "UPtr", 0)

    CustomTrayTip("Audio devices reverted to default.", 1)
    audioPrepared := false
}
return
