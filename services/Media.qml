pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

// Lecteur suivi par le module `mpris` (INVENTORY.md § 1) : un seul, choisi par son nom D-Bus
// (`org.mpris.MediaPlayer2.<Settings.mediaPlayer>`, comme l'option `player` de Waybar). Absent → module masqué.
Singleton {
    id: root

    readonly property MprisPlayer player: Mpris.players.values.find(p => p.dbusName === `org.mpris.MediaPlayer2.${Settings.mediaPlayer}`) ?? null
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

    // Molette : `playerctld shift` / `unshift`, comme la config Waybar (sans effet visible : le module suit un seul lecteur).
    function shift(up: bool): void {
        Quickshell.execDetached(["playerctld", up ? "shift" : "unshift"]);
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
