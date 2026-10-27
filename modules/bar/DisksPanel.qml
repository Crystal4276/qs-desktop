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
    // fenêtre d'udiskie) ; d'ici là, pas de fermeture automatique (Échap ou clic à côté abandonnent).
    property bool autoOpened: false
    holdOpen: unlocking !== null
    // Demande différée : un autre popup est épinglé ou l'outil de capture est ouvert (saisie en cours ailleurs, qui serait
    // perdue, ou clavier pris) ; ouverte à leur fermeture.
    property Item waitingUnder: null

    function blocked(): bool {
        return (BarState.popupPinned && !pinned) || Screenshot.active;
    }

    onVisibleChanged: {
        if (!visible) {
            unlocking = null;
            queue = [];
            autoOpened = false;
        }
    }

    // Ce panneau demande (ou attendra) une phrase de passe : les disques suivants lui sont confiés (Tray.qml).
    readonly property bool prompting: unlocking !== null || waitingUnder !== null
    onPromptingChanged: {
        if (prompting)
            BarState.disksPrompt = root;
        else if (BarState.disksPrompt === root)
            BarState.disksPrompt = null;
    }
    Component.onDestruction: {
        if (BarState.disksPrompt === root)
            BarState.disksPrompt = null;
    }
    // Autre volume : rien de ce qui a été tapé pour le précédent ne lui est envoyé ; le champ reprend le focus (bouton Unlock
    // choisi au clavier, disque suivant).
    onUnlockingChanged: {
        passphrase.text = "";
        passphrase.error = false;
        checking = false;
        if (unlocking !== null)
            passphrase.focusInput();
    }

    // Même volume (pas un autre arrivé sous le même nom, /dev/sdb1) : `Disks.sameVolume`. Encore à demander : présent et verrouillé.
    function stillLocked(u): bool {
        return Disks.volumes.some(v => Disks.sameVolume(v, u) && v.cleartext === "/");
    }

    // Volume choisi (bouton Unlock) : la demande en cours reprend ensuite.
    function prompt(volume): void {
        if (unlocking && !Disks.sameVolume(unlocking, volume))
            queue = [unlocking, ...queue.filter(q => !Disks.sameVolume(q, volume))];
        unlocking = volume;
    }

    // Disque suivant de la file ; sinon champ retiré, et panneau fermé s'il s'était ouvert tout seul.
    function nextPrompt(): void {
        const rest = queue.filter(stillLocked);
        queue = rest.slice(1);
        unlocking = rest[0] ?? null;
        if (unlocking === null && autoOpened)
            close();
    }

    // Volume retiré, déverrouillé (ici ou ailleurs) : au suivant ; la file aussi est élaguée.
    Connections {
        target: Disks

        function onVolumesChanged(): void {
            root.queue = root.queue.filter(root.stillLocked);
            if (root.unlocking && !root.stillLocked(root.unlocking))
                root.nextPrompt();
        }
    }

    // Ouvert et épinglé sous `button` (ou gardé s'il l'est déjà), champ de la phrase de passe affiché avec le focus : ouvrir
    // d'abord, la surface donnant le focus à son cadre à l'ouverture. Une demande déjà affichée : celle-ci attend son tour.
    function askPassphrase(button: Item, volume): void {
        if ((unlocking && Disks.sameVolume(unlocking, volume)) || queue.some(q => Disks.sameVolume(q, volume)))
            return;
        queue = [...queue, volume];
        if (unlocking !== null)
            return;
        if (blocked()) {
            waitingUnder = button;
            return;
        }
        openPrompt(button);
    }

    function openPrompt(button: Item): void {
        if (!visible || previewing) {
            toggle(button, button.buttons);
            autoOpened = true;
        }
        nextPrompt();
    }

    // Après le signal qui a fermé le popup : ouvrir pendant sa diffusion (closePopups) ferait refermer aussitôt la demande, et
    // un clic qui ouvre un autre popup le rend de nouveau bloquant.
    function resumePrompt(): void {
        if (waitingUnder === null || blocked())
            return;
        const button = waitingUnder;
        waitingUnder = null;
        if (queue.some(stillLocked))
            openPrompt(button);
        else
            queue = [];
    }

    Connections {
        target: BarState

        function onPopupPinnedChanged(): void {
            Qt.callLater(root.resumePrompt);
        }
    }

    Connections {
        target: Screenshot

        function onActiveChanged(): void {
            Qt.callLater(root.resumePrompt);
        }
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
            // Action en cours sur le disque (montage automatique, clic précédent, éjection) : boutons atténués.
            readonly property bool busy: Disks.driveBusy(modelData)

            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                PanelSection {
                    text: drive.modelData.label || drive.modelData.device
                }

                PanelButton {
                    visible: drive.modelData.isLoop || drive.modelData.canPowerOff || drive.modelData.ejectable
                    enabled: !drive.busy
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
                    // Ligne inactive aussi : un clic sur un bouton atténué ne l'atteint pas (il ouvrirait le dossier).
                    locked: drive.busy
                    onClicked: volume.mounted ? root.run(() => Disks.browse(volume)) : null

                    PanelButton {
                        visible: modelData.canUnlock && !unlocked
                        enabled: !drive.busy
                        text: "Unlock"
                        onClicked: root.prompt(modelData)
                    }

                    PanelButton {
                        visible: volume.isFilesystem
                        enabled: !drive.busy
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
                        enabled: !drive.busy
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
        // essai) ; acceptée, ou échec d'une autre cause (polkit, udisksctl absent… : la notification le dit), disque suivant.
        onAccepted: text => {
            if (text === "" || root.checking)
                return;
            const target = root.unlocking;
            root.checking = true;
            error = false;
            Disks.unlock(target, text, result => {
                if (root.unlocking !== target)
                    return;
                if (result !== "wrong") {
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
