pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NordVPN (module natif du tray, remplace l'icône de norduserd ; ARCHITECTURE § 11.4). Aucune API : commande `nordvpn`,
// statut relu toutes les 5 s et après chaque action. Masqué si `nordvpn` est absent ou si tu n'es pas connecté au compte.
// Format lu (nordvpn 5.4) : lignes « Clé: valeur » (Status, Server, Hostname, Country, City, Current technology, Transfer, Uptime).
Singleton {
    id: root

    property bool available: false
    property var status: ({})
    readonly property string state: status["Status"] ?? ""
    readonly property bool connected: state === "Connected"
    readonly property bool paused: state === "Paused"
    readonly property bool connecting: state === "Connecting" || busy
    property bool busy: false
    property var countries: []
    property var cities: ({})    // pays → villes, chargées à la demande

    // Derniers pays utilisés, du plus récent au plus ancien (ta demande du 2026-10-16) : NordVPN ne garde pas d'historique,
    // chaque connexion observée (panneau, raccourci, ligne de commande) est enregistrée dans l'état local de Quickshell
    // (~/.local/state/quickshell/…/vpn-recent.json, propre à la machine, hors du dépôt).
    readonly property int recentCount: 5
    property var recent: []
    property bool recentLoaded: false   // l'historique n'est modifié qu'après lecture du fichier (sinon il serait écrasé)
    onStatusChanged: remember()
    onRecentLoadedChanged: remember()

    function remember(): void {
        const country = status["Country"];
        if (!recentLoaded || !connected || !country)
            return;
        const key = country.replace(/ /g, "_");
        if (recent[0] === key)
            return;
        recent = [key, ...recent.filter(c => c !== key)].slice(0, recentCount);
        recentFile.setText(JSON.stringify(recent));
    }

    FileView {
        id: recentFile
        path: Quickshell.statePath("vpn-recent.json")
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list))
                    root.recent = list.slice(0, root.recentCount);
            } catch (e) {}
            root.recentLoaded = true;
        }
        onLoadFailed: root.recentLoaded = true   // pas encore d'historique
    }

    // Icône du tray, celles du paquet nordvpn : bleue connecté, grise sinon.
    readonly property string icon: connected ? "nordvpn-tray-blue" : "nordvpn-tray-gray"

    function refresh(): void {
        statusProcess.running = true;
    }

    function run(args: var): void {
        if (busy)
            return;
        busy = true;
        action.command = ["nordvpn", ...args];
        action.running = true;
    }

    // Connexion : serveur recommandé, pays, ou « pays ville ».
    function connect(target: var): void {
        run(["connect", ...(target ?? [])]);
    }

    // Reconnexion (interrupteur) : dernier pays utilisé, serveur recommandé s'il n'y a pas d'historique (ta demande du 2026-10-16).
    function connectLast(): void {
        connect(recent.length > 0 ? [recent[0]] : []);
    }

    function disconnect(): void {
        run(["disconnect"]);
    }

    // Pause : 5m, 15m, 30m, 1h, 24h.
    function pause(duration: string): void {
        run(["pause", duration]);
    }

    function loadCountries(): void {
        if (countries.length === 0)
            countriesProcess.running = true;
    }

    function loadCities(country: string): void {
        if (cities[country] !== undefined || citiesProcess.running)
            return;
        citiesProcess.country = country;
        citiesProcess.command = ["nordvpn", "cities", country];
        citiesProcess.running = true;
    }

    function names(text: string): var {
        return text.split(/[\s,]+/).map(s => s.trim()).filter(s => /^[A-Z][\w-]*$/.test(s));
    }

    Process {
        id: statusProcess
        command: ["nordvpn", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^\s*([^:]+):\s*(.*)$/);
                    if (m)
                        result[m[1].trim()] = m[2].trim();
                }
                root.available = result["Status"] !== undefined && !/not logged in/i.test(text);
                root.status = result;
            }
        }
        onExited: code => {
            if (code !== 0)
                root.available = false;
        }
    }

    Timer {
        interval: 5000
        running: root.available
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: action
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: actionErrors
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "--app-name=NordVPN", "NordVPN", actionErrors.text.trim() || "Command failed"]);
            root.refresh();
        }
    }

    Process {
        id: countriesProcess
        command: ["nordvpn", "countries"]
        stdout: StdioCollector {
            onStreamFinished: root.countries = root.names(text)
        }
    }

    Process {
        id: citiesProcess
        property string country: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const copy = Object.assign({}, root.cities);
                copy[citiesProcess.country] = root.names(text);
                root.cities = copy;
            }
        }
    }
}
