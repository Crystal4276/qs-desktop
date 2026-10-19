import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar

// Écran de verrouillage natif (remplace swaylock, ARCHITECTURE § 10.1 R2) : protocole ext-session-lock (WlSessionLock) — si
// Quickshell s'arrête, la session reste verrouillée — et mot de passe vérifié par PAM (`/etc/pam.d/login`, comme swaylock).
// Une surface par écran (LockContent) ; le champ du mot de passe s'affiche sur l'écran principal (services/Outputs.qml), la saisie
// est prise quel que soit l'écran qui a le clavier. Pas de déverrouillage par IPC.
// Verrouiller : Session.lock() (panneau de réglages, menu), `qs ipc call lock lock`, veille (IdleMonitor, à venir).
Scope {
    id: root

    // Pas de rechargement automatique de la config pendant le verrouillage (sauvegarde dans le dépôt, `git pull`…) : dans
    // Quickshell 0.3, un WlSessionLock rechargé verrouillé recrée ses surfaces avant de reprendre les anciennes, et le compositeur
    // coupe Quickshell (erreur de protocole) ; non verrouillé, il déverrouillerait la session sans mot de passe. Les changements
    // faits pendant le verrouillage sont pris au suivant. État gardé malgré tout d'un rechargement à l'autre (rechargement
    // demandé à la main) : en cas d'échec, la session reste verrouillée plutôt que de s'ouvrir.
    property alias locked: persist.locked
    onLockedChanged: Quickshell.watchFiles = !locked
    property string password: ""
    property bool checking: false
    property bool error: false
    property string message: ""
    property bool capsLock: false
    // Écran du champ : l'écran principal ; à défaut (aucun écran détecté), celui qui était focalisé au verrouillage.
    property alias lockedScreen: persist.lockedScreen
    readonly property string fieldScreen: Outputs.primary?.name ?? lockedScreen

    // Dossier de configuration PAM : vide = /etc/pam.d (les tests y mettent une configuration factice).
    property string pamDirectory: ""

    function lock(): void {
        if (locked)
            return;
        BarState.closePopups([]);
        password = "";
        error = false;
        message = "";
        lockedScreen = Compositor.focusedOutput;
        locked = true;
    }

    function submit(): void {
        if (checking || password === "")
            return;
        checking = true;
        error = false;
        message = "Checking…";
        if (!pam.start())
            fail("Authentication unavailable");
    }

    function fail(text: string): void {
        checking = false;
        error = true;
        message = text;
        password = "";
    }

    function key(event: var): void {
        const k = event.key;
        // Verrouillage majuscules : déduit d'une lettre tapée (majuscule sans Maj, ou minuscule avec Maj).
        if (event.text.length === 1 && event.text.toLowerCase() !== event.text.toUpperCase()) {
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            capsLock = (event.text === event.text.toUpperCase()) !== shift;
        }
        if (checking)
            return;
        if (k === Qt.Key_Return || k === Qt.Key_Enter)
            submit();
        else if (k === Qt.Key_Escape)
            password = "";
        else if (k === Qt.Key_Backspace)
            password = (event.modifiers & Qt.ControlModifier) ? "" : password.slice(0, -1);
        else if (event.text !== "" && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {   // Suppr. : U+007F
            password += event.text;
            error = false;
            message = "";
        }
    }

    PersistentProperties {
        id: persist
        reloadableId: "lockState"

        property bool locked: false
        property string lockedScreen: ""
    }

    Connections {
        target: Session
        function onLockRequested() {
            root.lock();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }
    }

    PamContext {
        id: pam

        config: "login"
        Component.onCompleted: {
            if (root.pamDirectory !== "")
                configDirectory = root.pamDirectory;
        }

        // PAM demande le mot de passe : réponse avec la saisie, effacée aussitôt.
        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.password);
            root.password = "";
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.checking = false;
                root.message = "";
                root.locked = false;
            } else {
                root.fail(result === PamResult.MaxTries ? "Too many attempts" : "Wrong password");
            }
        }

        onError: error => root.fail("Authentication error")
    }

    WlSessionLock {
        id: sessionLock

        locked: root.locked
        // Verrouillage confirmé par le compositeur : connu de Session (verrouillage avant la mise en veille, services/Idle.qml).
        onSecureChanged: Session.locked = secure

        WlSessionLockSurface {
            id: surface

            color: Theme.color.crust

            LockContent {
                anchors.fill: parent
                output: Compositor.output(surface.screen?.name ?? "")
                primary: root.fieldScreen === (surface.screen?.name ?? "")
                length: root.password.length
                message: root.message
                error: root.error
                capsLock: root.capsLock
                user: Quickshell.env("USER") ?? ""
                focus: true
                Keys.onPressed: event => {
                    root.key(event);
                    event.accepted = true;
                }
                Component.onCompleted: forceActiveFocus()
            }
        }
    }
}
