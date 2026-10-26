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
// - curseurs : sortie son, luminosité (laptop) ; flèche : choix du périphérique (toujours affichée, même avec un seul
//   périphérique : la liste montre lequel est utilisé), puis « Advanced… » (pavucontrol). Pas de micro (ta demande du 2026-10-26 :
//   jamais réglé ici ; il reste dans le panneau audio) ;
// - profils d'énergie (3 boutons) ; bascules en 2 colonnes : ne pas déranger (clic droit : son horaire), écran allumé, veilleuse,
//   HDR, VRR, mode avion (dès qu'il y a une radio Wi-Fi ou Bluetooth).
// Ce qui a sa place dans le tray (réseau, Bluetooth, VPN, disques, notifications) n'est pas repris.
// Carte du tray (Panel.qml, ta demande du 2026-10-26) : aperçu au survol de l'engrenage, épinglée au clic, fermée comme les autres.
Panel {
    id: root

    property string expanded: ""   // "sink", "dnd" ou "" : liste de périphériques ou horaire du « ne pas déranger » déplié

    WlrLayershell.namespace: "quickshell-settings"

    onVisibleChanged: if (!visible) expanded = ""   // en plus de celui de Panel.qml

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

        QuickButton {
            glyph: Theme.icon.wallpaper
            onClicked: root.run(() => Wallpapers.pickerRequested())
        }

        Item {
            Layout.fillWidth: true
        }

        QuickButton {
            image: Theme.image.lock
            onClicked: root.run(() => Session.lock())
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
        expandable: Audio.sinks.length > 0
        expanded: root.expanded === "sink"
        onMoved: v => Audio.setVolume(v)
        onIconClicked: Audio.toggleMute()
        onExpandClicked: root.expanded = expanded ? "" : "sink"
    }

    AudioDevices {
        visible: root.expanded === "sink"
    }

    MixerButton {
        visible: root.expanded === "sink"
        onOpened: root.close()
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
            subtitle: Notifs.scheduled ? `${Notifs.scheduleFrom} – ${Notifs.scheduleTo}` : ""
            checked: Notifs.doNotDisturb
            onClicked: Notifs.setDoNotDisturb(!Notifs.doNotDisturb)
            onSecondaryClicked: root.expanded = root.expanded === "dnd" ? "" : "dnd"
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
            visible: Rfkill.available
            icon: Theme.icon.airplane
            title: "Airplane Mode"
            checked: Rfkill.airplane
            onClicked: Rfkill.toggle()
        }
    }

    // Horaire du « ne pas déranger » (clic droit sur sa bascule) : heures modifiables (Entrée ou sortie du champ), interrupteur.
    PanelRow {
        visible: root.expanded === "dnd"
        clickable: false
        text: "Schedule"

        TimeField {
            value: Notifs.scheduleFrom
            onEdited: time => Notifs.setSchedule(Notifs.scheduled, time, Notifs.scheduleTo)
            onAccepted: root.frameItem.forceActiveFocus()   // Entrée : le cadre reprend le clavier (Échap, flèches)
            onCancelled: root.frameItem.forceActiveFocus()
        }

        Text {
            text: "–"
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.fontSize
            color: Theme.panel.text
        }

        TimeField {
            value: Notifs.scheduleTo
            onEdited: time => Notifs.setSchedule(Notifs.scheduled, Notifs.scheduleFrom, time)
            onAccepted: root.frameItem.forceActiveFocus()
            onCancelled: root.frameItem.forceActiveFocus()
        }

        PanelSwitch {
            checked: Notifs.scheduled
            onToggled: checked => Notifs.setSchedule(checked, Notifs.scheduleFrom, Notifs.scheduleTo)
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
            opacity: line.muted ? Theme.panel.disabledOpacity : 1   // comme l'OSD
            value: line.value
            onMoved: v => line.moved(v)
        }

        PercentLabel {
            value: line.value
        }

        // Toujours là (invisible sans liste : luminosité) : curseurs et pourcentages alignés d'une ligne à l'autre.
        PanelButton {
            opacity: line.expandable ? 1 : 0
            enabled: line.expandable
            fontFamily: Theme.font.icons
            text: line.expanded ? Theme.icon.expanded : Theme.icon.next
            onClicked: line.expandClicked()
        }
    }
}
