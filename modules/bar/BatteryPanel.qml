import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services

Panel {
    id: root
    title: "Battery"
    onVisibleChanged: Charging.panelOpen = visible
    Component.onDestruction: Charging.panelOpen = false

    readonly property var batteryDetails: Charging.details
    readonly property bool discharging: Battery.device?.state === UPowerDeviceState.Discharging
    readonly property string estimate: Charging.onBattery && discharging
        ? Charging.duration(batteryDetails.TimeToEmpty ?? 0)
        : Battery.charging && Charging.mode === "full" ? Charging.duration(batteryDetails.TimeToFull ?? 0) : ""
    readonly property string chargeStatus: !Battery.available ? "No laptop battery"
        : Charging.onBattery ? "Running on battery"
        : Battery.charging ? "Connected · Charging"
        : "Connected · Not charging"

    PanelCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.padding

            Text {
                text: Battery.charging ? Theme.icon.batteryCharging : Theme.level(Theme.icon.battery, Battery.percent)
                font.family: Theme.font.icons
                font.pixelSize: Theme.panel.cardIconSize
                color: Battery.warning && Charging.onBattery ? Theme.module.batteryWarning : Theme.module.battery
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: `${Battery.percent} %`
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.cardIconSize
                    font.weight: Font.DemiBold
                    color: Theme.panel.text
                }
                PanelSection { text: root.chargeStatus }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.panel.spacing
            radius: height / 2
            color: Theme.color.crust
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, Battery.percent)) / 100
                height: parent.height
                radius: parent.radius
                color: Battery.warning && Charging.onBattery ? Theme.module.batteryWarning : Theme.module.battery
            }
            Rectangle {
                visible: Charging.limit > 0 && Charging.limit < 100
                x: parent.width * Charging.limit / 100 - width / 2
                width: Theme.panel.border
                height: parent.height
                color: Theme.panel.text
            }
        }
        RowLayout {
            Layout.fillWidth: true
            PanelSection {
                text: Charging.limit ? `Charge limit · ${Charging.limit} %` : "Reading charging policy…"
            }
            Text {
                visible: Charging.applied
                text: Charging.mode === "preserve" ? "Preserving battery" : "Full charge allowed"
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: Theme.panel.accent
            }
        }
    }

    PanelSection { text: "Charging mode" }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.panel.spacing
        QuickToggle {
            id: preserve
            objectName: "battery-preserve"
            vertical: true
            icon: Theme.icon.powerSaver
            title: "Preserve · 80 %"
            subtitle: "Daily use on AC"
            checked: !Charging.departure && Charging.applied
            enabled: Charging.configured && !Charging.changing
            opacity: enabled ? 1 : Theme.panel.disabledOpacity
            onClicked: Charging.select(false)
        }
        QuickToggle {
            objectName: "battery-full"
            vertical: true
            icon: Theme.icon.batteryCharging
            title: "Full charge · 100 %"
            subtitle: "Prepare a departure"
            checked: Charging.departure && Charging.applied
            enabled: Charging.configured && !Charging.changing
            opacity: enabled ? 1 : Theme.panel.disabledOpacity
            onClicked: Charging.select(true)
        }
    }

    Text {
        Layout.fillWidth: true
        text: Charging.loading || Charging.changing ? "Checking charging mode…"
            : !Charging.supported ? "Charging modes are not supported by this battery controller."
            : !Charging.configured ? "Charging modes have not been configured on this computer."
            : Charging.departure ? "A full charge is allowed for your next departure. Preservation returns automatically when you reconnect after leaving."
            : "Charging starts below 50 % and stops at 80 %. A charge already above the limit is not forcibly discharged."
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.smallFontSize
        color: Theme.panel.secondaryText
        wrapMode: Text.Wrap
    }

    PanelCard {
        DetailsGrid {
            rows: [
                ["Power source", Charging.onBattery ? "Battery" : "AC power"],
                [Charging.onBattery ? "Estimated runtime" : "Full charge in", root.estimate],
                ["Battery health", Number.isFinite(root.batteryDetails.Capacity) && root.batteryDetails.Capacity > 0 ? `${Math.round(root.batteryDetails.Capacity)} % of original capacity` : ""],
                ["Temperature", Number.isFinite(root.batteryDetails.Temperature) && root.batteryDetails.Temperature > 0 ? `${root.batteryDetails.Temperature.toFixed(1)} °C` : ""],
                ["Charge cycles", Number.isInteger(root.batteryDetails.ChargeCycles) && root.batteryDetails.ChargeCycles >= 0 ? String(root.batteryDetails.ChargeCycles) : ""],
                ["Capacity", root.batteryDetails.EnergyFull > 0 ? `${root.batteryDetails.EnergyFull.toFixed(1)} Wh` : ""]
            ]
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Charging.error !== ""
        text: Charging.error
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.smallFontSize
        color: Theme.panel.warning
        wrapMode: Text.Wrap
    }
    PanelButton {
        visible: Charging.error !== ""
        text: "Retry"
        enabled: !Charging.busy
        onClicked: Charging.retry()
    }
}
