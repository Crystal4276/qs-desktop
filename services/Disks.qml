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
    // Disques portant au moins un volume géré : { key, label, device (disque entier), canPowerOff, isLoop }
    // (clé : chemin du Drive UDisks2, ou du périphérique entier pour une image disque montée en boucle).
    property var drives: []
    property bool loaded: false

    // --- Lecture de l'état ---

    function decode(bytes): string {
        if (!bytes)
            return "";
        let s = "";
        for (const b of bytes) {
            if (b === 0)
                break;
            s += String.fromCharCode(b);
        }
        return s;
    }

    function value(iface, key) {
        return iface?.[key]?.data;
    }

    function parse(text: string): void {
        let objects;
        try {
            objects = JSON.parse(text).data[0];
        } catch (e) {
            console.warn(`Disks: lecture d'UDisks2 impossible : ${e}`);
            return;
        }
        const drivesByPath = {};
        for (const [path, ifs] of Object.entries(objects)) {
            const d = ifs["org.freedesktop.UDisks2.Drive"];
            if (d)
                drivesByPath[path] = {
                    path,
                    label: [value(d, "Vendor"), value(d, "Model")].filter(s => s).join(" "),
                    canPowerOff: value(d, "CanPowerOff") ?? false,
                    removable: value(d, "Removable") ?? false
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
                loops[path] = { path, label: decode(value(loop, "BackingFile")), device, canPowerOff: false, removable: true, isLoop: true };
        }
        const list = [];
        for (const [path, ifs] of Object.entries(objects)) {
            const b = ifs["org.freedesktop.UDisks2.Block"];
            if (!b || value(b, "HintIgnore"))
                continue;
            // Comme udiskie (mount.py) : une image disque en boucle est gérée même si UDisks2 la dit « système »,
            // sauf images du système (snaps, extensions).
            const partition = ifs["org.freedesktop.UDisks2.Partition"];
            const parent = drivesByPath[value(b, "Drive")] ?? loops[partition ? value(partition, "Table") : path];
            const userLoop = parent?.isLoop && parent.label !== "" && !/^\/var\/lib\/(extensions|confexts|snapd)\//.test(parent.label);
            if (value(b, "HintSystem") && !userLoop)
                continue;
            const fs = ifs["org.freedesktop.UDisks2.Filesystem"];
            const crypto = ifs["org.freedesktop.UDisks2.Encrypted"];
            if (!fs && !crypto)
                continue;
            // Volume déchiffré : rattaché à son volume chiffré (CryptoBackingDevice), affiché avec lui.
            const backing = value(b, "CryptoBackingDevice");
            const mountPoints = (value(fs, "MountPoints") ?? []).map(decode);
            const device = decode(value(b, "PreferredDevice")) || decode(value(b, "Device"));
            const label = value(b, "IdLabel") || value(b, "IdUUID") || parent?.label || "";
            list.push({
                path,
                device,
                label,
                uiLabel: [device, label].filter(s => s).join(": "),
                size: Number(value(b, "Size") ?? 0),
                fsType: value(b, "IdType") ?? "",
                isFilesystem: !!fs,
                isCrypto: !!crypto,
                backing: backing && backing !== "/" ? backing : "",
                cleartext: crypto ? (value(crypto, "CleartextDevice") ?? "/") : "/",
                mounted: mountPoints.length > 0,
                mountPoint: mountPoints[0] ?? "",
                driveKey: parent?.path ?? ""
            });
        }
        list.sort((a, b) => a.device.localeCompare(b.device));
        notifyChanges(volumes, list, !loaded);
        volumes = list;
        drives = [...Object.values(drivesByPath), ...Object.values(loops)].filter(d => list.some(v => v.driveKey === d.path))
            .map(d => ({ key: d.path, label: d.label, device: d.device, canPowerOff: d.canPowerOff, isLoop: d.isLoop ?? false }));
        loaded = true;
        const ejecting = drives.find(d => d.key === pendingEject);
        if (ejecting && !list.some(v => v.driveKey === ejecting.key && v.mounted))
            eject(ejecting);
    }

    // --- Notifications et montage automatique (udiskie : notify.py, automount) ---

    function notify(title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "--app-name=udiskie", "--icon=drive-removable-media", title, body]);
    }

    function notifyChanges(before, after, initial: bool): void {
        const old = {};
        for (const v of before)
            old[v.path] = v;
        for (const v of after) {
            const o = old[v.path];
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
            if ((!o || initial) && v.isFilesystem && !v.mounted)
                mount(v);
        }
        const now = new Set(after.map(v => v.path));
        for (const v of before)
            if (!now.has(v.path) && !v.backing)
                notify("Device removed", `device disappeared on ${v.device}`);
    }

    // --- Actions (udisksctl) ---

    function run(action: string, device: string, args: var, input: string): void {
        const p = actionProcess.createObject(root, { action, device, command: ["udisksctl", ...args], input });
        p.running = true;
    }

    function mount(v): void {
        run("mount", v.device, ["mount", "--no-user-interaction", "-b", v.device], "");
    }

    function unmount(v): void {
        run("unmount", v.device, ["unmount", "--no-user-interaction", "-b", v.device], "");
    }

    function unlock(v, passphrase: string): void {
        run("unlock", v.device, ["unlock", "--no-user-interaction", "-b", v.device, "--key-file", "/dev/stdin"], passphrase);
    }

    function lock(v): void {
        const clear = volumes.find(c => c.path === v.cleartext);
        if (clear?.mounted)
            unmount(clear);
        run("lock", v.device, ["lock", "--no-user-interaction", "-b", v.device], "");
    }

    // Éjecter : démonter les volumes du disque, puis (à la relecture suivante, une fois tout démonté) l'éteindre
    // ou détacher l'image disque.
    property string pendingEject: ""
    function eject(drive): void {
        const mounted = volumes.filter(v => v.driveKey === drive.key && v.mounted);
        if (mounted.length > 0) {
            pendingEject = drive.key;
            for (const v of mounted)
                unmount(v);
            return;
        }
        pendingEject = "";
        if (drive.isLoop)
            run("detach", drive.device, ["loop-delete", "--no-user-interaction", "-b", drive.device], "");
        else if (drive.canPowerOff)
            run("power off", drive.device, ["power-off", "--no-user-interaction", "-b", drive.device], "");
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

            stdinEnabled: input !== ""
            stdout: StdioCollector {}
            stderr: StdioCollector {
                id: errors
            }
            onStarted: {
                if (input !== "") {
                    write(input);
                    stdinEnabled = false;   // fin de la phrase de passe : stdin fermé
                }
            }
            onExited: code => {
                if (code !== 0) {
                    // « Error unlocking …: GDBus.Error:org.freedesktop.UDisks2.Error.Failed: Error unlocking …: <cause> » → dernière partie.
                    const message = errors.text.trim().replace(/^[\s\S]*GDBus\.Error:\S+\s*/, "");
                    root.notify("Job failed", message ? `failed to ${action} ${device}:\n${message}` : `failed to ${action} device ${device}.`);
                }
                refresh.restart();
                destroy();
            }
        }
    }

    // --- Lecture et suivi ---

    Process {
        id: query
        command: ["busctl", "--system", "--json=short", "call", "org.freedesktop.UDisks2", "/org/freedesktop/UDisks2",
            "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        id: refresh
        interval: 300
        onTriggered: query.running = true
    }

    // Tout signal d'UDisks2 (ajout, retrait, montage…) déclenche une relecture. Relancé s'il s'arrête.
    Process {
        id: monitor
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.UDisks2"]
        running: true
        stdout: SplitParser {
            onRead: refresh.restart()
        }
        onExited: restartMonitor.start()
    }

    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }
}
