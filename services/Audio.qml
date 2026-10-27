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

    // « Ne pas déranger » (ta demande du 2026-10-27) : Discord et la web app WhatsApp jouent eux-mêmes le son de leurs
    // notifications, sur leur propre flux. Pendant « ne pas déranger », les flux des applications de `doNotDisturb.muteApps`
    // (hosts/*.json : nom du binaire, ou `--class=` d'une web app Chromium) sont coupés, puis rétablis à la fin. Restent
    // audibles : le navigateur (même binaire qu'une web app, sans `--class=`) et les appels de Discord (moteur vocal WebRTC,
    // flux à part). Un flux coupé dès son apparition ne laisse rien passer (mesuré).
    // Le `--class=` se lit dans /proc, une fois par processus : en attendant, pendant « ne pas déranger », le flux d'un
    // processus pas encore examiné est coupé (quelques ms, inaudible au début d'une vidéo ; mesuré).
    // WirePlumber retiendrait la coupure par nom d'application, « Chromium » pour tous ces flux comme pour le navigateur :
    // dotfiles/wireplumber/ le lui interdit.
    readonly property bool hushed: Notifs.doNotDisturb
    readonly property var hushApps: (Settings.doNotDisturb.muteApps ?? []).map(a => String(a).toLowerCase())
    // Processus examinés : pid → valeurs de `--class=` du processus et de son parent (minuscules) ; pid à examiner.
    property var processClasses: ({})
    property var pendingPids: []
    property bool hushLoaded: false   // hushPersist repris (avant : rien n'est touché)
    onHushedChanged: syncHush()
    onStreamsChanged: syncHush()

    // true : à couper ; false : non ; undefined : processus pas encore examiné.
    function hushTarget(node: PwNode): var {
        if (node.properties["application.name"] === "WEBRTC VoiceEngine")
            return false;
        if (hushApps.includes((node.properties["application.process.binary"] ?? "").toLowerCase()))
            return true;
        const pid = String(node.properties["application.process.id"] ?? "");
        if (pid === "")
            return false;
        return processClasses[pid]?.some(c => hushApps.includes(c));
    }

    // Coupe les flux visés pendant « ne pas déranger » ; rétablit ceux coupés ainsi, à la fin ou si le flux n'est pas visé.
    function syncHush(): void {
        if (!hushLoaded)
            return;
        const live = streams.filter(n => n.ready && n.audio);
        const owned = JSON.parse(hushPersist.owned).filter(id => live.some(n => n.id === id));
        const lookups = [];
        for (const n of live) {
            const target = hushTarget(n);
            if (hushed && target === undefined)
                lookups.push(String(n.properties["application.process.id"]));
            if (hushed && target !== false) {
                if (!n.audio.muted) {
                    n.audio.muted = true;
                    owned.push(n.id);
                }
            } else if (owned.includes(n.id)) {
                if (n.audio.muted)
                    n.audio.muted = false;
                owned.splice(owned.indexOf(n.id), 1);
            }
        }
        hushPersist.owned = JSON.stringify(owned);
        const added = lookups.filter((pid, i) => lookups.indexOf(pid) === i && !pendingPids.includes(pid));
        if (added.length > 0)
            pendingPids = [...pendingPids, ...added];
    }

    function learnProcess(pid: string, cmdlines: string): void {
        processClasses = Object.assign({}, processClasses, {
            [pid]: cmdlines.split(/\s+/).filter(a => a.startsWith("--class=")).map(a => a.slice(8).toLowerCase())
        });
        Qt.callLater(() => pendingPids = pendingPids.filter(p => p !== pid));
        syncHush();
    }

    // Ligne de commande du processus et de son parent (le processus audio d'une web app n'a pas `--class=`, le navigateur
    // qui l'a lancé si). Chromium remplace les séparateurs par des espaces.
    Instantiator {
        model: root.pendingPids
        delegate: Process {
            required property string modelData
            running: true
            command: ["sh", "-c", "for p in $1 $(awk '/^PPid:/ { print $2 }' /proc/$1/status); do tr '\\0' ' ' < /proc/$p/cmdline; echo; done",
                "sh", modelData]
            stdout: StdioCollector {
                onStreamFinished: root.learnProcess(modelData, text)
            }
        }
    }

    // Un flux n'est réglable qu'une fois suivi (`ready`).
    Instantiator {
        model: root.streams
        delegate: Connections {
            required property PwNode modelData
            target: modelData
            function onReadyChanged(): void {
                root.syncHush();
            }
        }
    }

    // Rétabli à la main pendant « ne pas déranger » : recoupé.
    Instantiator {
        model: root.hushed ? root.streams.filter(n => n.ready && n.audio && root.hushTarget(n) !== false) : []
        delegate: Connections {
            required property PwNode modelData
            target: modelData.audio
            function onMutedChanged(): void {
                root.syncHush();
            }
        }
    }

    // Flux coupés par « ne pas déranger » (identifiants PipeWire), gardés au rechargement de la config. En texte JSON : un
    // tableau JavaScript ne passe pas d'un moteur QML au suivant.
    PersistentProperties {
        id: hushPersist
        reloadableId: "audioHush"
        property string owned: "[]"

        onLoaded: {
            root.hushLoaded = true;
            root.syncHush();
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
