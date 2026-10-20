pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Serveur de notifications (remplace Dunst, phase 6). Comportement repris de dunstrc et du code de Dunst 1.13 (queues.c,
// notification.c, markup.c) :
//  - délais : celui demandé par l'application, sinon 10 s (basse, normale) et jamais pour une critique ; suspendus tant que
//    le pointeur est sur les notifications (sauf notification « transient ») ;
//  - tri : urgence décroissante, puis ordre d'arrivée ;
//  - doublons empilés avec compteur « (N) » ; étiquette de pile (x-dunst-stack-tag…) : remplace la précédente de la même application ;
//  - historique : toute notification fermée y entre (20 au plus) ; rappelée, elle reste affichée jusqu'à sa fermeture ;
//  - texte : « <b>titre</b>\ncorps », indicateurs (A) actions, (U) liens, âge « (1m 4s old) » au-delà de 60 s.
// Ajouts (ta demande du 2026-10-16) : centre de notifications (cloche du tray, NotificationsPanel.qml) qui montre l'historique,
// et « ne pas déranger » : seules les critiques s'affichent, les autres vont directement dans l'historique.
Singleton {
    id: root

    // Notifications affichées (objets Entry), dans l'ordre d'affichage.
    property list<QtObject> popups: []
    // Historique : copies figées, de la plus ancienne à la plus récente ; `seen` faux si elle a expiré sans que tu la fermes
    // ou si elle est arrivée pendant « ne pas déranger » (point bleu sur la cloche jusqu'à l'ouverture du centre).
    property var history: []
    readonly property bool unseen: history.some(h => !h.seen)
    property alias doNotDisturb: persist.doNotDisturb

    // Historique et « ne pas déranger » gardés quand la config se recharge (les notifications affichées le sont par le serveur).
    // L'historique y est en texte JSON : un tableau JavaScript ne passe pas d'un moteur QML au suivant.
    PersistentProperties {
        id: persist
        reloadableId: "notifs"

        property string history: "[]"
        property bool doNotDisturb: false
        property int nextKey: 0
        property bool ready: false

        // Images envoyées en données (avatars…) : perdues au rechargement (voir imageLocks), icône de l'application à la place.
        onLoaded: {
            root.history = JSON.parse(history).map(h => h.imageKey ? Object.assign(h, root.isDataImage(h.icon) ? { icon: h.fallbackIcon ?? "" } : {}, { imageKey: 0 }) : h);
            ready = true;
        }
    }

    onHistoryChanged: {
        if (persist.ready)
            persist.history = JSON.stringify(history);
        pruneImages();
    }

    // Image envoyée en données (indice image-data) : Quickshell la sert depuis l'objet Notification, détruit à la fermeture.
    // Comme Dunst, qui la garde dans son historique, l'objet est retenu (RetainableLock) tant qu'une entrée de l'historique
    // ou une notification rappelée l'affiche. { imageKey: verrou }, en mémoire seulement.
    property var imageLocks: ({})

    Component {
        id: imageLock

        RetainableLock {
            locked: true
        }
    }

    // Image en données, servie par Quickshell (une icône nommée ou un chemin arrive aussi en `image`, mais en image://icon/ :
    // l'icône du thème reste lisible après un rechargement, rien à retenir).
    function isDataImage(image: string): bool {
        return image.startsWith("image://") && !image.startsWith("image://icon/");
    }

    function lockImage(n: Notification): int {
        const key = ++persist.nextKey;
        imageLocks = Object.assign({}, imageLocks, { [key]: imageLock.createObject(root, { object: n }) });
        return key;
    }

    function pruneImages(): void {
        const used = new Set([...history.map(h => h.imageKey), ...popups.map(e => e.saved?.imageKey)].filter(k => k));
        const kept = {};
        for (const [key, lock] of Object.entries(imageLocks)) {
            if (used.has(Number(key)))
                kept[key] = lock;
            else
                lock.destroy();
        }
        imageLocks = kept;
    }
    // Pointeur sur les notifications (NotificationPopups.qml) : délais suspendus.
    property bool hovered: false
    // Horloge à la seconde, pour l'âge affiché.
    property real clock: Date.now()

    readonly property int historyLength: 20               // dunstrc
    readonly property int ageThreshold: 60                // dunstrc show_age_threshold, en secondes
    readonly property var defaultTimeouts: [10000, 10000, 0] // basse, normale, critique (défauts Dunst, non fixés dans dunstrc)
    readonly property var stackTagHints: ["synchronous", "private-synchronous", "x-canonical-private-synchronous", "x-dunst-stack-tag"]

    property int nextOrder: 0

    NotificationServer {
        // Capacités annoncées par Dunst (markup = full) : actions, corps avec markup et liens, icônes, étiquettes de pile.
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        extraHints: root.stackTagHints
        keepOnReload: true

        onNotification: notification => root.add(notification)
    }

    // Composant interne : les id du fichier n'y sont pas visibles, d'où « Notifs. ».
    component Entry: QtObject {
        id: entry

        property Notification notification: null
        property var saved: ({})        // copie figée (notification rappelée de l'historique)
        property int order: 0
        property int dupCount: 0
        property real start: Date.now()        // début du délai
        property real timestamp: Date.now()    // arrivée (âge affiché)
        property bool redisplayed: false

        readonly property string appName: notification ? notification.appName : (saved.appName ?? "")
        readonly property string summary: notification ? notification.summary : (saved.summary ?? "")
        readonly property string body: notification ? notification.body : (saved.body ?? "")
        readonly property int urgency: notification ? notification.urgency : (saved.urgency ?? NotificationUrgency.Normal)
        readonly property string icon: notification ? Notifs.iconSource(notification.image, notification.appIcon) : (saved.icon ?? "")
        readonly property int progress: notification ? Notifs.progressOf(notification.hints) : (saved.progress ?? -1)
        readonly property string stackTag: notification ? Notifs.stackTagOf(notification.hints) : ""
        readonly property bool isTransient: notification?.transient ?? false
        readonly property var actions: notification ? notification.actions : []
        readonly property bool hasActions: notification ? notification.actions.length > 0 : (saved.hasActions ?? false)
        readonly property var urls: Notifs.urlsOf(summary, body)
        // Délai en ms (0 : jamais). Rappelée de l'historique : jamais (sticky_history).
        readonly property real timeout: redisplayed ? 0 : notification && notification.expireTimeout >= 0 ? notification.expireTimeout
            : Notifs.defaultTimeouts[urgency] ?? 10000
        // Texte affiché (StyledText).
        readonly property string text: Notifs.render(entry, Notifs.clock)

        // Remplacement par identifiant (géré par Quickshell sur le même objet) : le délai repart, comme Dunst.
        property Connections watcher: Connections {
            target: entry.notification
            function onSummaryChanged() { entry.start = Date.now(); }
            function onBodyChanged() { entry.start = Date.now(); }
            function onHintsChanged() { entry.start = Date.now(); }
            function onUrgencyChanged() { entry.start = Date.now(); }
            function onClosed(reason) { Notifs.closed(entry, reason); }
        }
    }

    Component {
        id: entryComponent
        Entry {}
    }

    // --- Arrivée ---

    function add(n: Notification): void {
        // Ne pas déranger : directement dans l'historique, non suivie (Quickshell la ferme aussitôt). Avec une image en données,
        // elle est suivie juste le temps d'être retenue puis fermée : une notification non suivie est détruite sur-le-champ,
        // verrou ou non.
        if (doNotDisturb && n.urgency !== NotificationUrgency.Critical) {
            let imageKey = 0;
            if (isDataImage(n.image)) {
                n.tracked = true;
                imageKey = lockImage(n);
                Qt.callLater(() => n.expire());
            }
            archive({
                appName: n.appName,
                summary: n.summary,
                body: n.body,
                urgency: n.urgency,
                icon: iconSource(n.image, n.appIcon),
                imageKey,
                fallbackIcon: iconSource("", n.appIcon),
                progress: progressOf(n.hints),
                hasActions: n.actions.length > 0,
                dupCount: 0,
                timestamp: Date.now()
            }, false);
            return;
        }
        n.tracked = true;
        const icon = iconSource(n.image, n.appIcon);
        const tag = stackTagOf(n.hints);
        // Étiquette de pile : remplace la notification de même étiquette et de même application.
        let old = tag !== "" ? popups.find(e => e.stackTag === tag && e.appName === n.appName) : undefined;
        let dupCount = old?.dupCount ?? 0;
        // Doublon (même application, titre, corps, urgence et icône) : remplacé, compteur augmenté si la progression est la même.
        if (!old) {
            old = popups.find(e => e.appName === n.appName && e.summary === n.summary && e.body === n.body && e.urgency === n.urgency
                && (e.icon === "" || icon === "" || e.icon === icon));
            if (old)
                dupCount = old.progress === progressOf(n.hints) ? old.dupCount + 1 : old.dupCount;
        }
        if (old) {
            const previous = old.notification;
            old.notification = n;       // la surveillance passe à la nouvelle avant la fermeture de l'ancienne (pas d'historique)
            old.redisplayed = false;
            old.dupCount = dupCount;
            old.start = old.timestamp = Date.now();
            previous?.expire();
            return;
        }
        const entry = entryComponent.createObject(root, { notification: n, order: ++nextOrder });
        show(entry);
    }

    function show(entry): void {
        popups = [...popups, entry].sort((a, b) => b.urgency - a.urgency || a.order - b.order);
    }

    // --- Fermeture ---

    // Toute fermeture (délai, clic, application, action) : retirée de l'affichage, copiée dans l'historique.
    function closed(entry, reason: int): void {
        if (!popups.includes(entry))
            return;
        popups = popups.filter(e => e !== entry);
        let imageKey = entry.saved?.imageKey ?? 0;
        if (entry.notification && isDataImage(entry.notification.image))
            imageKey = lockImage(entry.notification);
        archive({
            appName: entry.appName,
            summary: entry.summary,
            body: entry.body,
            urgency: entry.urgency,
            icon: entry.icon,
            imageKey,
            fallbackIcon: entry.notification ? iconSource("", entry.notification.appIcon) : (entry.saved?.fallbackIcon ?? ""),
            progress: entry.progress,
            hasActions: entry.hasActions,
            dupCount: entry.dupCount,
            timestamp: entry.timestamp
        }, reason !== NotificationCloseReason.Expired);
        entry.notification = null;
        entry.destroy();
    }

    // `key` : identifiant de l'entrée (liste du centre de notifications).
    function archive(item, seen: bool): void {
        history = [...history, Object.assign(item, { seen, key: ++persist.nextKey })].slice(-historyLength);
    }

    function close(entry): void {
        if (entry.notification)
            entry.notification.dismiss();
        else
            closed(entry, NotificationCloseReason.Dismissed);   // rappelée de l'historique : plus connue de l'application
    }

    function closeAll(): void {
        for (const entry of [...popups])
            close(entry);
    }

    function expire(entry): void {
        if (entry.notification)
            entry.notification.expire();
        else
            closed(entry, NotificationCloseReason.Expired);
    }

    // Clic milieu (dunstrc : do_action, close_current) : action « default », ou l'unique action, sinon le lien s'il n'y en a qu'un.
    // Plusieurs actions sans « default », ou plusieurs liens : Dunst ouvrait dmenu (absent) ; ici, les boutons d'action.
    function doAction(entry): void {
        const actions = entry.actions;
        const action = actions.find(a => a.identifier === "default") ?? (actions.length === 1 ? actions[0] : null);
        if (action)
            action.invoke();
        else if (actions.length === 0 && entry.urls.length === 1)
            Quickshell.execDetached(["xdg-open", entry.urls[0]]);
        if (popups.includes(entry))
            close(entry);
    }

    // Bouton d'action : ferme la notification, sauf si elle est « resident » (Quickshell).
    function invoke(action): void {
        action.invoke();
    }

    // --- Historique ---

    function historyPop(): void {
        if (history.length === 0)
            return;
        const saved = history[history.length - 1];
        const entry = entryComponent.createObject(root, {
            saved,
            redisplayed: true,
            order: ++nextOrder,
            dupCount: saved.dupCount,
            timestamp: saved.timestamp
        });
        show(entry);   // avant de la retirer de l'historique : son image reste retenue
        history = history.slice(0, -1);
    }

    // Centre de notifications ouvert : tout est vu.
    function markSeen(): void {
        if (unseen)
            history = history.map(h => Object.assign({}, h, { seen: true }));
    }

    function removeHistory(key: int): void {
        history = history.filter(h => h.key !== key);
    }

    function clearHistory(): void {
        history = [];
    }

    // --- Délais ---

    Timer {
        running: root.popups.length > 0
        interval: 100
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (Math.floor(now / 1000) !== Math.floor(root.clock / 1000))
                root.clock = now;
            for (const entry of [...root.popups]) {
                if (root.hovered && !entry.isTransient)
                    entry.start = now;
                else if (entry.timeout > 0 && now - entry.start >= entry.timeout)
                    root.expire(entry);
            }
        }
    }

    // --- Lecture des notifications ---

    // Icône : image fournie (données, chemin ou nom d'icône), sinon icône de l'application (chemin ou nom dans le thème).
    // Fichiers locaux, images servies par Quickshell et icônes du thème seulement, comme Dunst : une adresse http(s) envoyée
    // par une application ferait télécharger l'image à chaque affichage (pixel espion ; revue de code).
    function iconSource(image: string, appIcon: string): string {
        if (image.startsWith("image://") || image.startsWith("file:"))
            return image;
        if (image !== "" && !image.includes("://"))
            return Icons.iconSource(image);   // chemin absolu ou nom d'icône du thème (image-path de la spécification)
        if (appIcon === "" || (appIcon.includes("://") && !appIcon.startsWith("file:")))
            return "";
        if (appIcon.startsWith("file:"))
            return appIcon;
        return Icons.iconSource(appIcon);
    }

    // Indice « value » : progression 0–100, -1 sans barre.
    function progressOf(hints): int {
        const value = hints?.value;
        return value === undefined || value === null || value < 0 ? -1 : Math.round(value);
    }

    function stackTagOf(hints): string {
        for (const name of stackTagHints)
            if (typeof hints?.[name] === "string")
                return hints[name];
        return "";
    }

    // Liens (markup.c, menu.c) : href des <a>, src des <img>, puis adresses dans le texte.
    function urlsOf(summary: string, body: string): var {
        const text = `${summary} ${body}`;
        const urls = [];
        const collect = (re, source, group) => {
            let m;
            while ((m = re.exec(source)) !== null)
                urls.push(m[group]);
        };
        collect(/<a\s[^>]*href="([^"]*)"/gi, text, 1);
        collect(/<img\s[^>]*src="([^"]*)"/gi, text, 1);
        const plain = text.replace(/<a\s[^>]*>|<\/a>|<img[^>]*>/gi, "");
        collect(/\b(https?:\/\/|ftps?:\/\/|news:\/\/|mailto:|file:\/\/|www\.)[-\w@;\/?:&=%$.+!*',~#]*(\([-\w@;\/?:&=%$.+!*',~#]*\)|[-\w@;\/?:&=%$+*~])+/gi, plain, 0);
        return urls;
    }

    function escapeMarkup(text: string): string {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Corps (markup = full) : & isolés échappés, <br> en saut de ligne, liens réduits à leur texte, images à leur texte alt.
    function bodyMarkup(body: string): string {
        return body.replace(/&(?!(amp|lt|gt|quot|apos|#\d+|#x[0-9a-f]+);)/gi, "&amp;")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<a\s[^>]*>|<\/a>/gi, "")
            .replace(/<img[^>]*>/gi, tag => tag.match(/alt="([^"]*)"/i)?.[1] ?? "[image]");
    }

    function render(entry, now: real): string {
        let msg = `<b>${escapeMarkup(entry.summary)}</b>\n${bodyMarkup(entry.body)}`.replace(/\s+$/, "");
        const indicators = (entry.hasActions ? "A" : "") + (entry.urls.length > 0 ? "U" : "");
        if (entry.dupCount > 0 || indicators !== "")
            msg = `(${entry.dupCount > 0 ? entry.dupCount : ""}${indicators}) ${msg}`;
        const age = Math.floor(now / 1000) - Math.floor(entry.timestamp / 1000);
        if (age >= ageThreshold) {
            const h = Math.floor(age / 3600), m = Math.floor(age / 60) % 60, s = age % 60;
            msg += h > 0 ? ` (${h}h ${m}m ${s}s old)` : m > 0 ? ` (${m}m ${s}s old)` : ` (${s}s old)`;
        }
        return msg.replace(/\n/g, "<br>");
    }

    // --- Raccourcis (équivalents de dunstctl) ---

    IpcHandler {
        target: "notifications"

        // dunstctl close : la première notification affichée.
        function close(): void {
            if (root.popups.length > 0)
                root.close(root.popups[0]);
        }

        // dunstctl close-all
        function closeAll(): void {
            root.closeAll();
        }

        // dunstctl history-pop
        function historyPop(): void {
            root.historyPop();
        }

        // dunstctl count
        function count(): string {
            return `displayed ${root.popups.length}, history ${root.history.length}`;
        }
    }
}
