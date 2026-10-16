import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Notifications affichées, empilées dans le coin bas-droit (dunstrc : origin bottom-right, offset 4x4, gap 20) de l'écran
// choisi par la config machine (`notificationsOutput` : "primary" ou description d'écran), l'écran principal à défaut.
PanelWindow {
    id: root

    readonly property string outputName: {
        const wanted = Settings.notificationsOutput;
        const described = wanted !== "primary" ? Compositor.outputs.find(o => o.description === wanted) : null;
        return (described ?? Outputs.primary)?.name ?? "";
    }

    readonly property ShellScreen target: Quickshell.screens.find(s => s.name === outputName) ?? null

    screen: target
    visible: Notifs.popups.length > 0 && target !== null
    onVisibleChanged: Notifs.hovered = false

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: Theme.notification.offset
        right: Theme.notification.offset
    }
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        spacing: Theme.notification.gap

        Repeater {
            model: ScriptModel {
                values: [...Notifs.popups]
            }

            NotificationCard {}
        }

        // Délais suspendus tant que le pointeur est sur les notifications (Dunst).
        HoverHandler {
            onHoveredChanged: Notifs.hovered = hovered
        }
    }
}
