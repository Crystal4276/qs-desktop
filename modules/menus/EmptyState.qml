import QtQuick
import QtQuick.Layouts
import qs.config

// Liste vide du menu d'applications (ta demande du 2026-10-21, style GNOME / KDE) : au centre de sa boîte, glyphe de 48 px en
// `subtext0`, message en `text`, astuce en `subtext0`.
ColumnLayout {
    id: root

    property string glyph: ""
    property string title: ""
    property string hint: ""

    anchors.centerIn: parent
    width: parent.width - 4 * Theme.appMenu.padding
    spacing: Theme.appMenu.spacing

    Text {
        Layout.alignment: Qt.AlignHCenter
        visible: root.glyph !== ""
        text: root.glyph
        font.family: Theme.font.icons
        font.pixelSize: Theme.appMenu.largeIconSize
        color: Theme.appMenu.description
    }

    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        font.family: Theme.font.text
        font.pixelSize: Theme.font.appMenu
        color: Theme.appMenu.text
        elide: Text.ElideMiddle
    }

    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: root.hint
        font.family: Theme.font.text
        font.pixelSize: Theme.appMenu.descriptionFontSize
        color: Theme.appMenu.description
        wrapMode: Text.Wrap
    }
}
