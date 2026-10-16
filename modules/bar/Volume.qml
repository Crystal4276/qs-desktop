import QtQuick
import qs.config
import qs.services

// Icône de volume (INVENTORY.md § 1, `pulseaudio`) : 3 paliers (seuils 33 et 66 %, getIcon de Waybar), muet `U+F466␣`.
// Clic gauche : muet ; milieu : sortie suivante ; droit : panneau audio (pavucontrol dans Waybar ; ton choix du 2026-10-16) ;
// molette : ±5 % (plafond 100 %).
// Largeur min. 35 px, padding gauche 10 px seulement en tête de pilule, 0 à droite (style.css).
Item {
    id: root

    // Premier module affiché de sa pilule (renseigné par Bar.qml).
    property bool leading: true
    readonly property bool shown: Audio.ready

    readonly property int paddingLeft: leading ? Theme.bar.modulePadding : 0

    implicitWidth: paddingLeft + Math.max(Theme.bar.volumeIconMinWidth, label.implicitWidth)
    implicitHeight: label.implicitHeight + 2 * Theme.bar.modulePadding

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: root.paddingLeft + (Math.max(Theme.bar.volumeIconMinWidth, implicitWidth) - implicitWidth) / 2
        text: Audio.muted ? Theme.icon.muted + " "
            : Theme.icon.volume[Math.min(Math.floor(Audio.percent / Math.floor(100 / Theme.icon.volume.length)), Theme.icon.volume.length - 1)]
        font.family: Theme.font.icons
        font.pixelSize: Theme.font.volumeIcon
        color: Theme.module.volume
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        // Panneau à l'appui, comme ceux du tray ; muet et sortie suivante au clic, comme Waybar.
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton)
                panel.toggle(root);
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Audio.toggleMute();
            else if (mouse.button === Qt.MiddleButton)
                Audio.cycleSink();
        }
    }

    AudioPanelLoader {
        id: panel
    }

    WheelSteps {
        onStep: direction => Audio.step(5 * direction)
    }
}
