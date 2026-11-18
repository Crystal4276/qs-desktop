pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Veilleuse (Night Light de GNOME) : état, horaire et température ; l'écran est chauffé par Hyprsunset.qml ou Gammastep.qml.
// Horaire comme « ne pas déranger » (Schedule.qml, ta demande du 2026-11-17) : `enabled` dit si l'écran est chaud en ce moment.
Singleton {
    id: root

    readonly property var config: Settings.nightLight
    readonly property bool enabled: persist.enabled

    // Température (ta demande du 2026-11-18) : réglée depuis le panneau, gardée dans un fichier d'état ; pas encore réglée : celle
    // de la config machine (`nightLight.temperature`, tes réglages GNOME). Plage du curseur de GNOME. `warmth` : position du
    // curseur, de 0 (moins chaud) à 1 (plus chaud).
    readonly property int minTemperature: 1700
    readonly property int maxTemperature: 4700
    readonly property int temperature: Math.max(minTemperature, Math.min(maxTemperature, Math.round(temperatureState.temperature ?? config.temperature)))
    readonly property real warmth: (maxTemperature - temperature) / (maxTemperature - minTemperature)

    function kelvinsAt(warmth: real): int {
        return Math.round(maxTemperature - Math.max(0, Math.min(1, warmth)) * (maxTemperature - minTemperature));
    }

    function setWarmth(warmth: real): void {
        temperatureState.temperature = kelvinsAt(warmth);
    }

    property bool temperatureRead: false   // moteur lancé après : pas de départ à la température par défaut

    FileView {
        path: Quickshell.statePath("night-light.json")   // ancien fichier d'état, repris (sa clé `enabled` est ignorée)
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.temperatureRead = true
        onLoadFailed: root.temperatureRead = true

        JsonAdapter {
            id: temperatureState
            property var temperature: null
        }
    }

    // Horaire réglé depuis le panneau de réglages ; heures de départ dans la config machine.
    readonly property Schedule schedule: Schedule {
        file: "night-light-schedule.json"
        defaults: root.config
        active: persist.enabled
        bySchedule: persist.bySchedule
        ready: persist.restored
        onSwitched: value => root.set(value, true)
    }

    function toggle(): void {
        set(!persist.enabled, false);
    }

    function set(on: bool, bySchedule: bool): void {
        persist.enabled = on;
        persist.bySchedule = on && bySchedule;
    }

    PersistentProperties {
        id: persist
        reloadableId: "nightlight"

        property bool enabled: false
        property bool bySchedule: false   // allumée par l'horaire (pas à la main)
        property bool restored: false   // état de la session repris

        onLoaded: {
            if (!restored)   // premier chargement de cette instance : début de session
                root.schedule.startSession();
            restored = true;
        }
    }

    // Moteur selon le compositeur (ta demande du 2026-11-18) : hyprsunset sous Hyprland (température changée à chaud, avec le
    // fondu de Hyprland), gammastep ailleurs (Sway).
    LazyLoader {
        active: root.temperatureRead && Compositor.isHyprland
        Hyprsunset {
            enabled: root.enabled
            temperature: root.temperature
        }
    }

    LazyLoader {
        active: root.temperatureRead && !Compositor.isHyprland
        Gammastep {
            enabled: root.enabled
            temperature: root.temperature
        }
    }

    // `qs ipc call nightlight toggle` (raccourci éventuel, tests).
    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            root.toggle();
        }

        function isEnabled(): bool {
            return root.enabled;
        }

        // Tests : température en kelvins, réglée comme depuis le curseur.
        function temperature(): int {
            return root.temperature;
        }

        function setTemperature(kelvins: int): void {
            root.setWarmth((root.maxTemperature - kelvins) / (root.maxTemperature - root.minTemperature));
        }

        // Tests : horaire en JSON ; réglage comme depuis le panneau.
        function scheduleState(): string {
            const s = root.schedule;
            return JSON.stringify({ enabled: root.enabled, scheduled: s.enabled, from: s.from, to: s.to, nightHours: s.inRange });
        }

        function setSchedule(enabled: bool, from: string, to: string): void {
            root.schedule.set(enabled, from, to);
        }
    }
}
