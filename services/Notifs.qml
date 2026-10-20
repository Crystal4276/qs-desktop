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
    // Reçues pendant « ne pas déranger », encore suivies (Entry.quiet).
    property list<QtObject> quiet: []
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
        property string iconFiles: "{}"   // copies d'icônes faites par cette instance (keepIcon)
        property int nextOrder: 0
        // Notifications suivies (affichées, rappelées, ou silencieuses) : état repris au rechargement (saveLive).
        property string live: "[]"

        // Images envoyées en données (avatars…) : perdues au rechargement (voir imageLocks), icône de l'application à la place.
        onLoaded: {
            if (!ready)
                staleIconDirs.running = true;   // premier chargement de cette instance
            root.iconFiles = Object.assign(JSON.parse(iconFiles), root.iconFiles);   // + copies faites avant ce point
            root.restoreLive(JSON.parse(live));
            root.history = JSON.parse(history).map(h => h.imageKey ? Object.assign(h, root.isDataImage(h.icon) ? { icon: h.fallbackIcon ?? "" } : {}, { imageKey: 0 }) : h);
            ready = true;
        }
    }

    onHistoryChanged: {
        if (persist.ready)
            persist.history = JSON.stringify(history);
        pruneImages();
        pruneTimer.restart();
        // Ligne d'une silencieuse poussée hors de l'historique (20 au plus) : elle cesse d'être suivie.
        for (const entry of [...quiet]) {
            if (!history.some(h => h.key === entry.historyKey))
                entry.notification?.expire();
        }
    }

    onPopupsChanged: {
        pruneTimer.restart();
        saveLive();
    }
    onQuietChanged: {
        pruneTimer.restart();
        saveLive();
    }

    // Nettoyage des copies d'icônes différé d'une seconde : une notification fermée quitte l'affichage avant d'entrer dans
    // l'historique (closed), et après un rechargement Quickshell réémet les notifications affichées après la restauration de
    // l'historique (vu dans le journal) ; elles reprennent leur copie entre-temps.
    Timer {
        id: pruneTimer
        interval: 1000
        onTriggered: root.pruneIcons()
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
        // Ne pas déranger : suivie sans être affichée jusqu'à son délai ; sa ligne de l'historique (clé) suit ses mises à jour.
        property int historyKey: 0
        readonly property bool quiet: historyKey !== 0
        property bool dirty: false   // changée, ligne et ordre à refaire (Notifs.applyChanges)
        // Image en données retenue pour sa ligne (snapshot) : réutilisée tant que l'image ne change pas.
        property string lockedImage: ""
        property int lockedKey: 0

        readonly property string appName: notification ? notification.appName : (saved.appName ?? "")
        readonly property string summary: notification ? notification.summary : (saved.summary ?? "")
        readonly property string body: notification ? notification.body : (saved.body ?? "")
        readonly property int urgency: notification ? notification.urgency : (saved.urgency ?? NotificationUrgency.Normal)
        // Icône et icône de l'application (repli dans l'historique) : copiées à l'arrivée et à chaque changement d'image
        // (Notifs.keepIcon), pas dans une liaison.
        property string icon: saved.icon ?? ""
        property string fallbackIcon: saved.fallbackIcon ?? ""
        function keepIcons(): void {
            const source = Notifs.iconSource(notification.image, notification.appIcon);
            const fallback = Notifs.iconSource("", notification.appIcon);
            icon = Notifs.keepIcon(source, notification.id);
            fallbackIcon = fallback === source ? icon : Notifs.keepIcon(fallback, notification.id);   // même fichier : une copie
        }
        // Émis aussi pour la valeur passée à createObject (vérifié).
        onNotificationChanged: {
            if (notification)
                keepIcons();
        }
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
            function onSummaryChanged() { Notifs.changed(entry); }
            function onBodyChanged() { Notifs.changed(entry); }
            function onHintsChanged() { Notifs.changed(entry); }
            function onUrgencyChanged() { Notifs.changed(entry); }
            function onImageChanged() { entry.keepIcons(); Notifs.changed(entry); }
            function onAppIconChanged() { entry.keepIcons(); Notifs.changed(entry); }
            function onClosed(reason) { Notifs.closed(entry, reason); }
        }
    }

    Component {
        id: entryComponent
        Entry {}
    }

    // --- Arrivée ---

    function add(n: Notification): void {
        n.tracked = true;
        // Réémise après un rechargement de la config : reprend son état (affichée ou silencieuse, âge, délai, compteur), sans
        // repasser par « ne pas déranger » ni par les doublons.
        if (n.lastGeneration) {
            restore(n);
            return;
        }
        const icon = iconSource(n.image, n.appIcon);
        const tag = stackTagOf(n.hints);
        const live = [...popups, ...quiet];
        // Étiquette de pile : remplace la notification de même étiquette et de même application.
        let old = tag !== "" ? live.find(e => e.stackTag === tag && e.appName === n.appName) : undefined;
        let dupCount = old?.dupCount ?? 0;
        // Doublon (même application, titre, corps, urgence et icône) : remplacé, compteur augmenté si la progression est la même.
        if (!old) {
            old = live.find(e => e.appName === n.appName && e.summary === n.summary && e.body === n.body && e.urgency === n.urgency
                && (e.icon === "" || icon === "" || (e.notification ? iconSource(e.notification.image, e.notification.appIcon) : e.icon) === icon));
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
            // Silencieuse remplacée alors qu'elle doit s'afficher (« ne pas déranger » coupé, ou critique) : affichée. Une
            // notification déjà affichée le reste.
            if (old.quiet && !silent(n))
                promote(old);
            changed(old);
            return;
        }
        const entry = entryComponent.createObject(root, { notification: n, order: ++persist.nextOrder });
        // Ne pas déranger : directement dans l'historique, suivie sans affichage jusqu'à son délai (ses mises à jour, par
        // identifiant ou étiquette de pile, remplacent sa ligne au lieu d'en ajouter une). Les critiques s'affichent.
        if (silent(n)) {
            const item = snapshot(entry);
            archive(item, false);
            entry.historyKey = item.key;
            quiet = [...quiet, entry];
            return;
        }
        show(entry);
    }

    // Contenu ou image changés (remplacement par identifiant, géré par Quickshell sur le même objet, ou par étiquette de pile
    // et doublon) : le délai repart, comme Dunst ; l'ordre d'urgence est refait ; ligne de l'historique mise à jour si silencieuse.
    function changed(entry): void {
        entry.start = Date.now();
        entry.dirty = true;
        Qt.callLater(applyChanges);   // après la mise à jour des liaisons de l'Entry (le signal arrive avant)
    }

    function applyChanges(): void {
        const dirty = [...popups, ...quiet].filter(e => e.dirty);
        if (dirty.length === 0)
            return;
        const rows = [];
        for (const entry of dirty) {
            entry.dirty = false;
            // Devenue critique par une mise à jour (même identifiant) : affichée.
            if (entry.quiet && entry.urgency === NotificationUrgency.Critical)
                promote(entry);
            else if (entry.quiet)
                rows.push(entry);
        }
        updateRows(rows);
        const sorted = [...popups].sort(byUrgency);
        if (sorted.some((e, i) => e !== popups[i]))
            popups = sorted;   // saveLive par onPopupsChanged
        else
            saveLive();
    }

    // Lignes des notifications silencieuses mises à jour : nouveau contenu, donc non vues, et en tête du centre. Nouvelle clé :
    // le ScriptModel du centre (objectProp: "key") garde l'ancien objet d'une ligne déplacée qui garde sa clé (vu sur banc).
    function updateRows(entries): void {
        const byKey = {};
        for (const entry of entries)
            byKey[entry.historyKey] = entry;
        const updated = [];
        for (const h of history) {
            const entry = byKey[h.key];
            if (entry) {
                entry.historyKey = ++persist.nextKey;
                updated.push(Object.assign(snapshot(entry), { seen: false, key: entry.historyKey }));
            }
        }
        if (updated.length > 0)
            history = [...history.filter(h => !byKey[h.key]), ...updated];
    }

    function silent(n: Notification): bool {
        return doNotDisturb && n.urgency !== NotificationUrgency.Critical;
    }

    // Silencieuse qui doit s'afficher : sa ligne quitte l'historique (elle y reviendra à sa fermeture), elle s'affiche.
    function promote(entry): void {
        const key = entry.historyKey;
        entry.historyKey = 0;
        quiet = quiet.filter(e => e !== entry);
        history = history.filter(h => h.key !== key);
        show(entry);
    }

    // Copie figée d'une notification suivie (historique). Image en données : retenue (lockImage).
    function snapshot(entry): var {
        let imageKey = entry.saved?.imageKey ?? 0;
        const image = entry.notification?.image ?? "";
        if (isDataImage(image)) {
            if (image !== entry.lockedImage || entry.lockedKey === 0) {
                entry.lockedKey = lockImage(entry.notification);
                entry.lockedImage = image;
            }
            imageKey = entry.lockedKey;
        }
        return {
            appName: entry.appName,
            summary: entry.summary,
            body: entry.body,
            urgency: entry.urgency,
            icon: entry.icon,
            imageKey,
            fallbackIcon: entry.fallbackIcon,
            progress: entry.progress,
            hasActions: entry.hasActions,
            dupCount: entry.dupCount,
            timestamp: entry.timestamp
        };
    }

    function byUrgency(a, b): int {
        return b.urgency - a.urgency || a.order - b.order;
    }

    function show(entry): void {
        popups = [...popups, entry].sort(byUrgency);
    }

    // --- Rechargement de la config ---

    // État des notifications suivies, gardé au rechargement : Quickshell réémet les notifications vivantes (keepOnReload),
    // mais pas leur âge, leur compteur, leur ordre ni leur rôle (affichée / silencieuse) ; une notification rappelée de
    // l'historique n'est plus connue de Quickshell : elle est recréée d'après sa copie.
    property var restored: ({})   // { id de la notification: état }, en attente de sa réémission

    function saveLive(): void {
        if (!persist.ready)
            return;
        persist.live = JSON.stringify([...popups, ...quiet].map(e => ({
            id: e.notification?.id ?? 0,
            saved: e.notification ? null : e.saved,
            historyKey: e.historyKey,
            redisplayed: e.redisplayed,
            order: e.order,
            dupCount: e.dupCount,
            timestamp: e.timestamp
        })));
    }

    // Propriétés d'une Entry recréée d'après son état. Le délai repart de zéro : le survol, qui le suspend, n'est pas
    // enregistré, et un délai repris trop tôt ferait disparaître la notification dès le rechargement.
    function stateProps(state): var {
        return { order: state.order, dupCount: state.dupCount, timestamp: state.timestamp, redisplayed: state.redisplayed };
    }

    function restoreLive(states): void {
        const pending = {};
        for (const state of states) {
            if (state.id !== 0) {
                pending[state.id] = state;
            } else {
                // Image en données de la copie : perdue au rechargement, icône de l'application à la place (comme l'historique).
                const saved = isDataImage(state.saved.icon ?? "") ? Object.assign(state.saved, { icon: state.saved.fallbackIcon ?? "", imageKey: 0 }) : state.saved;
                show(entryComponent.createObject(root, Object.assign(stateProps(state), { saved })));
            }
        }
        restored = pending;
    }

    function restore(n: Notification): void {
        const state = restored[n.id];
        const entry = entryComponent.createObject(root, Object.assign({ notification: n, order: ++persist.nextOrder },
            state ? stateProps(state) : {}));
        if (state?.historyKey) {
            entry.historyKey = state.historyKey;
            quiet = [...quiet, entry];
        } else {
            show(entry);
        }
    }

    // --- Fermeture ---

    // Toute fermeture (délai, clic, application, action) : retirée de l'affichage, copiée dans l'historique.
    function closed(entry, reason: int): void {
        if (quiet.includes(entry)) {
            // Silencieuse : déjà dans l'historique, elle cesse seulement d'être suivie (mise à jour en attente appliquée).
            if (entry.dirty)
                updateRows([entry]);
            quiet = quiet.filter(e => e !== entry);
        } else {
            if (!popups.includes(entry))
                return;
            popups = popups.filter(e => e !== entry);
            archive(snapshot(entry), reason !== NotificationCloseReason.Expired);
        }
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
        // Ligne d'une notification silencieuse encore suivie : c'est elle qui s'affiche (actions utilisables, mises à jour).
        const live = quiet.find(e => e.historyKey === saved.key);
        if (live) {
            promote(live);
            return;
        }
        const entry = entryComponent.createObject(root, Object.assign(stateProps(saved), {
            saved,
            redisplayed: true,
            order: ++persist.nextOrder
        }));
        show(entry);   // avant de la retirer de l'historique : son image reste retenue
        history = history.slice(0, -1);
    }

    // Centre de notifications ouvert : tout est vu.
    function markSeen(): void {
        if (unseen)
            history = history.map(h => Object.assign({}, h, { seen: true }));
    }

    // Ligne d'une notification silencieuse encore suivie : elle est fermée (écartée par toi).
    function removeHistory(key: int): void {
        quiet.find(e => e.historyKey === key)?.notification?.dismiss();
        history = history.filter(h => h.key !== key);
    }

    function clearHistory(): void {
        for (const entry of [...quiet])
            entry.notification?.dismiss();
        history = [];
    }

    // --- Délais ---

    Timer {
        running: root.popups.length > 0 || root.quiet.length > 0
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
            for (const entry of [...root.quiet]) {
                if (entry.timeout > 0 && now - entry.start >= entry.timeout)
                    root.expire(entry);
            }
        }
    }

    // --- Lecture des notifications ---

    // Icône : image fournie (données, chemin ou nom d'icône), sinon icône de l'application (chemin ou nom dans le thème).
    // Fichiers locaux, images servies par Quickshell et icônes du thème seulement, comme Dunst : une adresse http(s) envoyée
    // par une application ferait télécharger l'image à chaque affichage (pixel espion ; revue de code).
    function iconSource(image: string, appIcon: string): string {
        // Chemin servi par le fournisseur d'icônes : en file://, pour qu'un fichier absent soit une erreur (repli sur l'icône
        // de l'application) et non le damier de Quickshell.
        if (image.startsWith("image://icon//"))
            return Icons.fileUrl(decodeURIComponent(image.slice(13).split("?")[0]));
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

    // Icône en fichier local : copiée dès la réception. Chromium (et ses applications web : ChatGPT, Claude…) l'écrit dans un
    // dossier temporaire qu'il efface à la fermeture de la notification ; Dunst la chargeait aussitôt, ici elle est relue plus
    // tard (historique, rechargement). Une copie par notification, lue et écrite d'un bloc (pas de processus : Chromium efface
    // le fichier dès la fermeture, immédiate pendant « ne pas déranger »), dans un dossier propre à cette instance de Quickshell
    // sous XDG_RUNTIME_DIR (vidé à la fin de la session, comme l'historique ; deux instances ne se gênent pas ; les dossiers des
    // instances terminées sont effacés au démarrage). Seuls les fichiers des dossiers temporaires sont copiés (/tmp, TMPDIR,
    // XDG_RUNTIME_DIR, XDG_CACHE_HOME) : thèmes, /usr/share/pixmaps ou images personnelles ne disparaissent pas d'elles-mêmes.
    // Une copie qui ne sert plus (ni affichée, ni suivie, ni dans l'historique) est effacée (pruneIcons).
    readonly property string iconRoot: `${Quickshell.env("XDG_RUNTIME_DIR") || Quickshell.cacheDir}/quickshell-notification-icons`
    readonly property string iconCache: `${iconRoot}/${Quickshell.instanceId}`
    readonly property list<string> volatileDirs: ["/tmp", Quickshell.env("TMPDIR"), Quickshell.env("XDG_RUNTIME_DIR"),
        Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`]
        .filter(d => d && d.startsWith("/")).map(d => d.replace(/\/*$/, "/"))

    // Démarrage : dossiers des instances de Quickshell terminées (dev.sh, plantage). Rien n'est effacé si la liste des instances
    // vivantes ne contient pas celle-ci (commande en échec).
    Process {
        id: staleIconDirs
        command: ["sh", "-c", `live=" $(qs list --all 2>/dev/null | sed -n 's/^Instance \\(.*\\):$/\\1/p' | tr '\\n' ' ') "
            case "$live" in *" $2 "*) ;; *) exit 0 ;; esac
            for dir in "$1"/*/; do
                [ -d "$dir" ] || continue
                id=$(basename "$dir")
                case "$live" in *" $id "*) ;; *) rm -rf -- "$dir" ;; esac
            done`, "sh", root.iconRoot, Quickshell.instanceId]
    }
    // Copies faites par cette instance, { "<id de la notification>|<source>": URL de la copie }, gardées au rechargement de la
    // config (persist.iconFiles) : une notification réémise après un rechargement dont le fichier a disparu reprend sa copie.
    property var iconFiles: ({})
    onIconFilesChanged: {
        if (persist.ready)
            persist.iconFiles = JSON.stringify(iconFiles);
    }

    // Un FileView par fichier : un FileView dont on change `path` rend encore les données du précédent (vérifié, 0.3.2).
    // Écriture bloquante : `saveFailed` est émis avant le retour de setData.
    Component {
        id: iconFile

        FileView {
            property bool failed: false

            blockLoading: true
            blockWrites: true
            printErrors: false
            onSaveFailed: failed = true
        }
    }

    function keepIcon(source: string, id: int): string {
        const path = source.startsWith("file://") ? decodeURIComponent(source.slice(7))
            : source.startsWith("image://icon//") ? decodeURIComponent(source.slice(13).split("?")[0]) : "";
        if (path === "" || path.startsWith(`${iconRoot}/`) || !volatileDirs.some(d => path.startsWith(d)))
            return source;
        const key = `${id}|${source}`;
        const reader = iconFile.createObject(root, { path });
        const data = reader.data();
        reader.destroy();
        // Illisible (effacé) : dernière copie pour cette notification, sinon la source telle quelle. Lisible : copié à nouveau
        // (même chemin réécrit avec une autre image).
        if (!data || data.byteLength === 0)
            return iconFiles[key] ?? source;
        // Extension du nom de fichier (pas d'un « .xxxxxx » de fichier caché ou temporaire).
        const file = `${iconCache}/${++persist.nextKey}${path.split("/").pop().match(/^[^.].*(\.[A-Za-z0-9]+)$/)?.[1] ?? ""}`;
        const writer = iconFile.createObject(root, { path: file });
        writer.setData(data);
        const failed = writer.failed;
        writer.destroy();
        if (failed)
            return iconFiles[key] ?? source;
        const url = Icons.fileUrl(file);
        // Copie précédente pour la même clé : gardée sous une autre clé, effacée par pruneIcons quand plus rien ne l'affiche.
        const previous = iconFiles[key] !== undefined ? { [`${key}|${iconFiles[key]}`]: iconFiles[key] } : {};
        iconFiles = Object.assign({}, iconFiles, previous, { [key]: url });
        if (Object.keys(previous).length > 0)
            pruneTimer.restart();
        return url;
    }

    // Efface les copies qui ne servent plus : ni dans l'historique (icône ou icône de repli), ni sur une notification affichée.
    function pruneIcons(): void {
        const used = new Set();
        for (const item of [...history, ...popups, ...quiet]) {
            used.add(item.icon);
            used.add(item.fallbackIcon);
        }
        const unused = Object.values(iconFiles).filter(f => !used.has(f));
        if (unused.length === 0)
            return;
        const kept = {};
        for (const [key, f] of Object.entries(iconFiles)) {
            if (used.has(f))
                kept[key] = f;
        }
        iconFiles = kept;
        Quickshell.execDetached(["rm", "-f", "--", ...unused.map(f => decodeURIComponent(f.slice(7)))]);
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
