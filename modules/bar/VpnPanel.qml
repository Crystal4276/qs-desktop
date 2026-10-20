import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Panneau NordVPN (ARCHITECTURE § 11.4) : interrupteur (dernière entrée des récents / déconnexion), détails de la connexion,
// pause, choix d'un pays puis éventuellement d'une ville. Refonte du 2026-10-20 (ta demande) : onglets Recent / All countries ;
// la recherche (focus à l'ouverture) affiche tous les pays filtrés, débuts de nom puis débuts de mot d'abord ; Entrée connecte
// au premier résultat, Échap efface la recherche puis ferme.
Panel {
    id: root

    title: "NordVPN"
    hasSwitch: true
    switchChecked: Vpn.connected || Vpn.connecting
    onSwitchToggled: checked => checked ? Vpn.connectLast() : Vpn.disconnect()

    property string tab: "recent"   // onglet choisi : "recent" ou "all"
    property string expanded: ""    // pays dont les villes sont affichées
    readonly property string query: search.text.trim().toLowerCase().replace(/_/g, " ")
    // Liste affichée : une recherche montre tous les pays, quel que soit l'onglet (effacée, l'onglet revient).
    readonly property string shown: query !== "" ? "all" : tab
    // Entrées affichées : « Pays » ou « Pays/Ville » (récents).
    readonly property var rows: shown === "recent" ? Vpn.recent : matches(Vpn.countries, query)
    // Détails, trafic, pause : connexion établie et aucune action en cours (pendant un changement, le statut est encore l'ancien).
    readonly property bool settled: Vpn.connected && Vpn.doing === ""

    onVisibleChanged: {
        if (visible) {
            Vpn.refresh();
            Vpn.loadCountries();
            tab = Vpn.recent.length > 0 ? "recent" : "all";
            search.focusInput();
        } else {
            search.text = "";
            expanded = "";
        }
    }

    function label(name: string): string {
        return name.replace(/_/g, " ");
    }

    // Pays contenant la recherche : ceux qui commencent par elle, puis ceux dont un mot commence par elle, puis les autres ;
    // ordre alphabétique dans chaque groupe.
    function matches(countries: var, q: string): var {
        if (q === "")
            return countries;
        const found = [];
        countries.forEach((c, i) => {
            const name = label(c).toLowerCase();
            if (name.includes(q))
                found.push({ c, i, rank: name.startsWith(q) ? 0 : name.includes(" " + q) ? 1 : 2 });
        });
        return found.sort((a, b) => a.rank - b.rank || a.i - b.i).map(f => f.c);
    }

    function isCurrent(country: string, city: string): bool {
        return Vpn.connected && label(Vpn.status["Country"] ?? "") === label(country)
            && (city === "" || label(Vpn.status["City"] ?? "") === label(city));
    }

    function statusText(): string {
        const target = Vpn.requested ? Vpn.requested.map(label).join(", ") : "";
        switch (Vpn.doing) {
        case "connect":
            return target !== "" ? `Connecting to ${target}…` : "Connecting…";
        case "disconnect":
            return "Disconnecting…";
        case "pause":
            return "Pausing…";
        }
        return Vpn.state === "Connecting" ? "Connecting…"
            : Vpn.connected ? `${Vpn.status["Country"] ?? ""}, ${Vpn.status["City"] ?? ""}`
            : Vpn.paused ? "Paused" : "Not connected";
    }

    PanelRow {
        clickable: false
        icon: Vpn.icon
        text: root.statusText()
        subtext: root.settled ? [Vpn.status["Server"], Vpn.status["Current technology"], Vpn.status["Uptime"]].filter(s => s).join(" · ") : ""
        active: root.settled
    }

    PanelSection {
        visible: root.settled && (Vpn.status["Transfer"] ?? "") !== ""
        text: Vpn.status["Transfer"] ?? ""
    }

    RowLayout {
        visible: root.settled
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
        search: true
        onAccepted: {
            if (root.query !== "" && root.rows.length > 0)
                Vpn.connect(root.rows[0].split("/"));
        }
    }

    // Onglets, comme le panneau réseau ; « Recent » efface la recherche.
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.panel.spacing

        Repeater {
            model: [{ key: "recent", text: "Recent" }, { key: "all", text: "All countries" }]

            PanelButton {
                required property var modelData

                Layout.fillWidth: true
                text: modelData.text
                checked: root.shown === modelData.key
                onClicked: {
                    root.tab = modelData.key;
                    if (modelData.key === "recent")
                        search.text = "";
                }
            }
        }
    }

    PanelSection {
        visible: text !== ""
        text: root.rows.length > 0 ? ""
            : root.shown === "recent" ? "No recent countries · type to search"
            : Vpn.countries.length === 0 ? (Vpn.countriesLoading ? "Loading countries…" : "Countries unavailable · reopen to retry")
            : `No country matches “${search.text.trim()}”`
    }

    PanelList {
        Repeater {
            model: ScriptModel {
                values: root.rows
            }

            ColumnLayout {
                id: entry

                required property string modelData
                readonly property string country: Vpn.entryCountry(modelData)
                readonly property string city: modelData.split("/")[1] ?? ""

                Layout.fillWidth: true
                spacing: 0

                PanelRow {
                    text: entry.city !== "" ? `${root.label(entry.country)}, ${root.label(entry.city)}` : root.label(entry.country)
                    active: root.isCurrent(entry.country, entry.city)
                    onClicked: Vpn.connect(entry.modelData.split("/"))

                    PanelButton {
                        text: root.expanded === entry.country ? "Hide cities" : "Cities"
                        onClicked: {
                            root.expanded = root.expanded === entry.country ? "" : entry.country;
                            Vpn.loadCities(entry.country);
                        }
                    }
                }

                PanelSection {
                    readonly property bool open: root.expanded === entry.country
                    visible: open && Vpn.cities[entry.country] === undefined
                    Layout.leftMargin: Theme.panel.iconSize + Theme.panel.spacing + Theme.panel.rowPadding   // aligné sur le texte des villes
                    text: Vpn.citiesLoading === entry.country ? "Loading cities…" : "Cities unavailable"
                }

                Repeater {
                    model: root.expanded === entry.country ? (Vpn.cities[entry.country] ?? []) : []

                    PanelRow {
                        required property string modelData

                        Layout.leftMargin: Theme.panel.iconSize + Theme.panel.spacing
                        text: root.label(modelData)
                        active: root.isCurrent(entry.country, modelData)
                        onClicked: Vpn.connect([entry.country, modelData])
                    }
                }
            }
        }
    }
}
