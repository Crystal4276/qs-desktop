pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Opérations de fichiers de Nemo (copie, déplacement, corbeille) : fin et question en attente, par le système de notifications.
// Nemo ne notifie la fin que si sa fenêtre de progression a été fermée (nemo-progress-ui-handler.c), et une question (conflit,
// erreur) peut bloquer l'opération sans qu'on la voie. Pas d'interface D-Bus de progression : ses fenêtres (ToplevelManager),
// relevées sur banc (Nemo 6.8) :
//  - progression : titre « NN% statut » (« %d%% %s ») ; sa fermeture compte comme une fin (ou une annulation). Fermée à la
//    main, Nemo notifie aussi à la vraie fin ; impossible à distinguer : le titre sans pourcentage qu'elle prend en finissant
//    se perd souvent, sous Hyprland comme sous Sway (fermeture sans rendu entre les deux, vu sur banc ; ton choix) ;
//  - question : titre vide (boîtes de run_simple_dialog : erreurs, confirmations) ou celui de la boîte de conflit (« File
//    conflict » dans la langue de Nemo : sa traduction) ; Nemo traite ses opérations l'une après l'autre, une seule attend donc
//    à la fois ; notifiée si elle attend encore après questionDelay sans avoir le focus (sous tes yeux, ou une confirmation
//    à laquelle on répond aussitôt : rien), sous « Nemo » (une erreur sans rapport avec une copie a aussi un titre vide) ;
//    critique pour rester affichée jusqu'à la réponse (Notifs : 4 s au plus sinon ; ton choix du 2026-11-16), retirée à la
//    fermeture de la question ; clic sur la notification : la fenêtre de la question.
Singleton {
    id: root

    readonly property int questionDelay: 3000
    readonly property var notify: ["notify-send", "--app-name=nemo", "--hint=string:desktop-entry:org.Nemo", "--icon=system-file-manager"]
    readonly property string summary: "File Operations"

    // Statut de la fenêtre de progression, sans son pourcentage. Copie, déplacement (« Copying "A" to "B" », « Copying file 3
    // of 10 (in "A") to "B" », guillemets de la langue de Nemo) : noms [A, B] ; sinon [] (« Moving files to trash »…).
    function status(title: string): string {
        return title.replace(/^\d+\s?%\s*/, "");
    }

    function names(title: string): var {
        const quoted = /["“«]\s*([^"”»]+?)\s*["”»]/g;   // pas de matchAll dans le moteur JavaScript de Qt
        const text = status(title);
        const found = [];
        for (let m = quoted.exec(text); m !== null; m = quoted.exec(text))
            found.push(m[1]);
        return found.length === 2 ? found : [];
    }

    // Dossier d'arrivée (chemin) parmi les fichiers ouverts par Nemo : celui qui contient A s'il y est, sinon le dernier « /B/ ».
    function destinationIn(paths: var, title: string): string {
        const [source, target] = names(title);
        if (!target)
            return "";
        const at = (p, i) => i >= 0 ? p.slice(0, i + target.length + 1) : "";
        return paths.map(p => at(p, p.indexOf(`/${target}/${source}`))).find(d => d !== "")
            ?? paths.map(p => at(p, p.lastIndexOf(`/${target}/`))).find(d => d !== "") ?? "";
    }
    property string conflictTitle: "File conflict"

    Process {
        running: true
        command: ["gettext", "-d", "nemo", "File conflict"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text !== "")
                    root.conflictTitle = text;
            }
        }
    }

    Instantiator {
        model: ToplevelManager.toplevels

        delegate: QtObject {
            id: watch

            required property Toplevel modelData
            readonly property bool nemo: modelData?.appId === "nemo"
            readonly property string title: modelData?.title ?? ""   // indéfini au démontage d'un rechargement
            property bool progress: false
            property string copied: ""   // noms du titre ; d'autres (opération suivante, même fenêtre) : dossier cherché à nouveau
            property string destination: ""   // chemin du dossier d'arrivée, si trouvé (bouton « Open folder »)
            readonly property bool question: nemo && (title === "" || title === root.conflictTitle)
            property Process notifier: null
            readonly property bool active: modelData?.activated ?? false
            // Notification fermée (par toi, ou par « Show ») : pas de nouvelle avant que tu repasses par la question.
            property bool notified: false

            onNotifierChanged: {
                if (!notifier)
                    notified = true;
            }
            onActiveChanged: {
                if (active)
                    notified = false;
            }

            function percent(): bool {
                return /^\d+\s?%/.test(title);
            }

            onTitleChanged: {
                if (!nemo || !percent())
                    return;
                progress = true;
                const names = root.names(title).join("\n");
                if (names !== copied) {
                    copied = names;
                    destination = "";
                }
                if (names !== "" && destination === "" && !openFiles.running)
                    openFiles.running = true;
            }

            // Fichiers ouverts en écriture par Nemo pendant la copie (pas la source, qui peut être dans un dossier du même nom) :
            // le titre ne donne que le nom du dossier d'arrivée.
            readonly property Process openFiles: Process {
                command: ["sh", "-c", "cd /proc/$(pgrep -xo nemo)/fdinfo && awk '/^flags:/ && /[12]$/ { print \"../fd/\" FILENAME }' * 2>/dev/null | xargs -r readlink 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: watch.destination = root.destinationIn(text.split("\n"), watch.title)
                }
            }
            Component.onCompleted: progress = nemo && percent()
            onQuestionChanged: {
                if (!question)
                    notifier?.signal(2);   // SIGINT : notify-send ferme sa notification
            }
            Component.onDestruction: {
                notifier?.signal(2);
                if (progress) {
                    const [source, target] = root.names(title);
                    const body = `All file operations are finished\n${Notifs.escapeMarkup(target ? `${source} → ${target}` : root.status(title))}`;
                    if (destination === "")
                        Quickshell.execDetached([...root.notify, "--", root.summary, body]);
                    else
                        finishedNotifier.createObject(root, { body: body, folder: destination }).running = true;
                }
            }

            readonly property Timer wait: Timer {
                running: watch.question && !watch.active && !watch.notifier && !watch.notified
                interval: root.questionDelay
                onTriggered: {
                    watch.notifier = questionNotifier.createObject(root, { window: watch.modelData });
                    watch.notifier.running = true;
                }
            }
        }
    }

    // Possédé par le singleton : survit à la fenêtre, le temps que notify-send ferme sa notification.
    // Fin avec bouton « Open folder » (le dossier d'arrivée, dans le gestionnaire de fichiers).
    Component {
        id: finishedNotifier

        Process {
            id: finished

            property string body
            property string folder

            command: [...root.notify, "--wait", "--action=open=Open folder", "--", root.summary, body]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "open")
                        Places.open(finished.folder);
                    finished.destroy();
                }
            }
        }
    }

    Component {
        id: questionNotifier

        Process {
            id: process

            property Toplevel window

            command: [...root.notify, "--urgency=critical", "--wait", "--action=default=Show", "--", "Nemo", "Waiting for your answer"]
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
