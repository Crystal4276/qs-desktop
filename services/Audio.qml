pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

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

    // Le volume d'un nœud n'est lisible et modifiable que s'il est suivi.
    PwObjectTracker {
        objects: root.sinks
    }

    // Volume plafonné à 100 % (`max-volume` par défaut de Waybar).
    function setVolume(v: real): void {
        if (ready)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // Pas en points de pourcentage (molette : ±5).
    function step(points: int): void {
        setVolume((percent + points) / 100);
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

    function openMixer(): void {
        Quickshell.execDetached(["pavucontrol"]);
    }
}
