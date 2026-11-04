pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.config

// Écran de connexion (greeter.qml, modules/greeter ; ARCHITECTURE § 9) : utilisateurs, sessions, dernier choix, dialogue avec greetd.
//  - utilisateurs : comptes de /etc/passwd (UID 1000 à 59999, sans shell nologin / false) ; le dernier connecté d'abord ;
//  - sessions : fichiers .desktop de `wayland-sessions` puis `xsessions` (XDG_DATA_DIRS ; X11 seulement si `startx` est là), sans
//    ceux dont `TryExec` manque ;
//    la dernière de l'utilisateur, sinon `greeter.defaultSession` de la config machine (« wayland/sway »), sinon la première ;
//  - connexion : greetd demande le mot de passe (PAM, /etc/pam.d/greetd), puis lance la session par scripts/greeter-session.sh
//    (shell de connexion de l'utilisateur, comme SDDM ; X11 par startx) et Quickshell s'arrête.
// Dernier utilisateur et dernière session : `<dir>/greeter/state.json` ; fonds d'écran du bureau : `<dir>/<utilisateur>/`
// (Wallpapers.greeterDir). Dossiers créés par scripts/greeter-setup.sh.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("QS_GREETER_DIR") ?? "/var/lib/qs-desktop"

    // --- Utilisateurs ---
    readonly property var users: {
        const shells = /(nologin|false)$/;
        return passwd.text().split("\n").map(l => l.split(":")).filter(f => {
            const uid = Number(f[2]);
            return f.length >= 7 && uid >= 1000 && uid < 60000 && !shells.test(f[6]);   // shell vide : /bin/sh
        }).map(f => f[0]);
    }
    property int userIndex: 0
    readonly property string user: users[userIndex] ?? ""

    function nextUser(): void {
        if (users.length > 1 && !checking)
            userIndex = (userIndex + 1) % users.length;
    }

    // --- Sessions : [{ key: "wayland/<id>" | "x11/<id>", id, name, exec, desktopNames, x11 }] ---
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] ?? null

    function cycleSession(step: int): void {
        if (sessions.length > 0)
            sessionIndex = (sessionIndex + step + sessions.length) % sessions.length;
    }

    // Session de l'utilisateur affiché : sa dernière, sinon celle de la config machine, sinon la première.
    function pickSession(): void {
        const wanted = [state.sessions?.[user], Settings.greeter.defaultSession];
        for (const key of wanted) {
            const i = sessions.findIndex(s => s.key === key);
            if (i >= 0) {
                sessionIndex = i;
                return;
            }
        }
        sessionIndex = 0;
    }

    onUserChanged: {
        pickSession();
        listWallpapers();
    }

    function parseSessions(text: string): void {
        const list = [];
        for (const chunk of text.split("\x1e").slice(1)) {
            const lines = chunk.split("\n");
            const path = lines[0];
            const entry = {};
            let inMain = false;
            for (const line of lines.slice(1)) {
                if (line.startsWith("["))
                    inMain = line.trim() === "[Desktop Entry]";
                else if (inMain && line.includes("=")) {
                    const k = line.slice(0, line.indexOf("=")).trim();
                    if (!(k in entry))
                        entry[k] = line.slice(line.indexOf("=") + 1).trim();
                }
            }
            if (!entry.Exec || entry.Hidden === "true" || entry.NoDisplay === "true")
                continue;
            const x11 = path.includes("/xsessions/");
            const id = path.slice(path.lastIndexOf("/") + 1).replace(/\.desktop$/, "");
            const key = `${x11 ? "x11" : "wayland"}/${id}`;
            if (list.some(s => s.key === key))
                continue;   // même session dans un dossier précédent de XDG_DATA_DIRS
            list.push({
                key: key,
                id: id,
                name: (entry.Name ?? id) + (x11 ? " (X11)" : ""),
                exec: entry.Exec.replace(/ ?%[fFuUdDnNickvm]/g, ""),   // codes de champ : sans objet pour une session
                desktopNames: (entry.DesktopNames ?? "").split(";").filter(n => n !== "").join(":"),
                x11: x11
            });
        }
        sessions = list;
        pickSession();
    }

    Process {
        running: true
        // Fichiers séparés par U+001E (chemin sur la première ligne).
        command: ["sh", "-c", `
            kinds=wayland-sessions
            command -v startx >/dev/null 2>&1 && kinds="$kinds xsessions"   # X11 : par startx (xorg-xinit)
            for kind in $kinds; do
                for d in $(echo "\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr : ' '); do
                    for f in "$d/$kind"/*.desktop; do
                        [ -f "$f" ] || continue
                        t=$(sed -n 's/^TryExec=//p' "$f" | head -n 1)
                        [ -n "$t" ] && ! command -v "$t" >/dev/null 2>&1 && continue
                        printf '\\036%s\\n' "$f"
                        cat "$f"
                    done
                done
            done`]
        stdout: StdioCollector {
            onStreamFinished: root.parseSessions(text)
        }
    }

    // --- Dernier choix ---
    property var state: ({})

    FileView {
        id: stateFile
        path: `${root.dir}/greeter/state.json`
        printErrors: false
        blockLoading: true
        blockWrites: true   // écrit avant Greetd.launch(), qui arrête Quickshell
        onLoaded: {
            try {
                root.state = JSON.parse(text()) ?? {};
            } catch (e) {
                root.state = {};
            }
            const i = root.users.indexOf(root.state.user ?? "");
            root.userIndex = Math.max(i, 0);
            root.pickSession();
        }
    }

    function saveState(): void {
        const sessions = Object.assign({}, state.sessions ?? {}, { [user]: session?.key ?? "" });
        stateFile.setText(JSON.stringify({ user: user, sessions: sessions }));
    }

    FileView {
        id: passwd
        path: "/etc/passwd"
        blockLoading: true
    }

    // Fond de l'écran `description` exporté par le bureau de l'utilisateur affiché (même nom que Wallpapers.greeterFile) ; "" s'il
    // n'y en a pas (écran inconnu du bureau, utilisateur qui n'a jamais ouvert de session) : fond uni.
    // Chemins complets : une liste en retard, lue pour le compte précédent, ne correspond jamais au compte affiché.
    property var wallpapers: []

    function wallpaper(description: string): string {
        const path = `${dir}/${user}/${Qt.md5(description)}.jpg`;
        return description !== "" && wallpapers.includes(path) ? `file://${path}` : "";
    }

    function listWallpapers(): void {
        wallpapers = [];
        if (user !== "")
            wallpaperList.exec(["sh", "-c", 'for f in "$1"/*.jpg; do [ -f "$f" ] && echo "$f"; done', "sh", `${dir}/${user}`]);
    }

    Component.onCompleted: listWallpapers()

    Process {
        id: wallpaperList
        stdout: StdioCollector {
            onStreamFinished: root.wallpapers = text.split("\n").filter(p => p !== "")
        }
    }

    // --- Connexion ---
    property string pending: ""
    property bool checking: false
    property bool error: false
    property string message: ""
    property string pamText: ""   // messages de PAM pendant la vérification, montrés si elle échoue

    function submit(password: string): void {
        if (checking || password === "" || user === "")
            return;
        if (!Greetd.available) {
            fail("greetd is not running");
            return;
        }
        if (!session) {
            fail("No session");
            return;
        }
        pending = password;
        checking = true;
        error = false;
        message = "Checking…";
        pamText = "";
        Greetd.createSession(user);
    }

    function fail(text: string): void {
        checking = false;
        pending = "";
        error = true;
        message = text;
    }

    function clearMessage(): void {
        if (!checking) {   // « Checking… » reste affiché
            error = false;
            message = "";
        }
    }

    function launch(): void {
        const s = session;
        if (!s) {   // liste vidée entre-temps : session authentifiée refermée
            Greetd.cancelSession();
            fail("No session");
            return;
        }
        saveState();
        const env = [`XDG_SESSION_TYPE=${s.x11 ? "x11" : "wayland"}`, `XDG_SESSION_DESKTOP=${s.id}`];
        if (s.desktopNames !== "")
            env.push(`XDG_CURRENT_DESKTOP=${s.desktopNames}`);
        console.info(`Greeter: ${user} → ${s.key} : ${s.exec}`);
        Greetd.launch([Quickshell.shellPath("scripts/greeter-session.sh"), s.x11 ? "x11" : "wayland", s.exec], env, true);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired) {
                // Une seule question attendue (le mot de passe) : une seconde (changement de mot de passe expiré…) est refusée.
                if (root.pending === "") {
                    Greetd.cancelSession();
                    root.fail(message.trim() !== "" ? message.trim() : "Authentication error");
                    return;
                }
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (message.trim() !== "") {
                root.pamText = (root.pamText === "" ? "" : root.pamText + " ") + message.trim();
            }
        }

        function onAuthFailure(message: string): void {
            root.fail(root.pamText !== "" ? root.pamText : "Wrong password");
        }

        function onReadyToLaunch(): void {
            root.pending = "";
            root.launch();
        }

        // Erreur de greetd (pas un refus) : Quickshell garde la session, refermée ici pour permettre un nouvel essai.
        function onError(error: string): void {
            console.warn(`Greeter: greetd: ${error}`);
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
            root.fail(error !== "" ? error : "Authentication error");
        }
    }
}
