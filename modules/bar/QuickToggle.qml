import QtQuick
import QtQuick.Layouts
import qs.config

// Bascule du panneau de réglages (tuile des réglages rapides de GNOME) : bouton de panneau (fond `surface0`, survol `surface1`,
// coins 10 px) avec glyphe, titre et sous-titre ; activée : fond `green`, texte `mantle`.
// `vertical` : glyphe au-dessus du titre (les trois profils d'énergie sur une ligne). Clic droit : `secondaryClicked` (réglages
// de la bascule, comme « ne pas déranger » et son horaire).
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool vertical: false
    signal clicked
    signal secondaryClicked

    readonly property color foreground: checked ? Theme.quickSettings.checkedText : Theme.panel.text

    Layout.fillWidth: true
    Layout.preferredWidth: 1   // colonnes de même largeur
    // Même hauteur pour toutes les bascules d'un même genre, sous-titre ou non (tuiles de GNOME) : celle d'une tuile à deux lignes.
    implicitHeight: (vertical ? content.implicitHeight : Math.max(content.implicitHeight, twoLines.implicitHeight)) + 2 * Theme.panel.rowPadding
    radius: Theme.panel.rowRadius
    color: checked ? Theme.quickSettings.checked : hover.hovered ? Theme.panel.buttonHover : Theme.panel.button

    // Clavier (Tab, flèches) : Entrée ou Espace activent ; liseré quand l'élément est choisi.
    activeFocusOnTab: true
    border.width: activeFocus ? Theme.panel.border : 0
    border.color: Theme.panel.focusRing
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    GridLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Theme.panel.buttonPaddingH
            rightMargin: Theme.panel.buttonPaddingH
        }
        columns: root.vertical ? 1 : 2
        columnSpacing: Theme.panel.spacing
        rowSpacing: 0

        Text {
            Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: root.icon
            font.family: Theme.font.icons
            font.pixelSize: Theme.quickSettings.glyphSize
            color: root.foreground
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
                text: root.title
                font.family: Theme.font.text
                font.pixelSize: root.vertical ? Theme.panel.smallFontSize : Theme.panel.fontSize
                color: root.foreground
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: root.checked ? root.foreground : Theme.panel.secondaryText
                elide: Text.ElideRight
            }
        }
    }

    // Mesure d'une tuile à titre et sous-titre (rendu natif : TextMetrics ne mesure pas pareil).
    Column {
        id: twoLines
        visible: false

        Text {
            text: " "
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.fontSize
        }

        Text {
            text: " "
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.secondaryClicked() : root.clicked()
    }
}
