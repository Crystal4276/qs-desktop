import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar

// OSD (ton choix du 2026-10-16) : volume, micro ou luminosité changés au clavier (`qs ipc call audio|brightness …`).
// Cadre des panneaux, icône du module de la barre, niveau dans le style du curseur de volume, pourcentage.
// Sur l'écran focalisé, centré en bas ; disparaît après Theme.osd.duration ; ne prend aucun clic.
PanelWindow {
    id: root

    property string kind: ""   // "volume", "mic", "brightness"

    function show(k: string): void {
        kind = k;
        visible = true;
        hide.restart();
    }

    readonly property real level: kind === "brightness" ? Brightness.percent / 100
        : kind === "mic" ? (Audio.source?.audio?.volume ?? 0) : Audio.volume
    readonly property bool mutedNow: kind === "mic" ? Audio.micMuted : kind === "volume" && Audio.muted
    readonly property string glyph: kind === "brightness"
        ? Theme.level(Theme.icon.backlight, Brightness.percent)
        : kind === "mic" ? (Audio.micMuted ? Theme.icon.microphoneMuted : Theme.icon.microphone)
        : Audio.muted ? Theme.icon.muted
        : Theme.level(Theme.icon.volume, Audio.percent)

    screen: Quickshell.screens.find(s => s.name === Compositor.focusedOutput) ?? null
    visible: false
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors.bottom: true
    margins.bottom: Theme.osd.marginBottom
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}   // aucun clic : ils passent aux fenêtres dessous
    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight

    Connections {
        target: Audio
        function onChangedByKey(k) {
            root.show(k);
        }
    }

    Connections {
        target: Brightness
        function onChangedByKey() {
            root.show("brightness");
        }
    }

    Timer {
        id: hide
        interval: Theme.osd.duration
        onTriggered: root.visible = false
    }

    Rectangle {
        id: frame

        implicitWidth: row.implicitWidth + 2 * Theme.panel.padding
        implicitHeight: row.implicitHeight + 2 * Theme.panel.padding
        radius: Theme.panel.radius
        color: Theme.panel.background
        border.width: Theme.panel.border
        border.color: Theme.panel.borderColor

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Theme.panel.spacing

            Text {
                Layout.preferredWidth: Theme.bar.volumeIconMinWidth
                horizontalAlignment: Text.AlignHCenter
                text: root.glyph
                font.family: Theme.font.icons
                font.pixelSize: Theme.font.volumeIcon
                color: root.kind === "brightness" ? Theme.module.backlight : Theme.module.volume
            }

            VolumeSlider {
                Layout.preferredWidth: Theme.osd.levelWidth
                inset: Theme.slider.knobSize / 2
                enabled: false
                opacity: root.mutedNow ? 0.5 : 1
                value: root.level
            }

            PanelSection {
                Layout.fillWidth: false
                Layout.preferredWidth: widest.implicitWidth
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(root.level * 100)} %`
            }

            // Mesure de « 100 % » rendue comme le pourcentage (TextMetrics ne suit pas le rendu natif du texte).
            PanelSection {
                id: widest
                visible: false
                Layout.fillWidth: false
                text: "100 %"
            }
        }
    }
}
