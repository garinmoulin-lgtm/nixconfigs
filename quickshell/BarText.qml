import QtQuick

// Plain text in the bar font. Plain (not rich) text so the spacing inside
// your waybar format strings is preserved exactly.
Text {
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.weight: Theme.fontWeight
}
