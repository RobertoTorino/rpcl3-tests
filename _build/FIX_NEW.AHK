; Get the script directory and build the path to the screenshots folder
ScriptDir := A_ScriptDir
ScreenshotsFolder := ScriptDir . "\rpcl3_screenshots"

; Initialize variables
CurrentImageIndex := 1
ImageFiles := []

; Set initial GUI dimensions (normal window size)
GuiWidth := 820
GuiHeight := 660
ImageWidth := GuiWidth - 20
ImageHeight := 600  ; Fixed height as in original

; Create the GUI - normal size with MaximizeBox
Gui, +Resize +MaximizeBox
Gui, Add, Picture, x10 y10 w%ImageWidth% h%ImageHeight% vImageDisplay 0x100
Gui, Add, Button, x10 y620 w100 h30 gPrevImage, Previous
Gui, Add, Button, x120 y620 w100 h30 gNextImage, Next
Gui, Add, Button, x230 y620 w100 h30 gBrowseFolder, Browse Folder
Gui, Add, Text, x340 y625 w200 h20 vImageInfo
Gui, Add, Text, x550 y625 w300 h20 vFolderPath, Folder: %ScreenshotsFolder%

; Show GUI at normal size
Gui, Show, w%GuiWidth% h%GuiHeight%, Image Viewer

; Load images from the initial folder
GoSub, LoadImages

return

LoadImages:
; Clear the current image list
ImageFiles := []

; Check if folder exists
IfNotExist, %ScreenshotsFolder%
{
    GuiControl,, ImageInfo, Folder does not exist
    GuiControl,, ImageDisplay,  ; Clear the image
    return
}

; Get all image files from the folder
Loop, %ScreenshotsFolder%\*.jpg
    ImageFiles.Push(A_LoopFileFullPath)
Loop, %ScreenshotsFolder%\*.jpeg
    ImageFiles.Push(A_LoopFileFullPath)
Loop, %ScreenshotsFolder%\*.png
    ImageFiles.Push(A_LoopFileFullPath)
Loop, %ScreenshotsFolder%\*.gif
    ImageFiles.Push(A_LoopFileFullPath)
Loop, %ScreenshotsFolder%\*.bmp
    ImageFiles.Push(A_LoopFileFullPath)

; Reset to first image
CurrentImageIndex := 1

; Load the first image if available
if (ImageFiles.Length() > 0) {
    GoSub, UpdateImage
} else {
    GuiControl,, ImageInfo, No images found in folder
    GuiControl,, ImageDisplay,  ; Clear the image
}
return

PrevImage:
if (ImageFiles.Length() > 0) {
    CurrentImageIndex--
    if (CurrentImageIndex < 1)
        CurrentImageIndex := ImageFiles.Length()
    GoSub, UpdateImage
}
return

NextImage:
if (ImageFiles.Length() > 0) {
    CurrentImageIndex++
    if (CurrentImageIndex > ImageFiles.Length())
        CurrentImageIndex := 1
    GoSub, UpdateImage
}
return

BrowseFolder:
; Open folder browser dialog
FileSelectFolder, SelectedFolder, *%ScreenshotsFolder%, 3, Select Image Folder
if SelectedFolder {
    ScreenshotsFolder := SelectedFolder
    GuiControl,, FolderPath, Folder: %ScreenshotsFolder%
    GoSub, LoadImages
}
return

UpdateImage:
if (ImageFiles.Length() > 0) {
    CurrentImagePath := ImageFiles[CurrentImageIndex]

    ; Get current image control dimensions
    GuiControlGet, ImagePos, Pos, ImageDisplay
    GuiControl,, ImageDisplay, *w%ImagePosW% *h%ImagePosH% %CurrentImagePath%
    GuiControl,, ImageInfo, Image %CurrentImageIndex% of %ImageFiles.Length%

    ; Extract just the filename for display
    SplitPath, CurrentImagePath, FileName
    WinSetTitle, Image Viewer, , Image Viewer - %FileName%
}
return

; Handle window resize (when maximized or manually resized)
GuiSize:
if A_EventInfo = 1  ; Minimized
    return

; Recalculate dimensions based on new window size
NewGuiWidth := A_GuiWidth
NewGuiHeight := A_GuiHeight
NewImageWidth := NewGuiWidth - 20
NewImageHeight := NewGuiHeight - 80  ; Reserve space for buttons

; Resize controls
GuiControl, Move, ImageDisplay, w%NewImageWidth% h%NewImageHeight%
GuiControl, Move, Previous, y%NewGuiHeight%-60
GuiControl, Move, Next, y%NewGuiHeight%-60
GuiControl, Move, Browse Folder, y%NewGuiHeight%-60
GuiControl, Move, ImageInfo, y%NewGuiHeight%-55
GuiControl, Move, FolderPath, y%NewGuiHeight%-55

; Update the image with new dimensions if an image is loaded
if (ImageFiles.Length() > 0 && CurrentImageIndex > 0) {
    CurrentImagePath := ImageFiles[CurrentImageIndex]
    GuiControl,, ImageDisplay, *w%NewImageWidth% *h%NewImageHeight% %CurrentImagePath%
}
return

; Add keyboard shortcuts
F1::GoSub, PrevImage
F2::GoSub, NextImage
Left::GoSub, PrevImage
Right::GoSub, NextImage
Ctrl & o::GoSub, BrowseFolder

GuiClose:
ExitApp
