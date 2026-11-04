import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.lock

// Écran de connexion (greeter.qml, ARCHITECTURE § 9) : le design de l'écran de verrouillage (LockContent), une surface par écran,
// avec le choix de la session et du compte en plus. Le clavier va à l'écran principal (champ du mot de passe). État : services/Greeter.qml.
// Touches : Entrée (connexion), Échap (ferme la liste, sinon vide le champ), ↑/↓ (session précédente, suivante).
Scope {
    id: root

    property bool sessionsOpen: false
    // Écran principal sans Outputs (il placerait les espaces de travail du compositeur du greeter).
    readonly property string fieldScreen: Settings.primaryOf(Compositor.outputs)?.name ?? Quickshell.screens[0]?.name ?? ""

    PasswordEntry {
        id: entry
        onSubmitted: {
            root.sessionsOpen = false;
            Greeter.submit(text);
            if (Greeter.checking)
                text = "";   // la frappe continue pendant la vérification, pour l'essai suivant
        }
        onTyped: Greeter.clearMessage()
    }

    function key(event: var): void {
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            if (!Greeter.checking)
                Greeter.cycleSession(event.key === Qt.Key_Up ? -1 : 1);
        } else if (event.key === Qt.Key_Escape && sessionsOpen) {
            sessionsOpen = false;
        } else {
            entry.key(event);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property ShellScreen modelData
            readonly property bool primary: root.fieldScreen === (modelData?.name ?? "")
            readonly property var output: Compositor.output(modelData?.name ?? "")

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-greeter"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Theme.color.crust

            LockContent {
                anchors.fill: parent
                output: window.output
                primary: window.primary
                exported: true
                background: Greeter.wallpaper(window.output?.description ?? "")
                length: entry.text.length
                message: Greeter.message
                error: Greeter.error
                capsLock: entry.capsLock
                user: Greeter.user
                showPower: true
                sessions: Greeter.sessions.map(s => s.name)
                sessionIndex: Greeter.sessionIndex
                sessionsOpen: root.sessionsOpen
                // Session figée pendant la vérification (comme ↑/↓) : celle lancée est celle affichée à l'envoi.
                onSessionsToggled: root.sessionsOpen = !root.sessionsOpen && !Greeter.checking
                onSessionChosen: index => {
                    if (!Greeter.checking)
                        Greeter.sessionIndex = index;
                    root.sessionsOpen = false;
                }
                onUserClicked: Greeter.nextUser()
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
