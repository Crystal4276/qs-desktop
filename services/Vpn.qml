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
    readonly property string country: status["Country"] ?? ""
    readonly property string city: status["City"] ?? ""
    readonly property bool connecting: state === "Connecting" || doing === "connect"
    // Action en cours, jusqu'à la première lecture du statut qui la suit (sinon l'état d'avant reviendrait un instant).
    readonly property bool busy: action.busy || awaitingStatus
    property bool awaitingStatus: false
    readonly property int actionTimeout: 300   // s
    // Action lancée d'ici et pas encore finie : "connect", "disconnect", "pause" ou "".
    readonly property string doing: busy ? lastAction : ""
    property string lastAction: ""
    // Cible de la connexion lancée d'ici ([pays] ou [pays, ville]), jusqu'au statut qui la suit ; null : serveur recommandé.
    property var requested: null
    property var countries: []
    readonly property bool countriesLoading: countriesProcess.running
    property var cities: ({})    // pays → villes, chargées à la demande (un échec n'est pas gardé : nouvel essai à la demande suivante)
    // Pays dont les villes se chargent ou attendent leur tour (une seule liste dépliée : la dernière demandée).
    readonly property string citiesLoading: pendingCities !== "" ? pendingCities : citiesProcess.running ? citiesProcess.country : ""

    // Derniers pays utilisés, du plus récent au plus ancien (ta demande du 2026-10-16) : NordVPN ne garde pas d'historique,
    // chaque connexion observée (panneau, raccourci, ligne de commande) est enregistrée dans l'état local de Quickshell
    // (~/.local/state/quickshell/…/vpn.json, propre à la machine, hors du dépôt ; lu et écrit par JsonAdapter).
    // Une entrée par pays : « Netherlands », ou « Netherlands/Amsterdam » si la ville a été choisie (ta demande du 2026-10-20).
    // Pays écrits comme dans `nordvpn countries` dès que la liste est connue (countryKey).
    readonly property int recentCount: 5
    readonly property var recent: recentJson.recent
    property bool recentLoaded: false   // l'historique n'est modifié qu'après lecture du fichier (sinon il serait écrasé)
    onStatusChanged: remember()
    onRecentLoadedChanged: remember()

    // Entrée mise en tête des récents, à la place de celle du même pays (orthographe éventuellement différente).
    function push(entry: string): void {
        if (!recentLoaded || recent[0] === entry)
            return;
        const country = entryCountry(entry);
        recentJson.recent = [entry, ...recent.filter(e => !sameName(entryCountry(e), country))].slice(0, recentCount);
    }

    // Connexion réussie lancée d'ici (panneau, interrupteur, `qs ipc`) : son choix, pays seul ou ville. Pays connu seulement
    // (de la liste, ou des récents si elle n'est pas lue) ; un code pays, « nl », est laissé à remember() : pays seul.
    function record(target: var): void {
        const country = countries.find(c => sameName(c, target[0])) ?? recent.map(entryCountry).find(c => sameName(c, target[0]));
        if (country)
            push(target.length > 1 ? `${country}/${target[1]}` : country);
    }

    // Connexion observée (raccourci direct, ligne de commande, fin de pause, redémarrage de Quickshell) : l'entrée déjà retenue
    // pour ce pays, avec sa ville si c'est celle de la connexion (une autre ville choisie ailleurs : pays seul). Rien pendant
    // une action d'ici : le statut peut encore être l'ancien, et record() retient son choix à la fin.
    // Statut lu directement : appelée depuis onStatusChanged, la liaison `connected` peut ne pas être encore à jour.
    function remember(): void {
        const country = status["Country"];
        if (status["Status"] !== "Connected" || !country || busy)
            return;
        const key = countryKey(country);
        const found = recent.find(e => sameName(entryCountry(e), key));
        const city = found ? entryCity(found) : "";
        push(city !== "" && sameName(city, status["City"] ?? "") ? `${key}/${city}` : key);
    }

    // Pays tel qu'écrit dans `nordvpn countries` (clé des récents, des villes et du panneau), sinon celui du statut.
    function countryKey(name: string): string {
        return countries.find(c => sameName(c, name)) ?? name.replace(/ /g, "_");
    }

    // Entrée des récents « Pays » ou « Pays/Ville » : pays, ville ("" sans ville), cible de `connect`.
    function entryCountry(entry: string): string {
        return entry.split("/")[0];
    }

    function entryCity(entry: string): string {
        return entry.split("/")[1] ?? "";
    }

    function entryTarget(entry: string): var {
        return entry.split("/");
    }

    // Noms NordVPN : « United_States » (listes, commandes) ou « United States » (statut, affichage), casse libre en ligne de
    // commande.
    function label(name: string): string {
        return name.replace(/_/g, " ");
    }

    function sameName(a: string, b: string): bool {
        return a.toLowerCase().replace(/ /g, "_") === b.toLowerCase().replace(/ /g, "_");
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
    // vu qu'à la lecture suivante. (Pas pour la lecture périodique elle-même : avec un démon lent, les lectures s'enchaîneraient.)
    property bool refreshAgain: false

    function refresh(): void {
        if (action.busy)   // résultat ignoré ; la lecture qui suit l'action est demandée à sa fin
            return;
        if (statusProcess.running)
            refreshAgain = true;
        else
            readStatus();
    }

    // Lecture commencée pendant une action, ou avant la dernière : résultat ignoré (statut ancien ; la relecture qui suit
    // l'action le remplace), sinon l'ancienne connexion reviendrait un instant et dans les récents.
    property int actionCount: 0

    function readStatus(): void {
        statusProcess.stamp = actionCount;
        statusProcess.running = true;
    }

    // Renvoie faux si une autre action est en cours (rien n'est lancé).
    function run(args: var): bool {
        if (action.busy)   // (après l'action, l'attente du statut ne bloque pas un raccourci)
            return false;
        lastAction = args[0];   // avant `busy` : `doing` ne prend jamais le nom de l'action précédente
        requested = null;
        actionCount++;
        // Bornée, large (une connexion lente aboutit) : une commande figée garderait `busy` (panneau verrouillé) jusqu'au
        // redémarrage de Quickshell.
        return action.runCommand(["timeout", String(actionTimeout), "nordvpn", ...args]);
    }

    // Connexion : serveur recommandé, pays, ou « pays ville ».
    function connect(target: var): void {
        if (run(["connect", ...(target ?? [])]))
            requested = target?.length > 0 ? target : null;
    }

    // Reconnexion (interrupteur) : dernière entrée des récents (pays, ou pays et ville), serveur recommandé s'il n'y a pas
    // d'historique (ta demande du 2026-10-16).
    function connectLast(): void {
        connect(recent.length > 0 ? entryTarget(recent[0]) : []);
    }

    // Pendant une connexion (figée, trop longue) : l'annule, à côté de la commande en cours.
    function disconnect(): void {
        if (action.busy && lastAction === "connect")
            cancel.runCommand(["timeout", "30", "nordvpn", "disconnect"]);
        else
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
        // Une demande attend déjà son tour (lancée au prochain tour de boucle) : celle-ci la remplace.
        if (citiesProcess.running || pendingCities !== "") {
            pendingCities = country;
            return;
        }
        citiesProcess.country = country;
        citiesProcess.command = ["timeout", "10", "nordvpn", "cities", country];
        citiesProcess.running = true;
    }

    // Noms des listes (un par ligne, ou séparés par des virgules) ; une ligne qui contient autre chose (« A new version of
    // NordVPN is available! ») est ignorée entière ; indicateur de progression (« \r-\r ») retiré.
    function names(text: string): var {
        return text.split("\n").map(l => l.split(/[\s,]+/).filter(w => w !== "" && !/^[-\\|\/]+$/.test(w)))
            .filter(words => words.length > 0 && words.every(w => /^[A-Z][\w-]*$/.test(w)))
            .reduce((all, words) => all.concat(words), []);
    }

    Process {
        id: statusProcess
        property int stamp: 0
        command: ["timeout", "10", "nordvpn", "status"]   // bornées : démon figé
        running: true
        stdout: StdioCollector {
            id: statusOut
        }
        // Lecture ancienne (stamp) ou trop lente (124 : démon occupé) : rien n'est changé, le module ne disparaît pas.
        onExited: code => {
            // Pas de réponse après une action : elle reste « en cours » (l'état d'avant n'est pas montré comme actuel) ;
            // la lecture périodique réessaie.
            if (stamp !== root.actionCount || code === 124)
                return;
            root.awaitingStatus = false;   // avant `status` : remember() voit l'action finie
            root.requested = null;
            const text = statusOut.text;
            const result = {};
            for (const line of text.split("\n")) {
                const m = line.match(/^\s*([^:]+):\s*(.*)$/);
                if (m)
                    result[m[1].trim()] = m[2].trim();
            }
            root.available = code === 0 && result["Status"] !== undefined && !/not logged in/i.test(text);
            root.status = result;
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
        onTriggered: {
            if (!statusProcess.running && !action.busy)   // pendant une action : lecture inutile (ignorée)
                root.readStatus();
        }
    }

    property bool cancelled: false

    CliRunner {
        id: cancel
        program: "nordvpn"
        probe: false
        lastLineError: true
        onFinished: {
            if (error !== "")
                Quickshell.execDetached(["notify-send", "--app-name=NordVPN", "NordVPN", error]);
            else
                root.cancelled = action.busy;
        }
    }

    // Démon qui ne répond plus après une action : verrou levé au bout de 30 s (l'état affiché peut alors être l'ancien).
    Timer {
        id: awaitLimit
        interval: 30000
        running: root.awaitingStatus
        onTriggered: {
            root.awaitingStatus = false;
            root.requested = null;
        }
    }

    // Actions (connect, disconnect, pause) : une à la fois ; erreur en notification (dernière ligne : nordvpn écrit sa
    // progression, « Connecting to … », avant l'erreur).
    CliRunner {
        id: action
        program: "nordvpn"
        probe: false   // présence et compte : lus par `nordvpn status`
        lastLineError: true
        noAnswer: `nordvpn: no answer after ${root.actionTimeout / 60} minutes`
        onFinished: {
            const cancelled = cancel.busy || root.cancelled;   // connexion annulée : ni erreur à signaler, ni choix à retenir
            root.cancelled = false;
            if (error !== "" && !cancelled)
                Quickshell.execDetached(["notify-send", "--app-name=NordVPN", "NordVPN", error]);
            else if (error === "" && !cancelled && root.lastAction === "connect" && root.requested)
                root.record(root.requested);
            root.awaitingStatus = true;   // `requested` gardé jusque-là (« Connecting to … »)
            root.refresh();
        }
    }

    // Listes lues seulement si la commande réussit : en cas d'erreur, des mots du message (« Cannot reach System Daemon »)
    // passeraient pour des noms de pays et resteraient en cache.
    Process {
        id: countriesProcess
        command: ["timeout", "10", "nordvpn", "countries"]
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
        }
        // Demande en attente : lancée à l'arrêt de celle-ci (même si elle n'a pas pu démarrer : pas d'`exited`), gardée jusque-là
        // (affichée « Loading cities… », pas « unavailable »).
        onRunningChanged: {
            if (!running && root.pendingCities !== "")
                Qt.callLater(() => {
                    const next = root.pendingCities;
                    root.pendingCities = "";
                    root.loadCities(next);
                });
        }
    }
}
