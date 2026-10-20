pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NordVPN (module natif du tray, remplace l'icône de norduserd ; ARCHITECTURE § 11.4). Aucune API : commande `nordvpn`,
// statut relu toutes les 5 s et après chaque action. Masqué si `nordvpn` est absent ou si tu n'es pas connecté au compte
// (revérifié toutes les 30 s).
// Format lu (nordvpn 5.4) : lignes « Clé: valeur » (Status, Server, Hostname, Country, City, Current technology, Transfer, Uptime).
Singleton {
    id: root

    property bool available: false
    property var status: ({})
    readonly property string state: status["Status"] ?? ""
    readonly property bool connected: state === "Connected"
    readonly property bool paused: state === "Paused"
    readonly property bool connecting: state === "Connecting" || doing === "connect"
    readonly property bool busy: action.busy
    // Action lancée d'ici et pas encore finie : "connect", "disconnect", "pause" ou "".
    readonly property string doing: action.busy ? lastAction : ""
    property string lastAction: ""
    // Cible de la connexion demandée d'ici ([pays] ou [pays, ville]), gardée jusqu'à la connexion (retenue dans les récents)
    // ou l'échec de la commande ; null pour le serveur recommandé ou une connexion faite ailleurs.
    property var requested: null
    property var countries: []
    readonly property bool countriesLoading: countriesProcess.running
    property var cities: ({})    // pays → villes, chargées à la demande (un échec n'est pas gardé : nouvel essai à la demande suivante)
    readonly property string citiesLoading: citiesProcess.running ? citiesProcess.country : pendingCities

    // Derniers pays utilisés, du plus récent au plus ancien (ta demande du 2026-10-16) : NordVPN ne garde pas d'historique,
    // chaque connexion observée (panneau, raccourci, ligne de commande) est enregistrée dans l'état local de Quickshell
    // (~/.local/state/quickshell/…/vpn.json, propre à la machine, hors du dépôt ; lu et écrit par JsonAdapter).
    // Une entrée par pays : « Netherlands », ou « Netherlands/Amsterdam » si la ville a été choisie (ta demande du 2026-10-20).
    readonly property int recentCount: 5
    readonly property var recent: recentJson.recent
    property bool recentLoaded: false   // l'historique n'est modifié qu'après lecture du fichier (sinon il serait écrasé)
    onStatusChanged: remember()
    onRecentLoadedChanged: remember()

    // Pendant une action, le statut peut encore être l'ancien (changement de ville) : rien n'est retenu avant sa fin.
    // Statut lu directement : appelée depuis onStatusChanged, la liaison `connected` peut ne pas être encore à jour.
    function remember(): void {
        const country = status["Country"];
        if (!recentLoaded || status["Status"] !== "Connected" || !country || busy)
            return;
        const key = country.replace(/ /g, "_");
        // Connexion demandée d'ici : son choix (pays seul ou ville). Sinon (raccourci, ligne de commande, fin de pause,
        // redémarrage de Quickshell, demande par code pays) : l'entrée déjà retenue pour ce pays, ville comprise.
        let entry = recent.find(e => entryCountry(e) === key) ?? key;
        if (requested && requested[0].toLowerCase() === key.toLowerCase()) {
            entry = requested.length > 1 ? `${key}/${requested[1]}` : key;
            requested = null;
        }
        if (recent[0] === entry)
            return;
        recentJson.recent = [entry, ...recent.filter(e => entryCountry(e) !== key)].slice(0, recentCount);
    }

    function entryCountry(entry: string): string {
        return entry.split("/")[0];
    }

    FileView {
        path: Quickshell.statePath("vpn.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.recentLoaded = true
        onLoadFailed: root.recentLoaded = true   // pas encore d'historique : le fichier sera créé à la première connexion

        JsonAdapter {
            id: recentJson
            property list<string> recent: []
        }
    }

    // Icône du tray, celles du paquet nordvpn : bleue connecté, grise sinon.
    readonly property string icon: connected ? "nordvpn-tray-blue" : "nordvpn-tray-gray"

    // Lecture déjà en cours (lecture périodique) : refaite à sa fin, sinon l'effet d'une action qui vient de finir ne serait
    // vu qu'à la lecture suivante.
    property bool refreshAgain: false

    function refresh(): void {
        if (statusProcess.running)
            refreshAgain = true;
        else
            statusProcess.running = true;
    }

    // Renvoie faux si une autre action est en cours (rien n'est lancé).
    function run(args: var): bool {
        if (!action.run(args))
            return false;
        lastAction = args[0];
        requested = null;
        return true;
    }

    // Connexion : serveur recommandé, pays, ou « pays ville ».
    function connect(target: var): void {
        if (run(["connect", ...(target ?? [])]))
            requested = target?.length > 0 ? target : null;
    }

    // Reconnexion (interrupteur) : dernière entrée des récents (pays, ou pays et ville), serveur recommandé s'il n'y a pas
    // d'historique (ta demande du 2026-10-16).
    function connectLast(): void {
        connect(recent.length > 0 ? recent[0].split("/") : []);
    }

    function disconnect(): void {
        run(["disconnect"]);
    }

    // Pause : 5m, 15m, 30m, 1h, 24h.
    function pause(duration: string): void {
        run(["pause", duration]);
    }

    // Raccourcis (phase 10 ; aujourd'hui `$mod+u` = `nordvpn c Netherlands`, `$mod+i` = `nordvpn d`) : `qs ipc call vpn …`.
    IpcHandler {
        target: "vpn"

        // Pays donné (ex. "Netherlands"), sinon le dernier pays utilisé, comme l'interrupteur du panneau.
        function connect(country: string): void {
            if (country !== "")
                root.connect([country]);
            else
                root.connectLast();
        }

        function disconnect(): void {
            root.disconnect();
        }
    }

    // Liste vide (jamais chargée, ou échec : démon pas prêt, pas de réseau) : rechargée à chaque ouverture du panneau.
    function loadCountries(): void {
        if (countries.length === 0)
            countriesProcess.running = true;
    }

    // Villes demandées pendant qu'une autre liste se charge : chargées ensuite (seule la dernière demande compte).
    property string pendingCities: ""

    function loadCities(country: string): void {
        if (cities[country] !== undefined)
            return;
        if (citiesProcess.running) {
            pendingCities = country;
            return;
        }
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
        onRunningChanged: {
            if (!running && root.refreshAgain) {
                root.refreshAgain = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    // Statut toutes les 5 s ; module masqué (démon pas encore prêt à l'ouverture de session, compte connecté plus tard) :
    // nouvel essai toutes les 30 s, sans quoi il resterait masqué jusqu'au prochain rechargement.
    Timer {
        interval: root.available ? 5000 : 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Actions (connect, disconnect, pause) : une à la fois ; erreur en notification.
    CliRunner {
        id: action
        program: "nordvpn"
        probe: false   // présence et compte : lus par `nordvpn status`
        onFinished: {
            if (error !== "") {
                root.requested = null;
                Quickshell.execDetached(["notify-send", "--app-name=NordVPN", "NordVPN", error]);
            }
            root.refresh();
        }
    }

    // Listes lues seulement si la commande réussit : en cas d'erreur, des mots du message (« Cannot reach System Daemon »)
    // passeraient pour des noms de pays et resteraient en cache.
    Process {
        id: countriesProcess
        command: ["nordvpn", "countries"]
        stdout: StdioCollector {
            id: countriesOut
        }
        onExited: code => {
            if (code === 0)
                root.countries = root.names(countriesOut.text);
        }
    }

    Process {
        id: citiesProcess
        property string country: ""
        stdout: StdioCollector {
            id: citiesOut
        }
        onExited: code => {
            if (code === 0) {
                const copy = Object.assign({}, root.cities);
                copy[citiesProcess.country] = root.names(citiesOut.text);
                root.cities = copy;
            }
            const next = root.pendingCities;
            root.pendingCities = "";
            if (next !== "")
                Qt.callLater(() => root.loadCities(next));
        }
    }
}
