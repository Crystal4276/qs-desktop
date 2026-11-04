import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Panneau des disques amovibles (remplace le menu d'udiskie, ARCHITECTURE § 7.8) : par disque, ses volumes (monter, démonter,
// ouvrir, déverrouiller avec phrase de passe, verrouiller) et l'éjection. Montage automatique et notifications : Disks.qml.
Panel {
    id: root

    title: "Removable devices"

    // Phrase de passe demandée : premier disque de `Disks.pending` (branché, ou choisi par le bouton Unlock). Un seul popup est
    // ouvert à la fois : le panneau des disques ouvert l'affiche ; Tray.qml l'ouvre au besoin.
    readonly property var unlocking: visible ? Disks.pending[0] ?? null : null
    // Phrase envoyée, résultat attendu (déverrouillage en cours, même lancé depuis le panneau d'un écran disparu depuis).
    readonly property bool checking: unlocking !== null && Disks.busy.includes(unlocking.device)
    // Ouvert par le branchement d'un disque chiffré : refermé une fois les demandes satisfaites (rend le clavier, comme la
    // fenêtre d'udiskie) ; d'ici là, pas de fermeture automatique.
    property bool autoOpened: false
    holdOpen: unlocking !== null
    // Le champ a le focus à l'ouverture (la surface le donne à cet élément).
    initialFocus: unlocking !== null ? passphrase.inputItem : frameItem

    // Fermé par toi (Échap, clic à côté, autre popup) : demandes abandonnées, les boutons Unlock restent. Pas quand son écran
    // disparaît ou au verrouillage (`closingLost`) : le tray (d'un autre écran) reprend la demande ; ni un aperçu qui se referme
    // (épinglé ensuite par le tray, une fois la capture finie…).
    onClosing: {
        autoOpened = false;   // pas de second close() quand la file se vide (onUnlockingChanged)
        if (!closingLost && !previewing)
            Disks.dismissPrompts();
    }
    onVisibleChanged: {
        if (!visible)
            autoOpened = false;
    }

    // Autre volume : rien de ce qui a été tapé pour le précédent ne lui est envoyé ; le champ reprend le focus (bouton Unlock
    // choisi au clavier, disque suivant). Plus rien à demander : fermé s'il s'était ouvert tout seul.
    onUnlockingChanged: {
        passphrase.text = "";
        passphrase.error = false;
        if (unlocking !== null)
            passphrase.focusInput();
        else if (autoOpened)
            close();
        else
            frameItem.forceActiveFocus();   // champ masqué : il ne garde pas les touches suivantes
    }

    // Fermé (Tray.qml) : ouvert et épinglé sous `button` ; aperçu : épinglé.
    function openPrompt(button: Item): void {
        toggle(button, button.buttons);
        autoOpened = true;
    }

    // Dernier disque retiré ou éjecté : son icône disparaît, le panneau aussi.
    readonly property bool empty: Disks.drives.length === 0
    onEmptyChanged: if (empty) close()

    // Ouvrir un volume monté : le panneau se ferme, sauf pendant une demande de phrase de passe (elle serait abandonnée).
    function browse(volume): void {
        if (unlocking !== null)
            Disks.browse(volume);
        else
            run(() => Disks.browse(volume));
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
                    onClicked: volume.mounted ? root.browse(volume) : null

                    PanelButton {
                        visible: modelData.canUnlock && !unlocked
                        enabled: !drive.busy
                        text: "Unlock"
                        onClicked: Disks.choose(modelData)
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
                        onClicked: root.browse(volume)
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
        // Champ gardé jusqu'au résultat (ignoré si la demande a changé entre-temps) : refusée, en rouge et vidée (un autre
        // essai) ; échec d'une autre cause (polkit, udisksctl absent… : la notification le dit), demande abandonnée ; acceptée,
        // retirée de `Disks.pending` à la relecture qui suit.
        onAccepted: text => {
            if (text === "" || root.checking || root.unlocking === null)
                return;
            const target = root.unlocking;
            error = false;
            Disks.unlock(target, text, result => {
                if (root.unlocking !== target)
                    return;
                if (result === "failed") {
                    Disks.dismissPrompt(target);
                } else if (result === "wrong") {
                    passphrase.text = "";
                    passphrase.error = true;
                }
            });
        }
    }
}
