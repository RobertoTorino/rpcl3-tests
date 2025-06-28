; Get the script directory and build the path to the screenshots folder
ScriptDir := A_ScriptDir
ScreenshotsFolder := ScriptDir . "\rpcl3_screenshots"

; Initialize variables
CurrentImageIndex := 1
ImageFiles := []

; Get all image files from the folder
Loop, %ScreenshotsFolder%\*.jpg
    ImageFiles.Push(A_LoopFileFullPath)
Loop, %ScreenshotsFolder%\*.png
    ImageFiles.Push(A_LoopFileFullPath)
Loop, %ScreenshotsFolder%\*.gif
    ImageFiles.Push(A_LoopFileFullPath)
Loop, %ScreenshotsFolder%\*.bmp
    ImageFiles.Push(A_LoopFileFullPath)

; Create the GUI
Gui, Add, Picture, x10 y10 w800 h600 vImageDisplay
Gui, Add, Button, x10 y620 w100 h30 gPrevImage, Previous
Gui, Add, Button, x120 y620 w100 h30 gNextImage, Next
Gui, Add, Text, x230 y625 w200 h20 vImageInfo
Gui, Show, w820 h660, Image Viewer

; Load the first image if available
if (ImageFiles.Length() > 0)
    GoSub, UpdateImage
else
    GuiControl,, ImageInfo, No images found in folder

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

UpdateImage:
CurrentImagePath := ImageFiles[CurrentImageIndex]
GuiControl,, ImageDisplay, %CurrentImagePath%
GuiControl,, ImageInfo, Image %CurrentImageIndex% of %ImageFiles.Length()
return

GuiClose:
ExitApp
