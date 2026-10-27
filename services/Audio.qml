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

    // « Ne pas déranger » (ta demande du 2026-10-27) : Discord et le navigateur jouent eux-mêmes le son de leurs notifications,
    // sur leur propre flux. Pendant « ne pas déranger », les flux des applications de `doNotDisturb.muteApps` (hosts/*.json,
    // nom du binaire) sont coupés, appels compris ; à la fin, ceux coupés ainsi sont rétablis.
    // WirePlumber retient la coupure par nom d'application (restore-stream) et l'appliquerait au flux suivant de ce nom, même
    // après « ne pas déranger » : ces noms sont gardés dans un fichier d'état, et le premier flux de chacun, rétabli, efface
    // ce souvenir.
    readonly property bool hushed: Notifs.doNotDisturb
    readonly property var hushApps: (Settings.doNotDisturb.muteApps ?? []).map(a => String(a).toLowerCase())
    onHushedChanged: syncHush()
    onStreamsChanged: syncHush()

    function hushKey(node: PwNode): string {
        return node.properties["application.name"] ?? node.name;
    }

    // Binaire, sinon nom de l'application (un flux PipeWire natif peut ne pas donner son binaire).
    function hushTarget(node: PwNode): bool {
        const binary = (node.properties["application.process.binary"] ?? "").toLowerCase();
        const name = (node.properties["application.name"] ?? "").toLowerCase();
        return (binary !== "" && hushApps.includes(binary)) || (name !== "" && hushApps.includes(name));
    }

    function syncHush(): void {
        const ready = streams.filter(n => n.ready && n.audio);
        const keys = Array.from(hushState.keys);
        if (hushed) {
            for (const n of ready) {
                if (hushTarget(n) && !n.audio.muted) {
                    n.audio.muted = true;
                    if (!keys.includes(hushKey(n)))
                        keys.push(hushKey(n));
                }
            }
            if (keys.length !== hushState.keys.length)
                hushState.keys = keys;
        } else if (keys.length > 0) {
            const restored = [];
            for (const n of ready) {
                if (keys.includes(hushKey(n)) && n.audio.muted) {
                    n.audio.muted = false;
                    restored.push(hushKey(n));
                }
            }
            if (restored.length > 0)
                hushState.keys = keys.filter(k => !restored.includes(k));
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

    // Rétabli à la main pendant « ne pas déranger » : recoupé. WirePlumber applique la coupure retenue un peu après l'arrivée
    // du flux : rétabli aussi.
    Instantiator {
        model: root.streams.filter(n => n.ready && n.audio
            && (root.hushed ? root.hushTarget(n) : hushState.keys.includes(root.hushKey(n))))
        delegate: Connections {
            required property PwNode modelData
            target: modelData.audio
            function onMutedChanged(): void {
                root.syncHush();
            }
        }
    }

    FileView {
        path: Quickshell.statePath("dnd-muted.json")
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.syncHush()

        JsonAdapter {
            id: hushState
            property list<string> keys: []
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
