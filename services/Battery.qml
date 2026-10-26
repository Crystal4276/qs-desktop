pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Batterie du laptop (INVENTORY.md § 1, module `battery`, défini dans Waybar mais placé dans aucune barre).
// Présente seulement si UPower voit une batterie d'ordinateur portable (une alimentation USB-C ou une souris ne comptent pas).
Singleton {
    id: root

    readonly property bool available: UPower.devices.values.some(d => d.isLaptopBattery)
    readonly property UPowerDevice device: UPower.displayDevice
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)   // percentage : fraction 0–1
    readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.PendingCharge
    // Seuils de la config Waybar : warning 30 %, critical 15 %.
    readonly property int warningLevel: 30
    readonly property int criticalLevel: 15
    // Appareils Bluetooth (sans état de charge) : alerte réarmée quand la batterie remonte au-dessus de warningLevel + 10, soit
    // 40 % (ton choix du 2026-10-27 : absorbe les paliers de 10 % des casques).
    readonly property int rearmMargin: 10
    readonly property bool warning: percent <= warningLevel

    // Alerte (ajout du 2026-10-16) : une notification par seuil franchi pendant la décharge, réarmée dès que le laptop charge.
    property int alerted: 101   // plus bas seuil déjà signalé pendant cette décharge
    onPercentChanged: check()
    onChargingChanged: check()

    function check(): void {
        if (!available || device === null)
            return;
        if (charging) {
            alerted = 101;
            return;
        }
        const level = levelOf(percent);
        if (level >= alerted || level === 101)
            return;
        alerted = level;
        notifyLow("", percent, level);
    }

    // Seuil atteint par `percent` : `criticalLevel`, `warningLevel`, ou 101 (aucun). Aussi pour les appareils Bluetooth (Bluez.qml).
    function levelOf(percent: int): int {
        return percent <= criticalLevel ? criticalLevel : percent <= warningLevel ? warningLevel : 101;
    }

    // Alerte de batterie faible : celle du laptop (`device` vide) ou d'un appareil Bluetooth (son nom).
    function notifyLow(device: string, percent: int, level: int): void {
        const critical = level === criticalLevel;
        const state = critical ? "critically low" : "low";
        Quickshell.execDetached(["notify-send", `--app-name=${device === "" ? "Battery" : "Bluetooth"}`, `--urgency=${critical ? "critical" : "normal"}`,
            `--icon=${critical ? "battery-caution" : "battery-low"}`, device === "" ? `Battery ${state}` : `${device}: battery ${state}`,
            `${percent} % remaining`]);
    }
}
