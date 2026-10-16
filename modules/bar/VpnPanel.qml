import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Panneau NordVPN (ARCHITECTURE § 11.4) : interrupteur (dernier pays utilisé / déconnexion), détails de la connexion, pause,
// choix d'un pays puis éventuellement d'une ville : derniers pays utilisés, ou tous les pays filtrés par la recherche.
Panel {
    id: root

    title: "NordVPN"
    hasSwitch: true
    switchChecked: Vpn.connected || Vpn.connecting
    onSwitchToggled: checked => checked ? Vpn.connectLast() : Vpn.disconnect()

    property string expanded: ""   // pays dont les villes sont affichées

    onVisibleChanged: {
        if (visible) {
            Vpn.refresh();
            Vpn.loadCountries();
        } else {
            search.text = "";
            expanded = "";
        }
    }

    function label(name: string): string {
        return name.replace(/_/g, " ");
    }

    PanelRow {
        clickable: false
        icon: Vpn.icon
        text: Vpn.connecting && !Vpn.connected ? "Connecting…" : Vpn.connected ? `${Vpn.status["Country"] ?? ""}, ${Vpn.status["City"] ?? ""}`
            : Vpn.paused ? "Paused" : "Not connected"
        subtext: Vpn.connected ? [Vpn.status["Server"], Vpn.status["Current technology"], Vpn.status["Uptime"]].filter(s => s).join(" · ") : ""
        active: Vpn.connected
    }

    PanelSection {
        visible: Vpn.connected && (Vpn.status["Transfer"] ?? "") !== ""
        text: Vpn.status["Transfer"] ?? ""
    }

    RowLayout {
        visible: Vpn.connected
        Layout.fillWidth: true
        spacing: Theme.panel.spacing

        PanelSection {
            Layout.fillWidth: false
            text: "Pause"
        }

        Repeater {
            model: ["5m", "15m", "30m", "1h", "24h"]

            PanelButton {
                required property string modelData
                text: modelData
                onClicked: Vpn.pause(modelData)
            }
        }
    }

    PanelField {
        id: search
        placeholder: "Search countries"
    }

    PanelSection {
        visible: search.text === ""
        text: Vpn.recent.length > 0 ? "Recent countries" : "No recent countries · type to search"
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, Theme.panel.maxListHeight)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 0

            Repeater {
                model: search.text === "" ? Vpn.recent
                    : Vpn.countries.filter(c => root.label(c).toLowerCase().includes(search.text.toLowerCase()))

                ColumnLayout {
                    id: country

                    required property string modelData

                    Layout.fillWidth: true
                    spacing: 0

                    PanelRow {
                        text: root.label(country.modelData)
                        active: Vpn.connected && root.label(Vpn.status["Country"] ?? "") === root.label(country.modelData)
                        onClicked: Vpn.connect([country.modelData])

                        PanelButton {
                            text: root.expanded === country.modelData ? "Hide cities" : "Cities"
                            onClicked: {
                                root.expanded = root.expanded === country.modelData ? "" : country.modelData;
                                Vpn.loadCities(country.modelData);
                            }
                        }
                    }

                    Repeater {
                        model: root.expanded === country.modelData ? (Vpn.cities[country.modelData] ?? []) : []

                        PanelRow {
                            required property string modelData

                            Layout.leftMargin: Theme.panel.iconSize + Theme.panel.spacing
                            text: root.label(modelData)
                            active: Vpn.connected && root.label(Vpn.status["City"] ?? "") === root.label(modelData)
                            onClicked: Vpn.connect([country.modelData, modelData])
                        }
                    }
                }
            }
        }
    }
}
