import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Centre de notifications (ta demande du 2026-10-16) : cloche du tray. Historique (20 dernières, la plus récente en haut),
// effacement une par une ou tout ; interrupteur : notifications affichées, ou « ne pas déranger » (seules les critiques
// s'affichent, les autres arrivent ici). Non vues (expirées sans toi, ou reçues pendant « ne pas déranger ») : en `green`,
// et point bleu sur la cloche jusqu'à la fermeture du centre.
Panel {
    id: root

    title: "Notifications"
    hasSwitch: true
    switchChecked: !Notifs.doNotDisturb
    onSwitchToggled: checked => Notifs.doNotDisturb = !checked

    onVisibleChanged: {
        if (!visible)
            Notifs.markSeen();
    }

    // Corps en texte simple sur une ligne (balises retirées, entités courantes décodées).
    function plain(text: string): string {
        return text.replace(/<br\s*\/?>/gi, " ").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&amp;/g, "&").trim();
    }

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

                PanelRow {
                    required property var modelData

                    clickable: false
                    icon: modelData.icon || "preferences-desktop-notification"   // sans icône : icône générique (alignement)
                    text: modelData.summary || modelData.appName
                    subtext: [Qt.formatTime(new Date(modelData.timestamp), "HH:mm"), modelData.appName, root.plain(modelData.body)]
                        .filter(s => s).join(" · ")
                    active: !modelData.seen

                    PanelButton {
                        text: "Clear"
                        onClicked: Notifs.removeHistory(modelData.key)
                    }
                }
            }
        }
    }
}
