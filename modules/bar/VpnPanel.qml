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
    switchLocked: Vpn.busy
    initialFocus: search.inputItem
    onSwitchToggled: checked => checked ? Vpn.connectLast() : Vpn.disconnect()

    property string tab: "recent"   // onglet choisi : "recent" ou "all"
    property string expanded: ""    // pays dont les villes sont affichées
    readonly property string query: search.text.trim().toLowerCase().replace(/_/g, " ")
    // Liste affichée : une recherche montre tous les pays, quel que soit l'onglet (effacée, l'onglet revient).
    readonly property string shown: query !== "" ? "all" : tab
    // Entrées affichées : « Pays » ou « Pays/Ville » (récents) ; aucune, panneau fermé (pas ~150 lignes gardées en mémoire).
    readonly property var rows: !visible ? [] : shown === "recent" ? Vpn.recent : matches(Vpn.countries, query)
    // Détails, trafic, pause : connexion établie et aucune action en cours (pendant un changement, le statut est encore l'ancien).
    readonly property bool settled: Vpn.connected && Vpn.doing === ""

    onVisibleChanged: {
        if (visible) {
            Vpn.refresh();
            Vpn.loadCountries();
            tab = Vpn.recent.length > 0 ? "recent" : "all";
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
        return Vpn.connected && Vpn.sameName(Vpn.status["Country"] ?? "", country)
            && (city === "" || Vpn.sameName(Vpn.status["City"] ?? "", city));
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
                Vpn.connect(Vpn.entryTarget(root.rows[0]));
        }
    }

    // Onglets, comme le panneau réseau ; « Recent » efface la recherche.
    PanelTabs {
        model: [{ key: "recent", text: "Recent" }, { key: "all", text: "All countries" }]
        current: root.shown
        onPicked: key => {
            root.tab = key;
            if (key === "recent")
                search.text = "";
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
                readonly property string city: Vpn.entryCity(modelData)

                Layout.fillWidth: true
                spacing: 0

                // Pendant une action (connexion, pause…), lignes inactives (souris et clavier) : rien ne serait lancé. (Pas `enabled` :
                // la ligne choisie au clavier perdrait le focus, et Échap et les flèches avec ; « Cities » reste utilisable.)
                PanelRow {
                    clickable: !Vpn.busy
                    text: entry.city !== "" ? `${root.label(entry.country)}, ${root.label(entry.city)}` : root.label(entry.country)
                    active: root.isCurrent(entry.country, entry.city)
                    onClicked: Vpn.connect(Vpn.entryTarget(entry.modelData))

                    PanelButton {
                        text: root.expanded === entry.country ? "Hide cities" : "Cities"
                        onClicked: {
                            root.expanded = root.expanded === entry.country ? "" : entry.country;
                            if (root.expanded !== "")
                                Vpn.loadCities(entry.country);
                        }
                    }
                }

                PanelSection {
                    readonly property bool open: root.expanded === entry.country
                    visible: open && Vpn.cities[entry.country] === undefined
                    Layout.leftMargin: Theme.panel.iconSize + Theme.panel.spacing + Theme.panel.rowPadding   // aligné sur le texte des villes
                    text: open ? (Vpn.citiesLoading === entry.country ? "Loading cities…" : "Cities unavailable") : ""
                }

                Repeater {
                    model: root.expanded === entry.country ? (Vpn.cities[entry.country] ?? []) : []

                    PanelRow {
                        required property string modelData

                        clickable: !Vpn.busy
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
