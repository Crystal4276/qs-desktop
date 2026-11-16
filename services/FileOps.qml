pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Opérations de fichiers de Nemo (copie, déplacement, corbeille) : fin et question en attente, par le système de notifications.
// Nemo ne notifie la fin que si sa fenêtre de progression a été fermée (nemo-progress-ui-handler.c), et une question (conflit,
// erreur) peut bloquer l'opération sans qu'on la voie. Pas d'interface D-Bus de progression : ses fenêtres (ToplevelManager),
// relevées sur banc (Nemo 6.8) :
//  - progression : titre « NN% statut » (« %d%% %s ») ; finie (ou annulée), elle perd son pourcentage juste avant de se
//    fermer ; fermée à la main, elle disparaît avec, et Nemo notifie lui-même à la vraie fin. Hyprland perd ce dernier titre
//    (fermeture sans rendu entre les deux) : toute fermeture y compte comme une fin (ton choix du 2026-11-16, BACKLOG) ;
//  - question : titre vide (boîtes de run_simple_dialog : erreurs, confirmations) ou « File conflict » (titre de Nemo dans la
//    langue de la session) ; notifiée si elle attend encore après questionDelay (une confirmation à laquelle on répond aussitôt
//    ne l'est pas) ; critique pour rester affichée jusqu'à la réponse (Notifs : 4 s au plus sinon ; ton choix du 2026-11-16),
//    retirée à la fermeture de la question ; clic sur la notification : la fenêtre de la question.
Singleton {
    id: root

    readonly property int questionDelay: 3000
    readonly property var notify: ["notify-send", "--app-name=nemo", "--hint=string:desktop-entry:org.Nemo"]
    readonly property string summary: "File Operations"

    Instantiator {
        model: ToplevelManager.toplevels

        delegate: QtObject {
            id: watch

            required property Toplevel modelData
            readonly property bool nemo: modelData.appId === "nemo"
            readonly property string title: modelData.title
            property bool progress: false
            readonly property bool question: nemo && (title === "" || title === "File conflict")
            property Process notifier: null

            function percent(): bool {
                return /^\d+\s?%/.test(title);
            }

            onTitleChanged: {
                if (nemo && percent())
                    progress = true;
            }
            Component.onCompleted: progress = nemo && percent()
            onQuestionChanged: {
                if (!question)
                    notifier?.signal(2);   // SIGINT : notify-send ferme sa notification
            }
            Component.onDestruction: {
                notifier?.signal(2);
                if (progress && (!percent() || !Compositor.isSway))
                    Quickshell.execDetached([...root.notify, "--", root.summary, "All file operations are finished"]);
            }

            readonly property Timer wait: Timer {
                running: watch.question
                interval: root.questionDelay
                onTriggered: {
                    watch.notifier = questionNotifier.createObject(root, { window: watch.modelData });
                    watch.notifier.running = true;
                }
            }
        }
    }

    // Possédé par le singleton : survit à la fenêtre, le temps que notify-send ferme sa notification.
    Component {
        id: questionNotifier

        Process {
            id: process

            property Toplevel window

            command: [...root.notify, "--urgency=critical", "--wait", "--action=default=Show", "--", root.summary, "Waiting for your answer"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "default" && process.window)
                        Compositor.focusWindow(process.window);
                    process.destroy();
                }
            }
        }
    }
}
