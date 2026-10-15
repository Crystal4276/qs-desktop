pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Hyprland

// Interface unique sur le compositeur (docs/ARCHITECTURE.md § 2).
// Backend choisi au démarrage : Sway (SWAYSOCK) via Quickshell.I3, Hyprland (HYPRLAND_INSTANCE_SIGNATURE) via Quickshell.Hyprland.
// Seul le singleton du backend actif est touché : l'autre ne tente jamais de se connecter.
Singleton {
    id: root

    readonly property string type: Quickshell.env("SWAYSOCK") ? "sway"
        : Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : ""
    readonly property bool isSway: type === "sway"
    readonly property bool isHyprland: type === "hyprland"

    // Sorties actives : { name, description, x, y, width, height, scale, focused }
    // x, y, width, height en px logiques. description = « marque modèle numéro de série ».
    readonly property var outputs: {
        if (isSway)
            return I3.monitors.values.filter(m => m.lastIpcObject.active !== false).map(m => ({
                name: m.name,
                description: [m.lastIpcObject.make, m.lastIpcObject.model, m.lastIpcObject.serial].filter(s => s).join(" "),
                x: m.x, y: m.y, width: m.width, height: m.height,
                scale: m.scale,
                focused: m.focused
            }));
        if (isHyprland)
            return Hyprland.monitors.values.filter(m => !m.lastIpcObject.disabled).map(m => ({
                name: m.name,
                description: m.description,
                x: m.x, y: m.y,
                // taille du mode en px physiques → logiques [rotation : à vérifier en phase 9]
                width: Math.round(m.width / m.scale), height: Math.round(m.height / m.scale),
                scale: m.scale,
                focused: m.focused
            }));
        return [];
    }

    // Espaces de travail existants : { number, name, output, focused, visible, urgent }
    readonly property var workspaces: {
        if (isSway)
            return I3.workspaces.values.map(w => ({
                number: w.number,
                name: w.name,
                output: w.monitor?.name ?? "",
                focused: w.focused,
                visible: w.active,
                urgent: w.urgent
            }));
        if (isHyprland)
            return Hyprland.workspaces.values.filter(w => w.id > 0).map(w => ({
                number: w.id,
                name: w.name,
                output: w.monitor?.name ?? "",
                focused: w.focused,
                visible: w.active,
                urgent: w.urgent
            }));
        return [];
    }

    readonly property string focusedOutput: isSway ? (I3.focusedMonitor?.name ?? "")
        : isHyprland ? (Hyprland.focusedMonitor?.name ?? "") : ""

    function output(name: string): var {
        return outputs.find(o => o.name === name) ?? null;
    }

    function focusWorkspace(n: int): void {
        if (isSway)
            I3.dispatch(`workspace number ${n}`);
        else if (isHyprland)
            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = ${n} })` : `workspace ${n}`);
    }
}
