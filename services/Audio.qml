pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config

// Sortie audio par défaut (INVENTORY.md § 1, modules `pulseaudio` et `pulseaudio/slider`).
// Volume en échelle « cubique », comme pavucontrol, wpctl et Waybar.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.audio !== undefined && sink?.audio !== null
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    // Pourcentage entier, arrondi comme Waybar (pa_cvolume_avg × 100, arrondi).
    readonly property int percent: Math.round(volume * 100)
    readonly property string description: sink?.description ?? ""

    // Sorties matérielles, dans l'ordre de leurs identifiants (ordre de `wpctl status`).
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio).sort((a, b) => a.id - b.id)
    // Panneau audio : entrées (micros), entrée par défaut, applications qui jouent du son.
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio).sort((a, b) => a.id - b.id)
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Changement fait au clavier (IPC ci-dessous) : affiché par l'OSD (modules/osd). "volume" ou "mic".
    signal changedByKey(string kind)
    // Lectures seulement (type `AudioOutStream` = Audio | Stream | Sink, ex. Spotify) : les enregistrements (Audio | Stream |
    // Source, ex. un enregistreur) sont exclus. `media.class` n'est pas dans les propriétés exposées par Quickshell.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && (n.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream)
        .sort((a, b) => a.id - b.id)

    // Le volume d'un nœud n'est lisible et modifiable que s'il est suivi.
    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    // « Ne pas déranger » : coupe les sons de notification joués par les applications de `doNotDisturb.muteApps` (binaires) et
    // `muteWebApps` (`--class=` d'une web app Chromium), sauf les appels Discord ; rétablis à la fin (PROGRESS.md, 2026-10-27).
    readonly property bool hushed: Notifs.doNotDisturb
    readonly property var hushApps: lowerList(Settings.doNotDisturb.muteApps)
    readonly property var hushWebApps: lowerList(Settings.doNotDisturb.muteWebApps)
    // Attend l'état repris de « ne pas déranger » et la liste des nœuds : sinon, au rechargement, tout serait rétabli. Pas
    // dans l'instance de scripts/test-outputs.sh (QS_TEST) : elle partage PipeWire.
    readonly property bool hushReady: Notifs.loaded && Pipewire.ready && !Quickshell.env("QS_TEST")
    // pid → { classes: `--class=` du processus et de son parent (minuscules), seen: dernier flux vu (ms) } ; pid en lecture.
    property var processClasses: ({})
    property var pendingPids: []
    // Flux présents quand « ne pas déranger » commence (ou au chargement) : en cours (un appel…), jamais coupés. Les objets,
    // pas les id : un id PipeWire resert vite.
    property var playingNodes: []
    onHushedChanged: startHush()
    onHushAppsChanged: syncHush()
    onHushWebAppsChanged: syncHush()
    onHushReadyChanged: startHush()
    onStreamsChanged: syncHush()

    function startHush(): void {
        if (hushed) {
            playingNodes = streams.slice();
            processClasses = {};   // relus chaque nuit : un pid finit par resservir
        }
        syncHush();
    }

    function lowerList(list: var): var {
        return (Array.isArray(list) ? list : []).map(a => String(a).toLowerCase());
    }

    function processId(node: PwNode): string {
        return String(node.properties["application.process.id"] ?? "");
    }

    // Flux "id:serial", gardé dans le fichier d'état : un id PipeWire resert vite, `object.serial` jamais.
    function hushKey(node: PwNode): string {
        return `${node.id}:${node.properties["object.serial"] ?? ""}`;
    }

    // true : à couper ; false : non ; undefined : flux Chromium dont le processus n'est pas encore lu (seul cas où `--class=`
    // compte ; la règle WirePlumber l'empêche de retenir la coupure d'office).
    function hushTarget(node: PwNode): var {
        if (node.properties["application.name"] === "WEBRTC VoiceEngine")   // appels Discord
            return false;
        if (hushApps.includes((node.properties["application.process.binary"] ?? "").toLowerCase()))
            return true;
        const pid = processId(node);
        if (hushWebApps.length === 0 || pid === "" || node.properties["application.name"] !== "Chromium")
            return false;
        return processClasses[pid]?.classes.some(c => hushWebApps.includes(c));
    }

    // Une passe par tour de boucle d'événements, quel que soit le nombre de signaux.
    function syncHush(): void {
        if (hushReady && (hushed || hushState.owned.length > 0 || hushState.released.length > 0))
            Qt.callLater(hushPass);
    }

    // Flux qui naît pendant « ne pas déranger », processus pas encore lu : coupé d'office le temps de la lecture (inaudible,
    // mesuré). Rétabli à la main pendant « ne pas déranger » (ex. un appel WhatsApp) : laissé tel quel.
    function hushPass(): void {
        // Gardés tant que leur flux existe (serial vide : nœud pas encore lu).
        const keys = new Set(streams.map(n => hushKey(n)));
        const exists = key => keys.has(key) || keys.has(`${key.split(":")[0]}:`);
        const owned = Array.from(hushState.owned).filter(exists);
        const released = new Set(Array.from(hushState.released).filter(exists));
        const live = new Set(streams);
        if (playingNodes.some(n => !live.has(n)))
            playingNodes = playingNodes.filter(n => live.has(n));
        const lookups = new Set();
        for (const n of streams.filter(n => n.ready && n.audio && n.properties["object.serial"] !== undefined)) {
            const key = hushKey(n);
            const target = hushTarget(n);
            if (hushed && target === undefined)
                lookups.add(processId(n));
            if (released.has(key))
                continue;
            if (owned.includes(key)) {
                if (hushed && target !== false) {   // processus pas encore lu (rechargement) : décidé après
                    if (!n.audio.muted)
                        n.audio.muted = true;
                } else {
                    if (n.audio.muted)
                        n.audio.muted = false;
                    if (!n.audio.muted)
                        owned.splice(owned.indexOf(key), 1);
                }
            } else if (hushed && target !== false && !playingNodes.includes(n) && !n.audio.muted) {
                n.audio.muted = true;
                owned.push(key);
            }
        }
        if (owned.join() !== Array.from(hushState.owned).join())
            hushState.owned = owned;
        const stillReleased = hushed ? [...released] : [];
        if (stillReleased.join() !== Array.from(hushState.released).join())
            hushState.released = stillReleased;
        const added = [...lookups].filter(pid => !pendingPids.includes(pid));
        if (added.length > 0)
            pendingPids = [...pendingPids, ...added];
        // Processus lus : oubliés 10 min après leur dernier flux (un pid finit par resservir à un autre programme).
        const now = Date.now();
        const pids = new Set(streams.map(n => processId(n)));
        const kept = {};
        for (const pid of Object.keys(processClasses)) {
            const entry = processClasses[pid];
            if (pids.has(pid))
                entry.seen = now;
            if (now - entry.seen < 600000)
                kept[pid] = entry;
        }
        if (Object.keys(kept).length !== Object.keys(processClasses).length)
            processClasses = kept;
    }

    function saveHush(): void {
        hushFile.writeAdapter();
    }

    // Rétabli à la main alors que le shell l'avait coupé : laissé tel quel jusqu'à la fin de « ne pas déranger ».
    function release(node: PwNode): void {
        const key = hushKey(node);
        if (!hushed || node.audio.muted || hushTarget(node) === false || !hushState.owned.includes(key)
                || hushState.released.includes(key))
            return;
        hushState.released = [...hushState.released, key];
        hushState.owned = Array.from(hushState.owned).filter(k => k !== key);   // une écriture (writeAdapter différé)
    }

    function learnProcess(pid: string, cmdlines: string): void {
        processClasses = Object.assign({}, processClasses, {
            [pid]: {
                classes: cmdlines.split(/[\s\0]+/).filter(a => a.startsWith("--class=")).map(a => a.slice(8).toLowerCase()),
                seen: Date.now()
            }
        });
        Qt.callLater(() => pendingPids = pendingPids.filter(p => p !== pid));
        syncHush();
    }

    // Lignes de commande du processus et de son parent : le processus audio d'une web app n'a pas `--class=`, son parent si.
    Instantiator {
        model: ScriptModel {
            values: root.pendingPids
        }
        delegate: Scope {
            id: lookup

            required property string modelData
            property string ppid: ""   // "-" : illisible
            property int unread: 2
            property string cmdlines: ""

            function add(text: string): void {
                cmdlines += " " + text;
                if (--unread === 0)
                    root.learnProcess(modelData, cmdlines);
            }

            onPpidChanged: if (ppid === "-") add("")

            FileView {
                path: `/proc/${lookup.modelData}/status`
                printErrors: false
                onLoaded: lookup.ppid = /^PPid:\s*(\d+)/m.exec(text())?.[1] ?? "-"
                onLoadFailed: lookup.ppid = "-"
            }

            FileView {
                path: `/proc/${lookup.modelData}/cmdline`
                printErrors: false
                onLoaded: lookup.add(text())
                onLoadFailed: lookup.add("")
            }

            FileView {
                path: lookup.ppid === "" || lookup.ppid === "-" ? "" : `/proc/${lookup.ppid}/cmdline`
                printErrors: false
                onLoaded: lookup.add(text())
                onLoadFailed: lookup.add("")
            }
        }
    }

    // Flux suivi (réglable) ; coupure changée ailleurs (rétablie à la main, ou par WirePlumber).
    Instantiator {
        model: ScriptModel {
            values: root.hushApps.length > 0 || root.hushWebApps.length > 0 || hushState.owned.length > 0 ? root.streams : []
        }
        delegate: Scope {
            id: watch

            required property PwNode modelData

            Connections {
                target: watch.modelData
                function onReadyChanged(): void {
                    root.syncHush();
                }
            }

            Connections {
                target: watch.modelData.audio
                function onMutedChanged(): void {
                    root.release(watch.modelData);
                    root.syncHush();
                }
            }
        }
    }

    // Flux coupés par le shell, et ceux rétablis à la main depuis : gardés au redémarrage de Quickshell.
    FileView {
        id: hushFile
        path: Quickshell.statePath("audio-hush.json")
        blockLoading: true
        printErrors: false
        onAdapterUpdated: Qt.callLater(root.saveHush)   // une écriture pour plusieurs listes changées

        JsonAdapter {
            id: hushState
            property list<string> owned: []
            property list<string> released: []
        }
    }

    // Nom affiché d'un périphérique : surnom, sinon description, sinon nom technique.
    function nodeName(node: PwNode): string {
        return node.nickname || node.description || node.name;
    }

    // Niveau capté affiché (panneau audio) : pas pour une entrée Bluetooth, dont la capture ferait passer le casque du profil
    // A2DP (musique) au profil micro (HSP/HFP, son dégradé) tant que le panneau est ouvert.
    function hasLevel(node: PwNode): bool {
        return node !== null && !node.name.startsWith("bluez_") && !node.properties["api.bluez5.address"];
    }

    function setDefaultSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node: PwNode): void {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // Volume plafonné à 100 % (`max-volume` par défaut de Waybar).
    function setVolume(v: real): void {
        if (ready)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // Pas en points de pourcentage (molette : ±5). Au-dessus de 100 % (réglé ailleurs, ex. pavucontrol), comme Waybar : monter
    // ne fait rien, baisser retire un pas (pas de saut à 100 %).
    function step(points: int): void {
        if (!ready || (points > 0 && percent >= 100))
            return;
        sink.audio.volume = Math.max(0, Math.min(Math.max(1, volume), (percent + points) / 100));
    }

    function toggleMute(): void {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    // Sortie suivante, en boucle ; volume réglé à 60 % et notification (remplace audio-toggle.sh, SCRIPTS.md).
    function cycleSink(): void {
        const list = sinks;
        if (list.length === 0) {
            Quickshell.execDetached(["notify-send", "Audio Switch Error", "No sinks found!"]);
            return;
        }
        const i = list.findIndex(n => n.id === sink?.id);
        const next = list[(i + 1) % list.length];
        Pipewire.preferredDefaultAudioSink = next;
        next.audio.volume = 0.6;
        Quickshell.execDetached(["notify-send", "Audio Switch", next.description]);
    }

    function toggleMicMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Touches volume et micro (raccourcis, phase 10 ; Sway : pactl ±5 %, muet, micro muet) : `qs ipc call audio <fonction>`.
    // Volume plafonné à 100 % comme la molette (pactl n'avait pas de plafond).
    IpcHandler {
        target: "audio"

        function volumeUp(): void {
            root.step(5);
            root.changedByKey("volume");
        }

        function volumeDown(): void {
            root.step(-5);
            root.changedByKey("volume");
        }

        function toggleMute(): void {
            root.toggleMute();
            root.changedByKey("volume");
        }

        function toggleMicMute(): void {
            root.toggleMicMute();
            root.changedByKey("mic");
        }

        // Sortie suivante (`$mod+s`, remplace audio-toggle.sh).
        function cycleSink(): void {
            root.cycleSink();
        }
    }

    // Réglages avancés (bouton du panneau audio).
    function openMixer(): void {
        Quickshell.execDetached(["pavucontrol"]);
    }
}
