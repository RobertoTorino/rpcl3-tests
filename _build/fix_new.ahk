I have some strange behavior in my AHK v1 script, when I searched the game I get a result.
Wwhen I click on the line with the result a picture is shown.
But not in the full dimension I provided, it is smaller than the given size.
Then when I click on an empty line and then click again on the search result the picture is biggers and fits in the povide space.
As it should be in the first place.


Gui, Add, Picture, vGameIcon            x470 y107 w600 h400 gShowLargeImage

ListViewClick:
    selectedRow := LV_GetNext()
    if (selectedRow > 0) {
        ShowGameIcon(selectedRow)
        ;UpdateFavoriteButton(selectedRow)
    } else {
        ClearImagePreview()
    }
return


ShowGameIcon(rowIndex) {
    if (G_IconPaths.MaxIndex() < rowIndex) {
        GuiControl,, GameIcon,
        GuiControl,, ImageStatus, No data for this row
        return
    }

    iconPath := G_IconPaths[rowIndex]

    if (iconPath != "" && FileExist(iconPath)) {
        GuiControl,, GameIcon, %iconPath%
        GuiControl,, ImageStatus, Click icon for larger view
        CurrentSelectedRow := rowIndex
    } else {
        GuiControl,, GameIcon,
        if (iconPath != "") {
            GuiControl,, ImageStatus, Icon not found: %iconPath%
        } else {
            GuiControl,, ImageStatus, No icon path available
        }
        CurrentSelectedRow := rowIndex
    }
}

ShowLargeImage:
    if (CurrentSelectedRow <= 0 || G_PicPaths.MaxIndex() < CurrentSelectedRow)
        return

    picPath := G_PicPaths[CurrentSelectedRow]

    if (picPath = "" || !FileExist(picPath)) {
        if (picPath != "") {
            MsgBox, 48, Image Not Found, Large image file not found:`n%picPath%
        } else {
            MsgBox, 48, Image Not Found, No large image path available for this game.
        }
        return
    }

    Gui, 2: New, +Resize +MaximizeBox, Game Image
    Gui, 2: Add, Picture, x10 y10, %picPath%
    Gui, 2: Show, w600 h400
return