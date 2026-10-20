pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NordVPN (module natif du tray, remplace l'icône de norduserd ; ARCHITECTURE § 11.4). Aucune API : commande `nordvpn`,
// statut relu toutes les 5 s et après chaque action. Masqué si `nordvpn` est absent ou si tu n'es pas connecté au compte
// (revérifié toutes les 30 s).
// Toutes les commandes passent par une seule file (ta demande du 2026-10-20) : une à la fois, dans l'ordre ; une lecture
// du statut voit donc toujours l'effet de l'action d'avant.
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
    // Action en attente ou en cours, jusqu'à la lecture du statut qui la suit (sinon l'état d'avant reviendrait un instant).
    readonly property bool busy: jobs.some(j => j.kind === "action" || j.follow)
    readonly property bool actionPending: jobs.some(j => j.kind === "action")
    readonly property int actionTimeout: 300   // s
    // Action lancée d'ici et pas encore finie : "connect", "disconnect", "pause" ou "".
    readonly property string doing: busy ? lastAction : ""
    property string lastAction: ""
    // Cible de la connexion lancée d'ici ([pays] ou [pays, ville]), jusqu'au statut qui la suit (retenue alors dans les
    // récents) ; effacée si la commande échoue ; null : serveur recommandé.
    property var requested: null
    property var countries: []
    readonly property bool countriesLoading: jobs.some(j => j.kind === "countries")
    property var cities: ({})    // pays → villes, chargées à la demande (un échec n'est pas gardé : nouvel essai à la demande suivante)
    // Pays dont les villes se chargent ou attendent leur tour (une seule liste dépliée : la dernière demandée).
    readonly property string citiesLoading: jobs.filter(j => j.kind === "cities").map(j => j.country).pop() ?? ""

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

    property string rememberedHost: ""   // serveur de la dernière connexion retenue

    // Connexion lancée d'ici et confirmée par le statut (même pays) : son choix, pays seul ou ville (orthographe de la liste
    // des villes). Sinon (raccourci direct, ligne de commande, fin de pause, redémarrage de Quickshell, code pays), à chaque
    // nouveau serveur : l'entrée déjà retenue pour ce pays, avec sa ville si c'est celle de la connexion, sinon le pays seul.
    // Rien pendant une action : le statut peut encore être l'ancien.
    // Statut lu directement : appelée depuis onStatusChanged, la liaison `connected` peut ne pas être encore à jour.
    function remember(): void {
        const country = status["Country"];
        if (busy || !recentLoaded)   // (relancée au chargement de l'historique)
            return;
        if (status["Status"] !== "Connected" || !country) {
            rememberedHost = "";
            return;
        }
        const host = status["Hostname"] ?? "";
        if (!requested && host === rememberedHost)   // (le plus souvent : même connexion, rien à faire)
            return;
        const key = countryKey(country);
        if (requested && sameName(requested[0], key)) {
            rememberedHost = host;
            push(requested.length > 1 ? `${key}/${requested[1]}` : key);
            return;
        }
        if (host === rememberedHost)
            return;
        rememberedHost = host;
        const found = recent.find(e => sameName(entryCountry(e), key));
        const city = found ? entryCity(found) : "";
        push(city !== "" && sameName(city, status["City"] ?? "") ? `${key}/${city}` : key);
    }

    // Pays tel qu'écrit dans `nordvpn countries` (clé des récents, des villes et du panneau), sinon dans les récents, sinon tel
    // quel.
    function countryKey(name: string): string {
        return countries.find(c => sameName(c, name)) ?? recent.map(entryCountry).find(c => sameName(c, name)) ?? name.replace(/ /g, "_");
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

    // File : tâches { kind: "status" | "countries" | "cities" | "action", args, timeout (s), country (villes), follow
    // (lecture qui suit une action), quiet (déconnexion sans message « not connected ») }. Bornées par `timeout` : une
    // commande figée bloquerait la file.
    property var queue: []      // en attente
    property var current: null  // en cours
    readonly property var jobs: current ? [current, ...queue] : queue

    function statusJob(follow: bool): var {
        return { kind: "status", args: ["status"], timeout: 10, follow };
    }

    // Action bornée large (une connexion lente aboutit).
    function actionJob(args: var, quiet: bool): var {
        return { kind: "action", args, timeout: actionTimeout, quiet };
    }

    function enqueue(job: var): void {
        queue = [...queue, job];
        Qt.callLater(next);
    }

    // Lancée au tour suivant : la commande d'avant n'a pas fini de signaler sa fin.
    function next(): void {
        if (current || queue.length === 0)
            return;
        current = queue[0];   // avant de la retirer : `busy` ne retombe pas entre les deux
        queue = queue.slice(1);
        // `-k` : commande qui ignore SIGTERM tuée 5 s plus tard (sinon elle bloquerait la file pour la session) ; laisse aussi
        // 5 s à une connexion arrêtée par SIGINT pour se terminer proprement (disconnect()).
        cli.runCommand(["timeout", "-k", "5", String(current.timeout), "nordvpn", ...current.args]);
    }

    property int timeouts: 0   // lectures du statut sans réponse, de suite

    // Statut relu, sauf s'il l'est déjà ou si une action attend ou tourne (la lecture qui la suit suffit).
    function refresh(): void {
        if (!jobs.some(j => j.kind === "status" || j.kind === "action"))
            enqueue(statusJob(false));
    }

    // Renvoie faux si une autre action attend ou tourne (rien n'est lancé).
    function run(args: var, quiet: bool): bool {
        if (actionPending || cancelling)   // (après l'action, l'attente du statut ne bloque pas un raccourci)
            return false;
        lastAction = args[0];   // avant `busy` : `doing` ne prend jamais le nom de l'action précédente
        requested = null;
        // En tête de file : n'attend que la commande en cours (au plus 10 s pour une lecture). Lecture du statut en attente :
        // remplacée par celle qui suit l'action.
        queue = [actionJob(args, quiet), ...queue.filter(j => j.kind !== "status")];
        Qt.callLater(next);
        return true;
    }

    // Connexion : serveur recommandé, pays, ou « pays ville ». Faux si refusée (autre action en cours).
    function connect(target: var): bool {
        if (!run(["connect", ...(target ?? [])], false))
            return false;
        requested = target?.length > 0 ? target : null;
        return true;
    }

    // Reconnexion (interrupteur) : dernière entrée des récents (pays, ou pays et ville), serveur recommandé s'il n'y a pas
    // d'historique (ta demande du 2026-10-16).
    function connectLast(): bool {
        return connect(recent.length > 0 ? entryTarget(recent[0]) : []);
    }

    // Pendant une connexion (figée, trop longue) : elle est arrêtée, puis la déconnexion suit (finish()) ;
    // « Disconnecting… » dès maintenant. Connexion encore en attente (une liste se charge) : retirée de la file.
    property bool cancelling: false
    readonly property bool cancellable: jobs.some(j => j.kind === "action" && j.args[0] === "connect") && !cancelling

    function disconnect(): bool {
        const waiting = queue.find(j => j.kind === "action");
        if (waiting?.args[0] === "connect") {
            queue = queue.filter(j => j !== waiting);
            return run(["disconnect"], true);   // (déjà déconnecté : pas de message)
        }
        if (!cancellable)
            return run(["disconnect"], false);
        cancelling = true;
        lastAction = "disconnect";
        requested = null;
        cli.interrupt();
        cancelFallback.restart();
        return true;
    }

    // Pause : 5m, 15m, 30m, 1h, 24h.
    function pause(duration: string): void {
        run(["pause", duration], false);
    }

    function busyNotice(): void {
        Quickshell.execDetached(["notify-send", "--app-name=NordVPN", "NordVPN", "Busy: another action is running"]);
    }

    // Raccourcis (phase 10 ; aujourd'hui `$mod+u` = `nordvpn c Netherlands`, `$mod+i` = `nordvpn d`) : `qs ipc call vpn …`.
    IpcHandler {
        target: "vpn"

        // Pays donné (ex. "Netherlands"), sinon le dernier pays utilisé, comme l'interrupteur du panneau. Refusé pendant
        // une autre action : dit par une notification.
        function connect(country: string): void {
            if (!(country !== "" ? root.connect([country]) : root.connectLast()))
                root.busyNotice();
        }

        function disconnect(): void {
            if (!root.disconnect())
                root.busyNotice();
        }
    }

    // Liste vide (jamais chargée, ou échec : démon pas prêt, pas de réseau) : rechargée à chaque ouverture du panneau.
    function loadCountries(): void {
        if (countries.length === 0 && !countriesLoading)
            enqueue({ kind: "countries", args: ["countries"], timeout: 10 });
    }

    // Une seule liste de villes attend son tour : la dernière demandée.
    function loadCities(country: string): void {
        if (cities[country] !== undefined || queue.some(j => j.kind === "cities" && j.country === country))
            return;
        queue = queue.filter(j => j.kind !== "cities");
        if (current?.kind !== "cities" || current.country !== country)
            enqueue({ kind: "cities", args: ["cities", country], timeout: 10, country });
    }

    // Noms des listes (un par ligne, ou séparés par des virgules) ; une ligne qui contient autre chose (« A new version of
    // NordVPN is available! ») est ignorée entière ; indicateur de progression (« \r-\r ») retiré.
    function names(text: string): var {
        return text.split("\n").map(l => l.split(/[\s,]+/).filter(w => w !== "" && !/^[-\\|\/]+$/.test(w)))
            .filter(words => words.length > 0 && words.every(w => /^[A-Z][\w-]*$/.test(w)))
            .reduce((all, words) => all.concat(words), []);
    }

    // Tâches qui suivent celle qui finit, en tête de file : après une action, la lecture du statut (ou, après une connexion
    // arrêtée, la déconnexion) ; lecture qui suit une action sans réponse (démon occupé) : refaite, trois fois au plus, sauf
    // si une autre action attend (sa propre lecture la remplace).
    function followUps(job: var, code: int): var {
        if (job.kind === "status")
            return job.follow && code === 124 && timeouts < 3 && !queue.some(j => j.kind === "action") ? [job] : [];
        if (job.kind !== "action")
            return [];
        return cancelling ? [actionJob(["disconnect"], true)] : [statusJob(true)];
    }

    function finish(): void {
        const job = current;
        const code = cli.code;
        if (job.kind === "status")
            timeouts = code === 124 ? timeouts + 1 : 0;
        queue = [...followUps(job, code), ...queue];   // avant la fin de `current` : `busy` ne retombe pas entre les deux
        current = null;
        if (job.kind === "status")
            statusRead(code, cli.output);
        else if (job.kind === "action")
            actionDone(job);
        else if (job.kind === "countries" && code === 0)
            countries = names(cli.output);
        else if (job.kind === "cities")
            citiesRead(job.country, code === 0 ? names(cli.output) : []);
        Qt.callLater(next);
    }

    // Lecture trop lente (124 : démon occupé) : rien n'est changé, le module ne disparaît pas ; démon figé (trois lectures de
    // suite sans réponse) : module masqué, comme sans démon. `requested` gardé si une action attend : c'est la sienne
    // (lecture commencée avant elle).
    function statusRead(code: int, text: string): void {
        if (timeouts >= 3) {
            available = false;
            if (!actionPending)
                requested = null;
        }
        if (code === 124)
            return;
        const result = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^\s*([^:]+):\s*(.*)$/);
            if (m)
                result[m[1].trim()] = m[2].trim();
        }
        available = code === 0 && result["Status"] !== undefined && !/not logged in/i.test(text);
        status = result;   // remember() : `requested` n'a de sens que jusqu'à la fin de la connexion
        if (result["Status"] !== "Connecting" && !actionPending)
            requested = null;
    }

    // Erreur en notification (dernière ligne : nordvpn écrit sa progression, « Connecting to … », avant l'erreur) ; échec :
    // ni cible retenue, ni « Connecting to … » jusqu'à la lecture du statut (l'état affiché est l'actuel). Connexion arrêtée
    // (disconnect()) : ni erreur ni choix à retenir.
    function actionDone(job: var): void {
        if (cancelling) {
            cancelling = false;   // jusque-là, run() refuse toute autre action (raccourci)
            return;
        }
        const error = cli.error;
        if (error === "")
            return;
        if (!(job.quiet && /not connected/i.test(error)))
            Quickshell.execDetached(["notify-send", "--app-name=NordVPN", "NordVPN", error]);
        requested = null;
        lastAction = "";
    }

    // Liste vide (« Cities unavailable », échec) : pas gardée, nouvel essai à la demande suivante.
    function citiesRead(country: string, list: var): void {
        if (list.length === 0)
            return;
        const copy = Object.assign({}, cities);
        copy[country] = list;
        cities = copy;
    }

    // Statut toutes les 5 s ; module masqué (démon pas encore prêt à l'ouverture de session, compte connecté plus tard) :
    // nouvel essai toutes les 30 s, sans quoi il resterait masqué jusqu'au prochain rechargement.
    Timer {
        interval: root.available ? 5000 : 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    Component.onCompleted: refresh()

    // Connexion arrêtée qui ne rend pas la main (SIGINT ignoré) : arrêt forcé.
    Timer {
        id: cancelFallback
        interval: 3000
        onTriggered: {
            if (root.cancelling && root.current?.kind === "action")
                cli.stop();
        }
    }

    CliRunner {
        id: cli
        program: "nordvpn"
        probe: false   // présence et compte : lus par `nordvpn status`
        lastLineError: true
        noAnswer: `nordvpn: no answer after ${root.actionTimeout / 60} minutes`   // (seul le message des actions est lu)
        onFinished: root.finish()
    }
}
