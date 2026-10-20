pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// Lecteur suivi par le module `mpris` et les touches média (INVENTORY.md § 1). Waybar ne suivait que Spotify (`player`) et sa
// molette lançait `playerctld shift`, sans effet visible ; ici (ton choix du 2026-10-16) la molette passe d'un lecteur MPRIS
// à l'autre. Lecteur suivi (ton choix du 2026-10-16) : celui choisi à la molette, jusqu'au prochain démarrage d'une lecture ;
// sinon le lecteur préféré (`Settings.mediaPlayer`) s'il joue, sinon un lecteur qui joue (ex. Chromium seul en lecture),
// sinon le lecteur préféré, sinon le premier présent. Aucun lecteur → module masqué.
Singleton {
    id: root

    // `playerctld` (paquet playerctl) n'est qu'un relais qui recopie le lecteur actif : exclu, sinon il compterait en double.
    readonly property var players: Mpris.players.values.filter(p => p.dbusName !== "org.mpris.MediaPlayer2.playerctld")
    // Lecteurs en lecture ; non vide → le visualiseur cava est affiché (Cava.qml).
    readonly property var playing: players.filter(p => p.isPlaying)
    property string selected: ""   // nom D-Bus choisi à la molette
    readonly property string preferred: `org.mpris.MediaPlayer2.${Settings.mediaPlayer}`
    readonly property MprisPlayer player: players.find(p => p.dbusName === selected)
        ?? playing.find(p => p.dbusName === preferred) ?? playing[0]
        ?? players.find(p => p.dbusName === preferred) ?? players[0] ?? null

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
    Component.onCompleted: lastPlaying = playing.map(p => p.dbusName)   // lecteurs déjà en lecture au démarrage
    // Nom du lecteur sans le préfixe ni l'instance (« chromium.instance1234 » → « chromium ») : clé de son icône.
    readonly property string playerName: (player?.dbusName ?? "").replace("org.mpris.MediaPlayer2.", "").split(".")[0]
    readonly property bool paused: player?.playbackState === MprisPlaybackState.Paused

    // « Artiste - Titre » tronqué comme Waybar 0.15 (mpris.cpp, getDynamicStr) :
    // titre coupé à 20 colonnes avec « ... », puis artiste et titre gardés par priorité dans 40 colonnes.
    readonly property string dynamic: {
        if (!player)
            return "";
        const separator = " - ";
        const artist = player.trackArtist ?? "";
        const title = truncate(player.trackTitle ?? "", 20);
        const limit = 40 + separator.length;
        let total = 0;
        let showArtist = artist !== "", showTitle = title !== "";
        // Waybar ajoute le séparateur à la longueur de l'artiste, pas à celle du titre.
        const artistLen = width(artist) + (showArtist ? separator.length : 0);
        if (total + artistLen > limit)
            showArtist = false;
        else if (showArtist)
            total += artistLen;
        if (total + width(title) > limit)
            showTitle = false;
        return [showArtist ? artist : "", showTitle ? title : ""].filter(s => s !== "").join(separator);
    }

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

    // Largeur en colonnes : caractères larges (CJK, emojis) comptent 2, marques combinantes 0.
    function charWidth(c: string): int {
        const code = c.codePointAt(0);
        if (/\p{Mn}|\p{Me}|[​-‏­]/u.test(c))
            return 0;
        if ((code >= 0x1100 && code <= 0x115f) || (code >= 0x2e80 && code <= 0xa4cf) || (code >= 0xac00 && code <= 0xd7a3)
                || (code >= 0xf900 && code <= 0xfaff) || (code >= 0xfe30 && code <= 0xfe4f) || (code >= 0xff00 && code <= 0xff60)
                || (code >= 0xffe0 && code <= 0xffe6) || (code >= 0x1f300 && code <= 0x1f64f) || (code >= 0x1f900 && code <= 0x1f9ff)
                || (code >= 0x20000 && code <= 0x3fffd))
            return 2;
        return 1;
    }

    function width(s: string): int {
        let w = 0;
        for (const c of s)
            w += charWidth(c);
        return w;
    }

    // Coupe à `max` colonnes en terminant « ... », sans espace avant l'ellipse ; les espaces finaux tombent
    // même sans coupe (utf8_truncate de Waybar).
    function truncate(s: string, max: int): string {
        if (width(s) <= max)
            return s.replace(/\s+$/, "");
        const ellipsis = "...";
        const keep = max - ellipsis.length;
        let w = 0, end = 0, i = 0;
        for (const c of s) {
            w += charWidth(c);
            i += c.length;
            if (w <= keep && !/\s/.test(c))
                end = i;
        }
        return s.slice(0, end) + ellipsis;
    }
}
