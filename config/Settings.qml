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
    readonly property var workspaceLayouts: config.workspaceLayouts ?? []
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
    // Veille des écrans (services/Idle.qml) : `timeout` en secondes (0 : jamais) ; `primaryWakeDelay` : secondes avant de rallumer
    // l'écran principal après les autres (contournement d'un écran lent à se réveiller, repris de hypridle) ; `lockBeforeSleep` :
    // verrouiller avant la mise en veille du système (null : seulement sur une machine avec batterie).
    readonly property var idle: Object.assign({ timeout: 300, primaryWakeDelay: 0, lockBeforeSleep: null }, config.idle ?? {})
    // Veilleuse : de `from` à `to` (HH:MM, nuit qui passe minuit : limite de gammastep), `temperature` en kelvins la nuit
    // (hosts/default.json : tes réglages GNOME).
    readonly property var nightLight: Object.assign({ from: "20:00", to: "06:00", temperature: 3239 }, config.nightLight ?? {})
    // « Ne pas déranger » programmé (services/Notifs.qml) : actif de `from` à `to` (HH:MM) si `schedule`. Valeurs de départ :
    // ensuite réglées depuis le panneau de réglages et gardées dans un fichier d'état.
    readonly property var doNotDisturb: Object.assign({ schedule: true, from: "21:00", to: "07:00" }, config.doNotDisturb ?? {})

    // Pilules d'une barre : par description d'écran, sinon par rôle.
    // Renvoie { left: [[module, …], …], right: […] }.
    function barFor(description: string, primary: bool): var {
        return bars[description] ?? bars[primary ? "primary" : "secondary"] ?? ({ left: [], right: [] });
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
