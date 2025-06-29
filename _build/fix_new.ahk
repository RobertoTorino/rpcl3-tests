Oplossing 1: Picture control verversen
Voeg deze regel toe na het instellen van de nieuwe afbeelding:

ShowGameIcon(rowIndex) {
    if (G_IconPaths.MaxIndex() < rowIndex) {
        GuiControl,, GameIcon,
        GuiControl,, ImageStatus, No data for this row
        return
    }

    iconPath := G_IconPaths[rowIndex]

    if (iconPath != "" && FileExist(iconPath)) {
        GuiControl,, GameIcon, %iconPath%
        GuiControl, Move, GameIcon, x470 y107 w600 h400  ; Forceer de grootte opnieuw
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
Oplossing 2: Lege afbeelding eerst instellen
ShowGameIcon(rowIndex) {
    if (G_IconPaths.MaxIndex() < rowIndex) {
        GuiControl,, GameIcon,
        GuiControl,, ImageStatus, No data for this row
        return
    }

    iconPath := G_IconPaths[rowIndex]

    if (iconPath != "" && FileExist(iconPath)) {
        GuiControl,, GameIcon,  ; Eerst leegmaken
        Sleep, 10  ; Korte pauze
        GuiControl,, GameIcon, %iconPath%  ; Dan de nieuwe afbeelding
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
Oplossing 3: Picture control met schaaloptie
Wijzig je GUI definitie om schaling te forceren:

Gui, Add, Picture, vGameIcon x470 y107 w600 h400 gShowLargeImage 0x40000000
De 0x40000000 flag forceert het picture control om afbeeldingen te schalen naar de opgegeven dimensies.

Oplossing 4: GUI refresh na afbeelding instellen
ShowGameIcon(rowIndex) {
    ; ... je bestaande code ...

    if (iconPath != "" && FileExist(iconPath)) {
        GuiControl,, GameIcon, %iconPath%
        Gui, Show  ; GUI refreshen
        GuiControl,, ImageStatus, Click icon for larger view
        CurrentSelectedRow := rowIndex
    }
    ; ... rest van je code ...
}
Probeer eerst Oplossing 1 - dat lost meestal dit soort schaalproblemen op. Als dat niet werkt, kun je Oplossing 3 proberen met de schaalflag bij de GUI definitie.

You
I don't need the option to scale it to Gui, 2: Show, w600 h400 we can drop that, the picture should be shown once in the format width w260 and height h175

assistant logo
ChatDPG
Je kunt de ShowLargeImage functie aanpassen om de afbeelding in het gewenste formaat (260x175) te tonen:

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

    Gui, 2: New, , Game Image
    Gui, 2: Add, Picture, x10 y10 w260 h175, %picPath%
    Gui, 2: Show, w290 h205
return
De wijzigingen:

Picture control: w260 h175 voor de gewenste afmetingen
Gui window: w290 h205 (260+20 voor padding + 175+20 voor padding + 10 voor titlebar)
Verwijderd: +Resize +MaximizeBox opties omdat je een vaste grootte wilt
Het venster zal nu altijd de afbeelding tonen in 260×175 pixels zonder mogelijkheid tot resizing.

You
what does this part do? Gui, 2: Show, w290 h205

assistant logo
ChatDPG
Gui, 2: Show, w290 h205 doet het volgende:

Gui, 2: - Verwijst naar GUI venster nummer 2 (het nieuwe venster dat je net hebt aangemaakt)
Show - Maakt het venster zichtbaar op het scherm
w290 - Stelt de breedte van het hele venster in op 290 pixels
h205 - Stelt de hoogte van het hele venster in op 205 pixels
De reden waarom het venster (290x205) groter is dan de afbeelding (260x175):

Breedte: 260 (afbeelding) + 10 (x-positie) + 20 (padding rechts) = 290
Hoogte: 175 (afbeelding) + 10 (y-positie) + 20 (padding onder) = 205
Dit zorgt ervoor dat je afbeelding netjes binnen het venster past met wat ruimte eromheen, plus ruimte voor de titlebar van het venster.

Als je het venster precies op de afbeeldingsgrootte wilt instellen, kun je proberen:

Gui, 2: Show, w280 h195
Dit geeft minder padding maar houdt nog steeds rekening met de venster borders en titlebar.
