pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// Lecteur suivi par le module `mpris` et les touches média (Waybar). Waybar ne suivait que Spotify (`player`) et sa
// molette lançait `playerctld shift`, sans effet visible ; ici (ton choix du 2026-10-16) la molette passe d'un lecteur MPRIS
// à l'autre. Lecteur suivi (ton choix du 2026-10-16) : celui choisi à la molette, jusqu'au prochain démarrage d'une lecture ;
// sinon le lecteur préféré (`Settings.mediaPlayer`) s'il joue, sinon un lecteur qui joue (ex. Chromium seul en lecture),
// sinon le dernier suivi pendant une lecture, s'il est en pause (une pause ne fait pas passer au lecteur préféré : le clic suivant
// reprend la même lecture ; arrêté, il n'a plus rien à reprendre : ta demande du 2026-11-03, Chromium affiché vide), sinon le lecteur
// préféré, sinon le premier présent. Aucun lecteur → module masqué.
Singleton {
    id: root

    // `playerctld` (paquet playerctl) n'est qu'un relais qui recopie le lecteur actif : exclu, sinon il compterait en double.
    readonly property var players: Mpris.players.values.filter(p => p.dbusName !== "org.mpris.MediaPlayer2.playerctld")
    // Lecteurs en lecture.
    readonly property var playing: players.filter(p => p.isPlaying)
    property string selected: ""   // nom D-Bus choisi à la molette
    readonly property string preferred: `org.mpris.MediaPlayer2.${Settings.mediaPlayer}`
    property string recent: ""     // nom D-Bus du dernier lecteur suivi pendant une lecture
    readonly property MprisPlayer player: players.find(p => p.dbusName === selected)
        ?? playing.find(p => p.dbusName === preferred) ?? playing[0]
        ?? players.find(p => p.dbusName === recent && p.playbackState !== MprisPlaybackState.Stopped)
        ?? players.find(p => p.dbusName === preferred) ?? players[0] ?? null
    readonly property string playingName: player?.isPlaying ? player.dbusName : ""
    onPlayingNameChanged: if (playingName !== "") recent = playingName

    // Une lecture qui démarre annule le choix fait à la molette : le lecteur qui joue reprend la main. Sauf si c'est le lecteur
    // choisi qui démarre (lecture lancée depuis le module ou la carte média) : il reste suivi.
    property var lastPlaying: []
    onPlayingChanged: {
        const names = playing.map(p => p.dbusName);
        const started = names.filter(n => !lastPlaying.includes(n));
        if (started.length > 0 && !started.includes(selected))
            selected = "";
        lastPlaying = names;
    }
    Component.onCompleted: {
        lastPlaying = playing.map(p => p.dbusName);   // lecteurs déjà en lecture au démarrage
        recent = playingName;
    }
    // Nom du lecteur sans le préfixe ni l'instance (« chromium.instance1234 » → « chromium ») : clé de son icône.
    readonly property string playerName: (player?.dbusName ?? "").replace("org.mpris.MediaPlayer2.", "").split(".")[0]
    readonly property bool paused: player?.playbackState === MprisPlaybackState.Paused

    function togglePlaying(): void {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function previous(): void {
        if (player?.canGoPrevious)
            player.previous();
    }

    function next(): void {
        if (player?.canGoNext)
            player.next();
    }

    // Position (carte média) : en fraction du morceau, ou décalée en secondes ; sans effet si le lecteur a disparu ou
    // n'accepte pas les déplacements. La position n'est pas signalée en continu (documentation de MprisPlayer) : relue par
    // refreshPosition.
    readonly property real length: player?.lengthSupported ? player.length : 0

    function seek(fraction: real): void {
        if (player?.canSeek && length > 0)
            player.position = Math.max(0, Math.min(1, fraction)) * length;
    }

    function step(seconds: real): void {
        if (player?.canSeek && length > 0)
            player.position = Math.max(0, Math.min(length, player.position + seconds));
    }

    function refreshPosition(): void {
        player?.positionChanged();
    }

    // Molette : lecteur suivant (vers le haut) ou précédent, en boucle.
    function shift(up: bool): void {
        if (players.length < 2)
            return;
        const i = Math.max(0, players.indexOf(player));
        selected = players[(i + (up ? 1 : players.length - 1)) % players.length].dbusName;
    }

    // Touches média (raccourcis, phase 10) : `qs ipc call media <fonction>`, sur le lecteur suivi.
    IpcHandler {
        target: "media"

        function playPause(): void {
            root.togglePlaying();
        }

        function next(): void {
            root.next();
        }

        function previous(): void {
            root.previous();
        }
    }

}
