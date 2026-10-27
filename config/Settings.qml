pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Options de la machine : hosts/default.json, puis hosts/<hostname>.json par-dessus
// (fusion au premier niveau : une clé présente dans le fichier machine remplace celle par défaut).
// Format : docs/ARCHITECTURE.md § 4.
Singleton {
    id: root

    readonly property string hostname: hostnameFile.text().trim()
    readonly property var config: Object.assign({}, parse(defaultFile), parse(hostFile))

    readonly property string primaryOutput: config.primaryOutput ?? ""
    // Seuls les objets sont gardés : une entrée mal formée (null, liste…) ne doit pas casser la répartition.
    readonly property var workspaceLayouts: (Array.isArray(config.workspaceLayouts) ? config.workspaceLayouts : [])
        .filter(l => l !== null && typeof l === "object" && !Array.isArray(l))
    readonly property var bars: config.bars ?? ({})
    readonly property string notificationsOutput: config.notificationsOutput ?? "primary"
    // Préfixe qui lance une commande dans un terminal et attend sa fin, ex. ["gnome-terminal", "--wait", "--"].
    readonly property var terminal: config.terminal ?? []
    readonly property string updateCommand: config.updateCommand ?? ""
    // Lecteur suivi par le module `mpris` : nom D-Bus après `org.mpris.MediaPlayer2.` (option `player` de Waybar).
    readonly property string mediaPlayer: config.mediaPlayer ?? ""
    // Fonds d'écran (docs/WALLPAPERS.md) : dossier (vide : « Wallpapers » dans le dossier Images XDG) et choix de départ, tant que
    // rien n'a été choisi dans l'utilitaire : { kind: "simple" | "panorama" | "triptych", path: chemin relatif au dossier }.
    readonly property string wallpapersDir: config.wallpapersDir ?? ""
    readonly property var wallpaper: config.wallpaper ?? null
    // Veille des écrans (services/Idle.qml) : `timeout` en secondes (0 : jamais) ; `lockBeforeSleep` : verrouiller avant la mise
    // en veille du système (null : seulement sur une machine avec batterie).
    readonly property var idle: Object.assign({ timeout: 300, lockBeforeSleep: null }, config.idle ?? {})
    // Veilleuse : de `from` à `to` (HH:MM, différentes), `temperature` en kelvins la nuit (hosts/default.json : tes réglages GNOME).
    readonly property var nightLight: Object.assign({ from: "20:00", to: "06:00", temperature: 3239 }, config.nightLight ?? {})
    // « Ne pas déranger » programmé (services/Notifs.qml) : actif de `from` à `to` (HH:MM) si `schedule`. Valeurs de départ :
    // ensuite réglées depuis le panneau de réglages et gardées dans un fichier d'état.
    // `muteApps` : applications coupées pendant « ne pas déranger », binaire ou `--class=` (services/Audio.qml ; demande la
    // règle dotfiles/wireplumber/).
    readonly property var doNotDisturb: Object.assign({ schedule: true, from: "21:00", to: "07:00", muteApps: [] }, config.doNotDisturb ?? {})

    // Heure "HH:MM" ("9:5" accepté) → minutes depuis minuit ; -1 si elle est mal formée (veilleuse, « ne pas déranger »).
    function minutes(time: string): int {
        const match = /^([01]?\d|2[0-3]):([0-5]?\d)$/.exec(time ?? "");
        return match ? Number(match[1]) * 60 + Number(match[2]) : -1;
    }

    // Minutes depuis minuit → "HH:MM" ("" si négatif).
    function timeText(minutes: int): string {
        const pad = n => String(n).padStart(2, "0");
        return minutes < 0 ? "" : `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
    }

    // Pilules d'une barre : l'écran principal a la barre `primary` (tray, réglages, menu), même s'il a sa propre entrée : un
    // écran secondaire devenu seul ou principal les garde ; les autres, par description d'écran, sinon `secondary`.
    // Renvoie { left: [[module, …], …], right: […] }.
    function barFor(description: string, primary: bool): var {
        return (primary ? bars.primary : null) ?? bars[description] ?? bars.secondary ?? ({ left: [], right: [] });
    }

    function parse(file: FileView): var {
        const text = file.loaded ? file.text() : "";
        if (text === "")
            return {};
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn(`Settings: ${file.path} invalide : ${e}`);
            return {};
        }
    }

    FileView {
        id: hostnameFile
        path: "/proc/sys/kernel/hostname"
        blockLoading: true
    }

    FileView {
        id: defaultFile
        path: Quickshell.shellPath("hosts/default.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: hostFile
        path: root.hostname === "" ? "" : Quickshell.shellPath(`hosts/${root.hostname}.json`)
        blockLoading: true
        printErrors: false   // pas de fichier pour cette machine : valeurs par défaut
        watchChanges: true
        onFileChanged: reload()
    }
}
