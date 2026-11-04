import QtQuick
import qs.config
import qs.services

// Éteindre, redémarrer, mettre en veille : sous le champ du mot de passe, à l'écran de verrouillage comme à l'écran de connexion
// (modules/greeter). Sans confirmation, comme le panneau de réglages. Boutons ronds au style du champ ; à la souris seulement
// (le clavier va au mot de passe).
Row {
    id: root

    spacing: Theme.lock.spacing

    Repeater {
        model: [
            { image: Theme.image.shutdown, action: () => Session.poweroff() },
            { image: Theme.image.restart, action: () => Session.reboot() },
            { image: Theme.image.suspend, action: () => Session.suspend() }
        ]

        Rectangle {
            required property var modelData

            width: Theme.lock.powerSize
            height: width
            radius: width / 2
            color: Theme.lock.field
            border.width: Theme.panel.border
            border.color: hover.hovered ? Theme.lock.fieldFocus : Theme.lock.fieldBorder

            Image {
                anchors.centerIn: parent
                source: parent.modelData.image
                sourceSize.width: Theme.lock.powerImageSize
                sourceSize.height: Theme.lock.powerImageSize
            }

            HoverHandler {
                id: hover
            }

            TapHandler {
                onTapped: parent.modelData.action()
            }
        }
    }
}
