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
    readonly property bool warning: percent <= 30
}
