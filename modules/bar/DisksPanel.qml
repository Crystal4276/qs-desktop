import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Panneau des disques amovibles (remplace le menu d'udiskie, ARCHITECTURE R7) : par disque, ses volumes (monter, démonter,
// ouvrir, déverrouiller avec phrase de passe, verrouiller) et l'éjection. Montage automatique et notifications : Disks.qml.
Panel {
    id: root

    title: "Removable devices"

    // Volume chiffré en attente de phrase de passe.
    property var unlocking: null

    onVisibleChanged: {
        if (!visible)
            unlocking = null;
    }
    // Autre volume : rien de ce qui a été tapé pour le précédent ne lui est envoyé.
    onUnlockingChanged: passphrase.text = ""

    // Volume retiré, déverrouillé ailleurs, ou remplacé par un autre sous le même nom (/dev/sdb1) : plus rien à demander.
    Connections {
        target: Disks

        function onVolumesChanged(): void {
            const u = root.unlocking;
            if (u && !Disks.volumes.some(v => v.path === u.path && v.label === u.label && v.size === u.size && v.cleartext === "/"))
                root.unlocking = null;
        }
    }

    function open(volume): void {
        root.close();
        Disks.browse(volume);
    }

    function sizeText(bytes: real): string {
        const units = ["B", "kB", "MB", "GB", "TB"];
        let value = bytes, i = 0;
        while (value >= 1000 && i < units.length - 1) {
            value /= 1000;
            i++;
        }
        return `${value.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
    }

    PanelSection {
        visible: Disks.drives.length === 0
        text: "No removable devices"
    }

    Repeater {
        model: ScriptModel {
            values: Disks.drives
            objectProp: "key"
        }

        ColumnLayout {
            id: drive

            required property var modelData

            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                PanelSection {
                    text: drive.modelData.label || drive.modelData.device
                }

                PanelButton {
                    visible: drive.modelData.isLoop || drive.modelData.canPowerOff
                    text: drive.modelData.isLoop ? "Detach" : "Eject"
                    onClicked: Disks.eject(drive.modelData)
                }
            }

            Repeater {
                // Volumes déchiffrés affichés à la place de leur volume chiffré une fois déverrouillé.
                model: ScriptModel {
                    values: Disks.volumes.filter(v => v.driveKey === drive.modelData.key && !v.backing)
                    objectProp: "path"
                }

                PanelRow {
                    required property var modelData

                    // Déverrouillé : volume déchiffré présent, même sans système de fichiers reconnu (LVM…), alors absent de la liste.
                    readonly property bool unlocked: modelData.isCrypto && modelData.cleartext !== "/"
                    readonly property var clear: unlocked ? Disks.volumes.find(c => c.path === modelData.cleartext) ?? null : null
                    readonly property var volume: clear ?? modelData

                    icon: modelData.isCrypto ? (unlocked ? "changes-allow" : "changes-prevent") : "drive-removable-media"
                    text: modelData.uiLabel
                    subtext: [
                        root.sizeText(modelData.size),
                        volume.fsType,
                        modelData.isCrypto && !unlocked ? "locked" : volume.mounted ? `mounted on ${volume.mountPoint}` : "not mounted"
                    ].filter(s => s).join(" · ")
                    active: volume.mounted
                    onClicked: volume.mounted ? root.open(volume) : null

                    PanelButton {
                        visible: modelData.isCrypto && !unlocked
                        text: "Unlock"
                        onClicked: root.unlocking = modelData
                    }

                    PanelButton {
                        visible: volume.isFilesystem
                        text: volume.mounted ? "Unmount" : "Mount"
                        onClicked: volume.mounted ? Disks.unmount(volume) : Disks.mount(volume)
                    }

                    PanelButton {
                        visible: volume.mounted
                        text: "Open"
                        onClicked: root.open(volume)
                    }

                    PanelButton {
                        visible: unlocked
                        text: "Lock"
                        onClicked: Disks.lock(modelData)
                    }
                }
            }
        }
    }

    PanelSection {
        visible: root.unlocking !== null
        text: `Passphrase for ${root.unlocking?.uiLabel ?? ""}`
    }

    PanelField {
        id: passphrase

        visible: root.unlocking !== null
        password: true
        placeholder: "Passphrase"
        onVisibleChanged: {
            text = "";
            if (visible)
                focusInput();
        }
        onAccepted: text => {
            if (text !== "")
                Disks.unlock(root.unlocking, text);
            root.unlocking = null;
        }
    }
}
