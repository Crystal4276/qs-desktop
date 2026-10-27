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
    property bool checking: false   // phrase envoyée, résultat attendu
    // Autres disques chiffrés branchés, demandés ensuite (deux partitions LUKS d'une même clé…).
    property var queue: []
    // Ouvert par le branchement d'un disque chiffré : refermé une fois les disques déverrouillés (rend le clavier, comme la
    // fenêtre d'udiskie).
    property bool autoOpened: false

    onVisibleChanged: {
        if (!visible) {
            unlocking = null;
            queue = [];
            autoOpened = false;
        }
    }
    // Autre volume : rien de ce qui a été tapé pour le précédent ne lui est envoyé.
    onUnlockingChanged: {
        passphrase.text = "";
        passphrase.error = false;
        checking = false;
    }

    // Encore à demander : présent, verrouillé, et pas remplacé par un autre sous le même nom (/dev/sdb1).
    function stillLocked(u): bool {
        return Disks.volumes.some(v => v.path === u.path && v.label === u.label && v.size === u.size && v.cleartext === "/");
    }

    // Disque suivant de la file ; sinon champ retiré, et panneau fermé s'il s'était ouvert tout seul.
    function nextPrompt(): void {
        const rest = queue.filter(stillLocked);
        queue = rest.slice(1);
        unlocking = rest[0] ?? null;
        if (unlocking === null && autoOpened)
            close();
    }

    // Volume retiré, déverrouillé (ici ou ailleurs) : au suivant.
    Connections {
        target: Disks

        function onVolumesChanged(): void {
            if (root.unlocking && !root.stillLocked(root.unlocking))
                root.nextPrompt();
        }
    }

    // Ouvert et épinglé sous `button` (ou gardé s'il l'est déjà), champ de la phrase de passe affiché avec le focus : ouvrir
    // d'abord, la surface donnant le focus à son cadre à l'ouverture. Une demande déjà affichée : celle-ci attend son tour.
    function askPassphrase(button: Item, volume): void {
        if (!visible || previewing) {
            toggle(button, button.buttons);
            autoOpened = true;
        }
        if (unlocking === null)
            unlocking = volume;
        else if (unlocking.path !== volume.path && !queue.some(q => q.path === volume.path))
            queue = [...queue, volume];
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
                    visible: drive.modelData.isLoop || drive.modelData.canPowerOff || drive.modelData.ejectable
                    enabled: !Disks.driveBusy(drive.modelData)
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
                    // Action en cours (montage automatique, clic précédent) : boutons atténués.
                    readonly property bool busy: Disks.busy.includes(modelData.device) || Disks.busy.includes(volume.device)

                    icon: modelData.isCrypto ? (unlocked ? "changes-allow" : "changes-prevent") : "drive-removable-media"
                    text: modelData.uiLabel
                    subtext: [
                        root.sizeText(modelData.size),
                        volume.fsType,
                        modelData.isCrypto && !unlocked ? "locked" : volume.mounted ? `mounted on ${volume.mountPoint}` : "not mounted"
                    ].filter(s => s).join(" · ")
                    active: volume.mounted
                    onClicked: volume.mounted ? root.run(() => Disks.browse(volume)) : null

                    PanelButton {
                        visible: modelData.canUnlock && !unlocked
                        enabled: !busy
                        text: "Unlock"
                        onClicked: root.unlocking = modelData
                    }

                    PanelButton {
                        visible: volume.isFilesystem
                        enabled: !busy
                        text: volume.mounted ? "Unmount" : "Mount"
                        onClicked: volume.mounted ? Disks.unmount(volume) : Disks.mount(volume)
                    }

                    PanelButton {
                        visible: volume.mounted
                        text: "Open"
                        onClicked: root.run(() => Disks.browse(volume))
                    }

                    PanelButton {
                        visible: unlocked
                        enabled: !busy
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
            if (visible)
                focusInput();
        }
        // Champ gardé jusqu'au résultat (ignoré si la demande a changé entre-temps) : refusée, en rouge et vidée (un autre
        // essai) ; acceptée ou impossible à essayer (udisksctl absent : la notification le dit), disque suivant.
        onAccepted: text => {
            if (text === "" || root.checking)
                return;
            const target = root.unlocking;
            root.checking = true;
            error = false;
            Disks.unlock(target, text, (ok, code) => {
                if (root.unlocking !== target)
                    return;
                if (ok || code === -1) {
                    root.nextPrompt();
                } else {
                    root.checking = false;
                    passphrase.text = "";
                    passphrase.error = true;
                }
            });
        }
    }
}
