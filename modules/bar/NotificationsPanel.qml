import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Centre de notifications (ta demande du 2026-10-16) : cloche du tray. Historique (20 dernières, la plus récente en haut),
// effacement une par une ou tout ; interrupteur : notifications affichées, ou « ne pas déranger » (seules les critiques
// s'affichent, les autres arrivent ici). Lignes : NotificationRow.qml. Non vues (expirées sans toi, ou reçues pendant « ne pas
// déranger ») : en-tête en `green`, et point bleu sur la cloche jusqu'à la fermeture du centre. En tête : carte du média en
// cours (MediaCard.qml).
Panel {
    id: root

    title: "Notifications"
    hasSwitch: true
    switchChecked: !Notifs.doNotDisturb
    onSwitchToggled: checked => Notifs.doNotDisturb = !checked

    // Pas après un simple aperçu au survol de la cloche (Panel.qml, `engaged`).
    onVisibleChanged: {
        if (!visible && engaged)
            Notifs.markSeen();
    }

    // Heure relative des lignes : rafraîchie toutes les 30 s, panneau ouvert.
    property real now: Date.now()

    Timer {
        running: root.visible
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    // Lecture en cours (lecteur suivi par le module média).
    MediaCard {}

    PanelSection {
        visible: Notifs.doNotDisturb
        text: "Do not disturb · only critical notifications pop up"
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true

        PanelSection {
            text: Notifs.history.length === 0 ? "No notifications" : "Recent"
        }

        PanelButton {
            visible: Notifs.history.length > 0
            text: "Clear all"
            onClicked: Notifs.clearHistory()
        }
    }

    Flickable {
        visible: Notifs.history.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, Theme.panel.maxListHeight)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 0

            Repeater {
                model: ScriptModel {
                    values: [...Notifs.history].reverse()
                    objectProp: "key"
                }

                NotificationRow {
                    required property var modelData
                    entry: modelData
                    now: root.now
                }
            }
        }
    }
}
