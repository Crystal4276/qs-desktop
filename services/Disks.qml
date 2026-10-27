pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Disques amovibles (module natif du tray, remplace udiskie ; ARCHITECTURE R7, § 10.3). Pas d'accès D-Bus générique en QML :
//  - état : `busctl --json` (GetManagedObjects d'UDisks2), relu après chaque changement signalé par `gdbus monitor` ;
//  - actions : `udisksctl` (monter, démonter, déverrouiller avec la phrase de passe sur l'entrée standard, verrouiller, éteindre) ;
//  - comme udiskie (réglages par défaut, aucun fichier de config) : montage automatique, notifications avec ses textes.
// Volumes gérés : ni « système » ni « à ignorer » pour UDisks2 (les disques internes ne s'affichent pas), plus les images disque
// en boucle créées par l'utilisateur.
Singleton {
    id: root

    // Volumes gérés : { path, device, label, uiLabel, size, fsType, isFilesystem, isCrypto, backing (volume chiffré d'origine),
    //                   cleartext (volume déchiffré, "/" si verrouillé), mounted, mountPoint, driveKey }
    property var volumes: []
    // Disques portant au moins un volume géré : { key, label, device (disque entier), canPowerOff, ejectable, isLoop, autoclear }
    // (clé : chemin du Drive UDisks2, ou du périphérique entier pour une image disque montée en boucle).
    property var drives: []
    property bool loaded: false
    property int failedReads: 0
    property bool readFailed: false   // dernière lecture ratée (ou pas démarrée) : réessayée
    // Périphériques dont une action est en cours (un par action) : leurs boutons sont atténués, un second clic ne relance rien.
    property var busy: []
    // Disques LUKS branchés, encore verrouillés : phrase de passe à demander, le premier d'abord (udiskie ouvrait sa fenêtre ;
    // ta demande du 2026-10-27). Pas au démarrage ni au rechargement : seulement à l'arrivée du volume. Affichée par le panneau
    // des disques ouvert (un seul popup à la fois), ouvert par le tray s'il ne l'est pas (Tray.qml) ; retirés une fois
    // déverrouillés ou débranchés.
    property var pending: []
    // QS_TEST (instance de scripts/test-outputs.sh) : pas de montage automatique, l'instance de test parle au vrai bus système
    // et monterait tes disques laissés démontés.
    readonly property bool automount: !Quickshell.env("QS_TEST")

    // --- Lecture de l'état ---

    // Octets terminés par 0 (chemins, fichier d'une image disque) en UTF-8, comme udiskie (decode_ay) ; Latin-1 si invalide.
    function decode(bytes): string {
        if (!bytes)
            return "";
        const end = bytes.indexOf(0);
        const raw = end < 0 ? bytes : bytes.slice(0, end);
        try {
            return decodeURIComponent(raw.map(b => "%" + (b < 16 ? "0" : "") + b.toString(16)).join(""));
        } catch (e) {
            return raw.map(b => String.fromCharCode(b)).join("");
        }
    }

    function value(iface, key) {
        return iface?.[key]?.data;
    }

    function parse(text: string): void {
        let objects;
        try {
            objects = JSON.parse(text).data[0];
        } catch (e) {
            // Une seule fois (UDisks2 absent : relu de plus en plus rarement, voir `retry`).
            if (failedReads === 0)
                console.warn(`Disks: lecture d'UDisks2 impossible : ${e}`);
            return;
        }
        readFailed = false;
        failedReads = 0;
        const drivesByPath = {};
        for (const [path, ifs] of Object.entries(objects)) {
            const d = ifs["org.freedesktop.UDisks2.Drive"];
            if (d)
                drivesByPath[path] = {
                    path,
                    label: [value(d, "Vendor"), value(d, "Model")].filter(s => s).join(" "),
                    canPowerOff: value(d, "CanPowerOff") ?? false,
                    ejectable: value(d, "Ejectable") ?? false
                };
        }
        // Disque entier de chaque Drive (bloc sans interface Partition) et images en boucle.
        const loops = {};
        for (const [path, ifs] of Object.entries(objects)) {
            const b = ifs["org.freedesktop.UDisks2.Block"];
            if (!b || ifs["org.freedesktop.UDisks2.Partition"])
                continue;
            const device = decode(value(b, "Device"));
            if (drivesByPath[value(b, "Drive")])
                drivesByPath[value(b, "Drive")].device = device;
            const loop = ifs["org.freedesktop.UDisks2.Loop"];
            if (loop)
                loops[path] = { path, label: decode(value(loop, "BackingFile")), device, canPowerOff: false, ejectable: false, isLoop: true,
                    autoclear: value(loop, "Autoclear") ?? false };
        }
        // Volume chiffré d'origine d'un volume déchiffré (lui-même sinon).
        function encryptedOf(path: string): string {
            const backing = value(objects[path]?.["org.freedesktop.UDisks2.Block"], "CryptoBackingDevice");
            return backing && backing !== "/" ? encryptedOf(backing) : path;
        }
        // Disque d'un volume. Un volume déchiffré n'a pas de Drive (« / » pour un périphérique dm) : il hérite de celui de son
        // volume chiffré, donc il est géré comme lui et l'éjection du disque le démonte et le verrouille.
        function parentOf(path: string): var {
            const top = encryptedOf(path);
            const ifs = objects[top] ?? {};
            const partition = ifs["org.freedesktop.UDisks2.Partition"];
            return drivesByPath[value(ifs["org.freedesktop.UDisks2.Block"], "Drive")] ?? loops[partition ? value(partition, "Table") : top];
        }
        const list = [];
        for (const [path, ifs] of Object.entries(objects)) {
            const b = ifs["org.freedesktop.UDisks2.Block"];
            // Volume chiffré ignoré : son volume déchiffré aussi (aucune ligne du panneau ne le montrerait).
            const top = objects[encryptedOf(path)]?.["org.freedesktop.UDisks2.Block"];
            if (!b || value(b, "HintIgnore") || value(top, "HintIgnore"))
                continue;
            // Comme udiskie (mount.py) : une image disque en boucle est gérée même si UDisks2 la dit « système »,
            // sauf images du système (snaps, extensions).
            // Volume déchiffré : jugé sur son volume chiffré (UDisks2 dit « système » tout volume dm sans Drive ; udiskie ne
            // l'écarte pas non plus, ce n'est pas un périphérique de premier niveau).
            const parent = parentOf(path);
            if (!parent)
                continue;   // ni disque ni image (md, nbd…) : aucune ligne du panneau pour le démonter
            const userLoop = parent.isLoop && parent.label !== "" && !/^\/var\/lib\/(extensions|confexts|snapd)\//.test(parent.label);
            if (value(top, "HintSystem") && !userLoop)
                continue;
            const fs = ifs["org.freedesktop.UDisks2.Filesystem"];
            const crypto = ifs["org.freedesktop.UDisks2.Encrypted"];
            if (!fs && !crypto)
                continue;
            // Volume déchiffré : rattaché à son volume chiffré (CryptoBackingDevice), affiché avec lui.
            const backing = value(b, "CryptoBackingDevice");
            const mountPoints = (value(fs, "MountPoints") ?? []).map(decode);
            const device = decode(value(b, "PreferredDevice")) || decode(value(b, "Device"));
            const label = value(b, "IdLabel") || value(b, "IdUUID") || parent.label || "";
            list.push({
                path,
                device,
                label,
                uiLabel: [device, label].filter(s => s).join(": "),
                size: Number(value(b, "Size") ?? 0),
                fsType: value(b, "IdType") ?? "",
                isFilesystem: !!fs,
                isCrypto: !!crypto,
                // Phrase de passe passée en fichier de clé (udisksctl n'en lit une qu'au terminal) : équivalent pour LUKS
                // seulement (VeraCrypt, BitLocker : BACKLOG).
                canUnlock: !!crypto && value(b, "IdType") === "crypto_LUKS",
                backing: backing && backing !== "/" ? backing : "",
                cleartext: crypto ? (value(crypto, "CleartextDevice") ?? "/") : "/",
                mounted: mountPoints.length > 0,
                mountPoint: mountPoints[0] ?? "",
                driveKey: parent.path
            });
        }
        // sdb2 avant sdb10.
        const byDevice = (a, b) => a.device.localeCompare(b.device, undefined, { numeric: true });
        list.sort(byDevice);
        // Ordre fixe (GetManagedObjects n'en a pas).
        const driveList = [...Object.values(drivesByPath), ...Object.values(loops)].filter(d => list.some(v => v.driveKey === d.path))
            .map(d => ({ key: d.path, label: d.label, device: d.device ?? "", canPowerOff: d.canPowerOff, ejectable: d.ejectable,
                isLoop: d.isLoop ?? false, autoclear: d.autoclear ?? false }))
            .sort(byDevice);
        // Signaux sans effet ici (SMART des disques internes…) : rien n'est réassigné.
        const read = JSON.stringify([list, driveList]);
        if (loaded && read === persist.read)
            return;
        // Rechargement de la config : comparé au dernier état lu (rien n'est remonté) ; démarrage : tout est monté, comme udiskie.
        const restored = !loaded && persist.read !== "";
        const arrived = notifyChanges(restored ? JSON.parse(persist.read)[0] : volumes, list, !loaded && !restored);
        persist.read = read;
        volumes = list;
        drives = driveList;
        loaded = true;
        const still = pending.filter(p => list.some(v => sameVolume(v, p) && v.cleartext === "/"));
        if (still.length !== pending.length || arrived.length > 0)
            pending = [...still, ...arrived];
    }

    // Même volume : même objet UDisks2, même étiquette (ou UUID), même taille. Une autre clé branchée sous le même nom (sdb1)
    // entre deux lectures (rafale, lectures en échec) est un nouveau volume : annoncée, montée, phrase de passe demandée.
    function sameVolume(a, b): bool {
        return a.path === b.path && a.label === b.label && a.size === b.size;
    }

    // --- Notifications et montage automatique (udiskie : notify.py, automount) ---

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "--app-name=udiskie", "--icon=drive-removable-media", title, body]);
    }

    // Renvoie les disques LUKS arrivés verrouillés (phrase de passe à demander, `pending`).
    function notifyChanges(before, after, initial: bool): var {
        const arrived = [];
        const old = {};
        for (const v of before)
            old[v.path] = v;
        for (const v of after) {
            const o = old[v.path] && sameVolume(old[v.path], v) ? old[v.path] : undefined;
            if (!o && !initial && !v.backing)
                notify("Device added", `device appeared on ${v.device}`);
            if (o && !o.mounted && v.mounted)
                notify("Device mounted", `${v.uiLabel} mounted on ${v.mountPoint}`);
            if (o && o.mounted && !v.mounted)
                notify("Device unmounted", `${v.uiLabel} unmounted`);
            if (o && v.isCrypto && o.cleartext === "/" && v.cleartext !== "/")
                notify("Device unlocked", `${v.device} unlocked`);
            if (o && v.isCrypto && o.cleartext !== "/" && v.cleartext === "/")
                notify("Device locked", `${v.device} locked`);
            // Montage automatique : système de fichiers apparu (ou présent au démarrage), non monté.
            if (automount && (!o || initial) && v.isFilesystem && !v.mounted)
                mount(v);
            if (automount && !o && !initial && v.canUnlock && v.cleartext === "/")
                arrived.push(v);
        }
        for (const v of before)
            if (!after.some(a => sameVolume(a, v)) && !v.backing)
                notify("Device removed", `device disappeared on ${v.device}`);
        return arrived;
    }

    // Bouton Unlock : ce volume d'abord, les demandes en cours reprennent ensuite.
    function choose(v): void {
        pending = [v, ...pending.filter(p => !sameVolume(p, v))];
    }

    // Abandon : d'un volume (échec qui n'est pas la phrase de passe), ou de toutes (panneau fermé : Échap, clic à côté).
    function dismissPrompt(v): void {
        pending = pending.filter(p => !sameVolume(p, v));
    }

    function dismissPrompts(): void {
        if (pending.length > 0)
            pending = [];
    }

    // --- Actions (udisksctl) ---

    // `next` : appelé seulement si l'action réussit (enchaînements : démonter puis verrouiller, puis éteindre) ;
    // `failed(code, message)` : si elle échoue (-1 : commande pas démarrée).
    function run(action: string, device: string, command: var, input: string, next: var, failed: var): void {
        busy = [...busy, device];
        const p = actionProcess.createObject(root, { action, device, command, input, next: next ?? null, failed: failed ?? null });
        p.running = true;
    }

    // Action en cours sur le disque ou l'un de ses volumes (bouton d'éjection et lignes du disque : une seule règle).
    function driveBusy(drive): bool {
        return busy.some(d => d === drive.device || volumes.some(v => v.driveKey === drive.key && v.device === d));
    }

    // Étapes { action, device, command } l'une après l'autre ; la première qui échoue arrête la suite (notification « Job failed »).
    function sequence(steps: var): void {
        if (steps.length === 0)
            return;
        const [step, ...rest] = steps;
        run(step.action, step.device, step.command, "", () => sequence(rest));
    }

    function udisksctl(verb: string, device: string): var {
        return ["udisksctl", verb, "--no-user-interaction", "-b", device];
    }

    function unmountStep(v): var {
        return { action: "unmount", device: v.device, command: udisksctl("unmount", v.device) };
    }

    function lockStep(v): var {
        return { action: "lock", device: v.device, command: udisksctl("lock", v.device) };
    }

    function mount(v): void {
        run("mount", v.device, udisksctl("mount", v.device), "", null);
    }

    function unmount(v): void {
        sequence([unmountStep(v)]);
    }

    // `done(résultat)` : "ok", "wrong" (phrase refusée : à redemander) ou "failed" (autre cause : polkit, appareil occupé,
    // udisksctl absent ; la notification la donne), pour le champ de la phrase de passe.
    function unlock(v, passphrase: string, done: var): void {
        if (!v.canUnlock) {
            done?.("failed");
            return;
        }
        // cryptsetup : « Failed to activate device: Incorrect passphrase. » (« No key available with this passphrase. » avant 2.4).
        run("unlock", v.device, [...udisksctl("unlock", v.device), "--key-file", "/dev/stdin"], passphrase,
            () => done?.("ok"), (code, message) => done?.(/passphrase/i.test(message) ? "wrong" : "failed"));
    }

    // Verrouiller : démonter d'abord le volume déchiffré s'il est monté, puis verrouiller une fois le démontage fini.
    function lock(v): void {
        const clear = volumes.find(c => c.path === v.cleartext);
        sequence([...(clear?.mounted ? [unmountStep(clear)] : []), lockStep(v)]);
    }

    // Éjecter, comme udiskie : démonter les volumes du disque, verrouiller ses volumes chiffrés, puis l'éteindre (ou détacher
    // l'image disque, ou sortir le support d'un lecteur qui ne s'éteint pas : DVD ; udisksctl n'a pas de commande pour cela).
    // Une étape qui échoue (volume occupé) arrête tout : rien ne reste en attente.
    function eject(drive): void {
        const own = volumes.filter(v => v.driveKey === drive.key);
        const steps = [
            ...own.filter(v => v.mounted).map(unmountStep),
            ...own.filter(v => v.isCrypto && v.cleartext !== "/").map(lockStep)
        ];
        // Image « autoclear » (montée par GNOME Disks…) : libérée par le noyau à la dernière fermeture ; la détacher ensuite
        // échouerait (« Job failed » alors qu'elle est partie).
        if (drive.isLoop) {
            if (!drive.autoclear || steps.length === 0)
                steps.push({ action: "detach", device: drive.device, command: udisksctl("loop-delete", drive.device) });
        } else if (drive.canPowerOff) {
            steps.push({ action: "power off", device: drive.device, command: udisksctl("power-off", drive.device) });
        } else if (drive.ejectable) {
            steps.push({ action: "eject", device: drive.device, command: ["busctl", "--system", "call", "org.freedesktop.UDisks2", drive.key,
                    "org.freedesktop.UDisks2.Drive", "Eject", "a{sv}", "1", "auth.no_user_interaction", "b", "true"] });
        }
        sequence(steps);
    }

    function browse(v): void {
        if (v.mountPoint)
            Quickshell.execDetached(["xdg-open", v.mountPoint]);
    }

    Component {
        id: actionProcess

        Process {
            required property string action
            required property string device
            property string input: ""
            property var next: null
            property var failed: null
            property bool done: false

            // Commande qui ne démarre pas : Quickshell n'émet pas `exited`, seulement `running` faux. Méthode (pas une fonction
            // fléchée) pour Qt.callLater : l'appel est abandonné si l'objet a été détruit entre-temps (fin normale).
            function settleIfFailed(): void {
                if (!done)
                    finish(-1, `${command[0]} could not start`);
            }

            // Fin de l'action : notification d'échec, étape suivante, relecture. Nettoyage garanti même si un rappel échoue
            // (panneau détruit entre-temps) ; `destroy()` est différé, l'objet reste lisible jusqu'à la fin.
            function finish(code: int, error: string): void {
                done = true;
                input = "";
                try {
                    if (code !== 0) {
                        // « Error unlocking …: GDBus.Error:org.freedesktop.UDisks2.Error.Failed: Error unlocking …: <cause> » → dernière partie.
                        const message = error.trim().replace(/^[\s\S]*GDBus\.Error:\S+\s*/, "");
                        root.notify("Job failed", message ? `failed to ${action} ${device}:\n${message}` : `failed to ${action} device ${device}.`);
                        failed?.(code, message);
                    } else {
                        next?.();
                    }
                } finally {
                    // Après `next` : l'étape suivante est déjà inscrite, le disque reste occupé sans trou.
                    const i = root.busy.indexOf(device);
                    root.busy = root.busy.filter((_, j) => j !== i);
                    root.scheduleRefresh();
                    destroy();
                }
            }

            stdinEnabled: input !== ""
            stdout: StdioCollector {}
            stderr: StdioCollector {
                id: errors
            }
            onStarted: {
                if (input !== "") {
                    write(input);
                    stdinEnabled = false;   // fin de la phrase de passe : stdin fermé
                    input = "";
                }
            }
            onExited: code => finish(code, errors.text)
            onRunningChanged: if (!running) Qt.callLater(settleIfFailed)
        }
    }

    // --- Lecture et suivi ---

    // Changement signalé pendant une lecture : relu à la fin de celle-ci (sinon il serait perdu).
    property bool queryAgain: false

    // Relecture 300 ms après le premier signal d'une rafale (pas repoussée par les suivants : un flot continu la bloquerait).
    function scheduleRefresh(): void {
        if (!refresh.running)
            refresh.start();
    }

    // Dernier état lu, gardé au rechargement de la config : sans lui, tout volume démonté par toi serait remonté.
    PersistentProperties {
        id: persist
        reloadableId: "disks"

        property string read: ""   // [volumes, disques] en JSON : relecture sans changement ignorée

        onLoaded: root.read()
    }

    function read(): void {
        readFailed = true;   // remis à faux par une lecture réussie (parse)
        query.running = true;
    }

    Process {
        id: query
        command: ["busctl", "--system", "--json=short", "call", "org.freedesktop.UDisks2", "/org/freedesktop/UDisks2",
            "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: {
            if (root.queryAgain) {
                root.queryAgain = false;
                Qt.callLater(root.read);
            }
        }
        // Lecture ratée (UDisks2 pas encore prêt à l'ouverture de session, redémarré, busctl absent) : réessayée sans attendre
        // un signal ; sinon un disque retiré pendant l'échec resterait affiché. Après la lecture de la sortie (callLater).
        onRunningChanged: if (!running) Qt.callLater(root.checkRead)
    }

    function checkRead(): void {
        if (readFailed && !query.running) {
            failedReads++;
            retry.start();
        }
    }

    // 5 s, puis de plus en plus rarement (UDisks2 absent de la machine : 5 min au plus).
    Timer {
        id: retry
        interval: Math.min(5000 * 2 ** Math.max(root.failedReads - 1, 0), 300000)
        onTriggered: if (root.readFailed && !query.running) root.read()
    }

    Timer {
        id: refresh
        interval: 300
        onTriggered: {
            if (query.running)
                root.queryAgain = true;
            else
                root.read();
        }
    }

    // Tout signal d'UDisks2 (ajout, retrait, montage…) déclenche une relecture, sauf ceux des tâches (« jobs », relus par leurs
    // effets). Relancé s'il s'arrête ; ses lignes d'en-tête (« Monitoring signals… ») relisent tout à chaque démarrage.
    Process {
        id: monitor
        // Arrêté avec Quickshell (`qs kill`, fin de session) : sinon il lui survit (vu : un par relance de dev).
        command: ["setpriv", "--pdeathsig", "TERM", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.UDisks2"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (!line.includes("/UDisks2/jobs/"))
                    root.scheduleRefresh();
            }
        }
        // `running` faux aussi quand gdbus ne démarre pas (pas d'`exited`).
        onRunningChanged: if (!running) restartMonitor.start()
    }

    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }
}
