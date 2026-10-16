import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.config
import qs.services

// Panneau de réglages façon GNOME (ARCHITECTURE § 10.1.4) : ouvert par l'engrenage de la barre ou `qs ipc call settings toggle`.
// Remplace le power menu Rofi. De haut en bas, dans l'ordre des réglages rapides de GNOME 51 :
// - batterie (laptop), capture d'écran ; à droite verrouiller, se déconnecter, redémarrer, éteindre (sans confirmation) ;
// - curseurs : sortie son, micro, luminosité (laptop) ; flèche : choix du périphérique ;
// - profils d'énergie (3 boutons) ; bascules en 2 colonnes : ne pas déranger, écran allumé, veilleuse, HDR, VRR, mode avion.
// Ce qui a sa place dans le tray (réseau, Bluetooth, VPN, disques, notifications) n'est pas repris.
PanelWindow {
    id: root

    property string expanded: ""   // "sink", "source" ou "" : liste de périphériques dépliée
    property real closedAt: 0

    // Sous le bouton, centré, sans dépasser les marges de la barre (comme les panneaux du tray). Un appui sur l'engrenage
    // pendant que le panneau est ouvert : la barre l'a déjà fermé (Bar.qml), il ne se rouvre pas.
    function toggle(button: Item): void {
        if (visible || Date.now() - closedAt < 400) {
            close();
            return;
        }
        const window = button.QsWindow.window;
        screen = window.screen;
        const x = button.mapToItem(null, 0, 0).x;
        frame.x = Math.max(Theme.bar.marginSide, Math.min(x + (button.width - frame.width) / 2, window.width - Theme.bar.marginSide - frame.width));
        visible = true;
        frame.forceActiveFocus();
    }

    function close(): void {
        if (visible)
            closedAt = Date.now();
        visible = false;
    }

    function run(action: var): void {
        close();
        action();
    }

    function nodeName(node: PwNode): string {
        return node.nickname || node.description || node.name;
    }

    // Surface de la couche Overlay sur la zone utile de l'écran (sous les barres), comme le lanceur : ouvrable au clavier
    // (un popup ne peut pas prendre le clavier sans clic), clavier réservé (Échap), un clic à côté ou sur une barre ferme.
    visible: false
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    onVisibleChanged: {
        if (visible) {
            BarState.popupOpened();
        } else {
            BarState.popupClosed();
            expanded = "";
        }
    }

    Connections {
        target: BarState
        function onClosePopups() {
            root.close();
        }
    }

    // Appui à côté du cadre : fermeture.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            if (!frame.contains(mapToItem(frame, mouse.x, mouse.y)))
                root.close();
        }
    }

    PanelFrame {
        id: frame

        y: Theme.panel.gap
        width: Theme.panel.width
        maxHeight: parent.height - Theme.panel.gap - Theme.bar.marginSide
        onCloseRequested: root.close()

        // --- Ligne du haut ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            Row {
                visible: Battery.available
                spacing: Theme.panel.rowPadding

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.charging ? Theme.icon.batteryCharging : Theme.level(Theme.icon.battery, Battery.percent)
                    font.family: Theme.font.icons
                    font.pixelSize: Theme.quickSettings.glyphSize
                    color: Battery.warning && !Battery.charging ? Theme.module.batteryWarning : Theme.module.battery
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Battery.percent} %`
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    color: Theme.panel.text
                }
            }

            QuickButton {
                glyph: Theme.icon.screenshot
                onClicked: root.run(Session.screenshot)
            }

            Item {
                Layout.fillWidth: true
            }

            QuickButton {
                image: Theme.image.lock
                onClicked: root.run(Session.lock)
            }

            QuickButton {
                image: Theme.image.logout
                onClicked: root.run(Session.logout)
            }

            QuickButton {
                image: Theme.image.restart
                onClicked: root.run(Session.reboot)
            }

            QuickButton {
                image: Theme.image.shutdown
                onClicked: root.run(Session.poweroff)
            }
        }

        // --- Curseurs ---
        QuickSlider {
            visible: Audio.ready
            icon: Audio.muted ? Theme.icon.muted : Theme.level(Theme.icon.volume, Audio.percent)
            value: Audio.volume
            muted: Audio.muted
            expandable: Audio.sinks.length > 1
            expanded: root.expanded === "sink"
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
            onExpandClicked: root.expanded = expanded ? "" : "sink"
        }

        Repeater {
            model: ScriptModel {
                values: root.expanded === "sink" ? Audio.sinks : []
            }

            PanelRow {
                required property PwNode modelData

                icon: "audio-speakers"
                text: root.nodeName(modelData)
                active: modelData.id === Audio.sink?.id
                onClicked: Audio.setDefaultSink(modelData)
            }
        }

        QuickSlider {
            visible: Audio.source?.audio !== undefined && Audio.source?.audio !== null
            icon: Audio.micMuted ? Theme.icon.microphoneMuted : Theme.icon.microphone
            value: Audio.source?.audio?.volume ?? 0
            muted: Audio.micMuted
            expandable: Audio.sources.length > 1
            expanded: root.expanded === "source"
            onMoved: v => Audio.source.audio.volume = v
            onIconClicked: Audio.toggleMicMute()
            onExpandClicked: root.expanded = expanded ? "" : "source"
        }

        Repeater {
            model: ScriptModel {
                values: root.expanded === "source" ? Audio.sources : []
            }

            PanelRow {
                required property PwNode modelData

                icon: "audio-input-microphone"
                text: root.nodeName(modelData)
                active: modelData.id === Audio.source?.id
                onClicked: Audio.setDefaultSource(modelData)
            }
        }

        QuickSlider {
            visible: Brightness.available
            icon: Theme.level(Theme.icon.backlight, Brightness.percent)
            iconColor: Theme.module.backlight
            value: Brightness.percent / 100
            onMoved: v => Brightness.setPercent(Math.round(v * 100))
        }

        // --- Profils d'énergie ---
        RowLayout {
            Layout.fillWidth: true
            visible: Profiles.available
            spacing: Theme.panel.spacing

            QuickToggle {
                vertical: true
                icon: Theme.icon.powerSaver
                title: "Power Saver"
                checked: Profiles.profile === PowerProfile.PowerSaver
                onClicked: Profiles.set(PowerProfile.PowerSaver)
            }

            QuickToggle {
                vertical: true
                icon: Theme.icon.balanced
                title: "Balanced"
                checked: Profiles.profile === PowerProfile.Balanced
                onClicked: Profiles.set(PowerProfile.Balanced)
            }

            QuickToggle {
                visible: Profiles.hasPerformance
                vertical: true
                icon: Theme.icon.performance
                title: "Performance"
                checked: Profiles.profile === PowerProfile.Performance
                onClicked: Profiles.set(PowerProfile.Performance)
            }
        }

        // --- Bascules ---
        GridLayout {
            Layout.fillWidth: true
            columns: Theme.quickSettings.columns
            columnSpacing: Theme.panel.spacing
            rowSpacing: Theme.panel.spacing

            QuickToggle {
                icon: Theme.icon.doNotDisturb
                title: "Do Not Disturb"
                checked: Notifs.doNotDisturb
                onClicked: Notifs.doNotDisturb = !Notifs.doNotDisturb
            }

            QuickToggle {
                icon: Theme.icon.keepAwake
                title: "Keep Screen On"
                checked: Session.keepAwake
                onClicked: Session.keepAwake = !Session.keepAwake
            }

            QuickToggle {
                icon: Theme.icon.nightLight
                title: "Night Light"
                subtitle: NightLight.schedule
                checked: NightLight.enabled
                onClicked: NightLight.toggle()
            }

            QuickToggle {
                visible: Displays.hdrOutputs.length > 0
                icon: Theme.icon.hdr
                title: "HDR"
                subtitle: Displays.hdrOutputs.map(o => o.name).join(", ")
                checked: Displays.hdr
                onClicked: Displays.toggleHdr()
            }

            QuickToggle {
                visible: Displays.vrrOutputs.length > 0
                icon: Theme.icon.vrr
                title: "VRR"
                subtitle: Displays.vrrOutputs.map(o => o.name).join(", ")
                checked: Displays.vrr
                onClicked: Displays.toggleVrr()
            }

            QuickToggle {
                visible: Battery.available && Rfkill.available
                icon: Theme.icon.airplane
                title: "Airplane Mode"
                checked: Rfkill.airplane
                onClicked: Rfkill.toggle()
            }
        }
    }

    // Curseur : glyphe (clic : muet), curseur de volume, pourcentage, flèche du choix de périphérique.
    component QuickSlider: RowLayout {
        id: line

        property string icon: ""
        property color iconColor: Theme.module.volume
        property real value: 0
        property bool muted: false
        property bool expandable: false
        property bool expanded: false
        signal moved(real value)
        signal iconClicked
        signal expandClicked

        Layout.fillWidth: true
        spacing: Theme.panel.spacing

        Text {
            Layout.preferredWidth: Theme.quickSettings.imageSize   // glyphes de largeurs différentes : curseurs alignés
            horizontalAlignment: Text.AlignHCenter
            text: line.icon
            font.family: Theme.font.icons
            font.pixelSize: Theme.quickSettings.glyphSize
            color: line.iconColor

            MouseArea {
                anchors.fill: parent
                onClicked: line.iconClicked()
            }
        }

        VolumeSlider {
            Layout.fillWidth: true
            inset: Theme.slider.knobSize / 2
            opacity: line.muted ? 0.5 : 1   // comme l'OSD
            value: line.value
            onMoved: v => line.moved(v)
        }

        PanelSection {
            Layout.fillWidth: false
            Layout.preferredWidth: widest.implicitWidth
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(line.value * 100)} %`
        }

        // Mesure de « 100 % » rendue comme le pourcentage (TextMetrics ne suit pas le rendu natif du texte).
        PanelSection {
            id: widest
            visible: false
            Layout.fillWidth: false
            text: "100 %"
        }

        // Toujours là (invisible sans choix) : curseurs et pourcentages alignés d'une ligne à l'autre.
        PanelButton {
            opacity: line.expandable ? 1 : 0
            enabled: line.expandable
            fontFamily: Theme.font.icons
            text: line.expanded ? Theme.icon.expanded : Theme.icon.next
            onClicked: line.expandClicked()
        }
    }
}
