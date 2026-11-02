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

    // « Ne pas déranger » : coupe les sons de notification des applications de `doNotDisturb.muteApps`, repérées par
    // l'`application.id` donné à leur lancement (web apps : `env PULSE_PROP_OVERRIDE=application.id=whatsapp …`) ou par leur
    // binaire (application Discord), sauf les appels de l'application Discord ; rétablis à la fin. Un son en cours au début
    // n'est pas touché ; rétabli à la main pendant « ne pas déranger » : laissé (PROGRESS.md, 2026-10-27).
    readonly property bool hushed: Notifs.doNotDisturb
    readonly property var hushApps: (Array.isArray(Settings.doNotDisturb.muteApps) ? Settings.doNotDisturb.muteApps : [])
        .map(a => String(a).toLowerCase())
    // Attend l'état repris de « ne pas déranger » et la liste des nœuds : sinon, au rechargement, tout serait rétabli. Pas
    // dans l'instance de scripts/test-outputs.sh (QS_TEST) : elle partage PipeWire.
    readonly property bool hushReady: Notifs.loaded && Pipewire.ready && !Quickshell.env("QS_TEST")
    // Flux présents quand « ne pas déranger » commence (ou au chargement) : en cours (un appel…), jamais coupés. Les objets,
    // pas les id : un id PipeWire resert vite.
    property var playingNodes: []
    onHushedChanged: startHush()
    onHushAppsChanged: syncHush()
    onHushReadyChanged: startHush()
    onStreamsChanged: syncHush()
    // Flux suivis : un flux devenu visé (propriétés lues après coup) peut être déjà prêt, sans signal à suivre.
    readonly property var hushWatched: streams.filter(n => hushCandidate(n))
    onHushWatchedChanged: syncHush()

    function startHush(): void {
        playingNodes = hushed ? streams.slice() : [];
        syncHush();
    }

    // Flux "id:serial:pid", gardé dans le fichier d'état : un id PipeWire resert vite, `object.serial` jamais tant que PipeWire
    // tourne ; le pid distingue une autre session (fichier gardé, PipeWire relancé).
    function hushKey(node: PwNode): string {
        const props = node.properties;
        return `${node.id}:${props["object.serial"] ?? ""}:${props["application.process.id"] ?? ""}`;
    }

    // Flux « Chromium » seulement, comme la règle WirePlumber : ni les appels de l'application Discord (« WEBRTC VoiceEngine »),
    // ni un programme lancé depuis une web app (Spotify par un lien : il hérite de son application.id).
    function hushTarget(node: PwNode): bool {
        const props = node.properties;
        return props["application.name"] === "Chromium" && [props["application.id"], props["application.process.binary"]]
            .some(v => v !== undefined && hushApps.includes(String(v).toLowerCase()));
    }

    // Flux visé, ou que le shell a touché : seuls ceux-là sont suivis.
    function hushCandidate(node: PwNode): bool {
        const key = hushKey(node);
        return hushTarget(node) || hushState.owned.includes(key) || hushState.released.includes(key);
    }

    // Une passe par tour de boucle d'événements, quel que soit le nombre de signaux.
    function syncHush(): void {
        if (hushReady && ((hushed && hushApps.length > 0) || hushState.owned.length > 0 || hushState.released.length > 0))
            Qt.callLater(hushPass);
    }

    function hushPass(): void {
        // Gardés tant que leur flux existe (serial vide : nœud pas encore lu).
        const keys = new Set(streams.map(n => hushKey(n)));
        const exists = key => keys.has(key) || keys.has(`${key.split(":")[0]}::`);
        const owned = Array.from(hushState.owned).filter(exists);
        const released = new Set(Array.from(hushState.released).filter(exists));
        const live = new Set(streams);
        if (playingNodes.some(n => !live.has(n)))
            playingNodes = playingNodes.filter(n => live.has(n));
        for (const n of streams.filter(n => n.ready && n.audio && n.properties["object.serial"] !== undefined)) {
            const key = hushKey(n);
            const target = hushTarget(n);
            if (released.has(key))
                continue;
            if (owned.includes(key)) {
                if (hushed && target) {
                    if (!n.audio.muted)
                        n.audio.muted = true;
                } else {
                    if (n.audio.muted)
                        n.audio.muted = false;
                    if (!n.audio.muted)
                        owned.splice(owned.indexOf(key), 1);
                }
            } else if (hushed && target && !playingNodes.includes(n) && !n.audio.muted) {
                n.audio.muted = true;
                owned.push(key);
            }
        }
        const stillReleased = hushed ? [...released] : [];
        if (owned.join() !== Array.from(hushState.owned).join() || stillReleased.join() !== Array.from(hushState.released).join()) {
            hushState.owned = owned;
            hushState.released = stillReleased;
            hushFile.writeAdapter();   // aussitôt : une coupure non écrite ne serait jamais rétablie après un plantage
        }
    }

    // Rétabli à la main alors que le shell l'avait coupé : laissé tel quel jusqu'à la fin de « ne pas déranger ».
    function release(node: PwNode): void {
        const key = hushKey(node);
        if (!hushed || node.audio.muted || !hushTarget(node) || !hushState.owned.includes(key) || hushState.released.includes(key))
            return;
        hushState.released = [...hushState.released, key];
        hushState.owned = Array.from(hushState.owned).filter(k => k !== key);
        hushFile.writeAdapter();
    }

    // Flux suivi (réglable) ; coupure changée ailleurs (rétablie à la main).
    Instantiator {
        model: ScriptModel {
            values: root.hushWatched
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

        // Pas d'OSD sans périphérique : il annoncerait un micro ouvert à 0 %, alors que rien n'a changé.
        function volumeUp(): void {
            root.step(5);
            if (root.ready)
                root.changedByKey("volume");
        }

        function volumeDown(): void {
            root.step(-5);
            if (root.ready)
                root.changedByKey("volume");
        }

        function toggleMute(): void {
            root.toggleMute();
            if (root.ready)
                root.changedByKey("volume");
        }

        function toggleMicMute(): void {
            root.toggleMicMute();
            if (root.source?.audio)
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
