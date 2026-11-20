import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell
import qs.config
import qs.services

// Centre de notifications (ta demande du 2026-10-16) : cloche du tray. Historique (100 dernières, la plus récente en haut),
// effacement une par une ou tout ; interrupteur : notifications affichées, ou « ne pas déranger » (seules les critiques
// s'affichent, les autres arrivent ici). Lignes : NotificationRow.qml. Non vues (expirées sans toi, ou reçues pendant « ne pas
// déranger ») : en-tête en `green`, et point bleu sur la cloche jusqu'à la fermeture du centre. En tête : carte du média en
// cours (MediaCard.qml).
Panel {
    id: root

    title: "Notifications"
    hasSwitch: true
    switchChecked: !Notifs.doNotDisturb
    onSwitchToggled: checked => Notifs.setDoNotDisturb(!checked)

    // Pas après un simple aperçu au survol de la cloche (Panel.qml, `wasPinned`).
    onVisibleChanged: {
        if (visible)
            historyList.contentY = historyList.originY;
        if (!visible && wasPinned)
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

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.panel.spacing

        ColumnLayout {
            id: controls
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            // Commandes fixes pendant le défilement de l'historique.
            MediaCard {}

            PanelSection {
                visible: Notifs.doNotDisturb
                text: "Do not disturb · only critical notifications pop up"
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                PanelSection {
                    text: Notifs.history.length === 0 ? "No notifications" : `Recent · ${Notifs.history.length}`
                }

                PanelButton {
                    visible: Notifs.history.length > 0
                    text: "Clear all"
                    onClicked: Notifs.clearHistory()
                }
            }
        }

        Flickable {
            id: historyList
            visible: Notifs.history.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Math.max(0,
                root.availableContentHeight - controls.implicitHeight - Theme.panel.spacing))
            contentHeight: list.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            // Suppression, repli ou écran plus grand : ne pas laisser une fin de liste vide.
            function clampPosition(): void {
                contentY = Math.max(originY, Math.min(contentY, originY + Math.max(0, contentHeight - height)));
            }
            onContentHeightChanged: Qt.callLater(clampPosition)
            onHeightChanged: Qt.callLater(clampPosition)

            Controls.ScrollBar.vertical: Controls.ScrollBar {
                id: scrollbar
                visible: historyList.contentHeight > historyList.height && historyList.height > 0
                policy: Controls.ScrollBar.AlwaysOn
                implicitWidth: Theme.notificationCentre.scrollbarWidth
                padding: Theme.notificationCentre.scrollbarInset
                minimumSize: Math.min(1, Theme.notificationCentre.scrollbarMinLength / Math.max(1, availableHeight))
                hoverEnabled: true
                background: null
                contentItem: Rectangle {
                    radius: width / 2
                    color: scrollbar.hovered || scrollbar.pressed
                        ? Theme.notificationCentre.scrollbarHover : Theme.notificationCentre.scrollbar
                }
            }

            ColumnLayout {
                id: list
                // Gouttière constante : pas de changement de largeur lors de l'apparition du curseur.
                width: historyList.width - Theme.notificationCentre.scrollbarWidth
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
}
