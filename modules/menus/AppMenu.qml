import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Menu d'applications (remplace nwg-menu, ARCHITECTURE § 8 Q3) : disposition du menu de Cinnamon, style de nwg-menu (THEME.md § 7).
// Ouvert par le bouton Arch de la barre ou `qs ipc call menu toggle`, sous le bouton.
// - Colonne de gauche : dossiers XDG, favoris (clic droit sur une application : ajouter / retirer), verrouiller, se déconnecter,
//   redémarrer, éteindre (sans confirmation, comme le panneau de réglages) ;
// - catégories (au survol, sauf pendant une recherche, que le survol n'efface jamais ; un clic la quitte) : All Applications,
//   catégories freedesktop non vides, Recent Files ;
// - applications de la catégorie (nom + description), recherche en bas (taper filtre toutes les applications, comme le lanceur).
// Clavier : la saisie va à la recherche ; Haut / Bas, Pages : sélection ; Gauche : catégories (Haut / Bas les parcourent),
// Droite : retour aux applications ; Entrée lance ; Échap ferme.
PanelWindow {
    id: root

    property string category: "all"
    property string pane: "apps"    // colonne pilotée par Haut / Bas : "apps" ou "categories"
    property int selected: 0
    property var contextEntry: null // application du menu contextuel (clic droit), null : fermé
    property real closedAt: 0

    readonly property var categories: [
        { key: "all", name: "All Applications", icon: Theme.appMenu.allIcon },
        ...[...Apps.categoryList, { key: "Other", name: "Other" }].filter(c => (Apps.byCategory[c.key] ?? []).length > 0)
            .map(c => ({ key: c.key, name: c.name, icon: Theme.appMenu.categoryIcons[c.key] })),
        ...(Places.recent.length > 0 ? [{ key: "recent", name: "Recent Files", icon: Theme.appMenu.recentIcon }] : [])
    ]

    readonly property var items: {
        if (search.text !== "")
            return Apps.filter(search.text).map(appItem);
        if (category === "recent")
            return Places.recent.map(f => ({
                id: `file:${f.path}`,
                name: f.name,
                description: f.path.slice(0, f.path.length - f.name.length - 1),
                icon: mimeIcon(f.mime),
                path: f.path
            }));
        return (category === "all" ? Apps.byName : Apps.byCategory[category] ?? []).map(appItem);
    }

    // Nouvelle liste (saisie, catégorie) : première ligne choisie et visible, une fois la vue mise à jour.
    onItemsChanged: {
        selected = 0;
        Qt.callLater(() => list.positionViewAtBeginning());
    }

    function appItem(entry: var): var {
        return { id: entry.id, name: entry.name, description: entry.comment || entry.genericName, icon: Apps.iconSource(entry.icon), entry: entry };
    }

    // Icône d'un type de fichier (« text/plain » → text-plain, sinon text-x-generic, sinon l'icône de fichier générique).
    function mimeIcon(mime: string): string {
        for (const name of [mime.replace("/", "-"), `${mime.split("/")[0]}-x-generic`, Theme.appMenu.fileIcon]) {
            const path = name.startsWith("-") ? "" : Quickshell.iconPath(name, true);
            if (path !== "")
                return path;
        }
        return "";
    }

    // Sous le bouton, aligné sur le bord gauche de sa pilule (nwg-menu : 10 px sous la barre). Un appui sur le bouton pendant
    // que le menu est ouvert : la barre l'a déjà fermé (Bar.qml), il ne se rouvre pas.
    function toggle(button: Item): void {
        if (visible || Date.now() - closedAt < 400) {
            close();
            return;
        }
        const window = button.QsWindow.window;
        screen = window.screen;
        const x = button.mapToItem(null, 0, 0).x - Theme.bar.pillBorder;
        frame.x = Math.max(Theme.bar.marginSide, Math.min(x, window.width - Theme.bar.marginSide - frame.width));
        search.text = "";
        category = "all";
        pane = "apps";
        selected = 0;
        contextEntry = null;
        list.positionViewAtBeginning();
        visible = true;
        search.forceActiveFocus();
    }

    function close(): void {
        if (visible)
            closedAt = Date.now();
        visible = false;
    }

    function setCategory(key: string): void {
        search.text = "";
        category = key;
    }

    function select(index: int): void {
        if (items.length > 0)
            selected = Math.max(0, Math.min(index, items.length - 1));
    }

    function activate(item: var): void {
        if (!item)
            return;
        if (item.entry)
            Apps.launch(item.entry);
        else
            Places.open(item.path);
        close();
    }

    function run(action: var): void {
        close();
        action();
    }

    function handleKey(event: var): bool {
        const k = event.key;
        if (k === Qt.Key_Escape) {
            if (contextEntry)
                contextEntry = null;
            else
                close();
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (pane === "categories")
                pane = "apps";
            else
                activate(items[selected]);
        } else if (k === Qt.Key_Left && search.text === "")
            pane = "categories";
        else if (k === Qt.Key_Right && search.text === "")
            pane = "apps";
        else if (k === Qt.Key_Up || k === Qt.Key_Down) {
            const step = k === Qt.Key_Up ? -1 : 1;
            if (pane === "categories") {
                const i = categories.findIndex(c => c.key === category);
                setCategory(categories[Math.max(0, Math.min(i + step, categories.length - 1))].key);
            } else
                select(selected + step);
        } else if (k === Qt.Key_PageUp || k === Qt.Key_PageDown) {
            const rows = Math.max(1, Math.floor(list.height / largeRow.height));
            select(selected + (k === Qt.Key_PageUp ? -rows : rows));
        } else
            return false;
        return true;
    }

    visible: false
    WlrLayershell.namespace: "quickshell-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    onVisibleChanged: BarState.setPopupOpen(root, visible)
    Component.onDestruction: BarState.setPopupOpen(root, false)

    Connections {
        target: BarState
        function onClosePopups() {
            root.close();
        }
    }

    OutsideClick {
        active: root.visible
        screen: root.screen
        onPressed: root.close()
    }

    // Appui à côté du cadre : fermeture.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    // Ligne de liste (style nwg-menu) : icône, nom, description facultative ; survol ou sélection : fond `green`, texte `mantle`.
    component MenuRow: Rectangle {
        id: row

        property string icon: ""
        property string label: ""
        property string description: ""
        property int iconSize: Theme.appMenu.smallIconSize
        property bool highlighted: hovered
        readonly property bool hovered: hover.hovered
        signal clicked
        signal rightClicked(real x, real y)

        implicitWidth: rowContent.implicitWidth + 2 * Theme.appMenu.itemPadding
        implicitHeight: Math.max(iconSize, texts.implicitHeight) + 2 * Theme.appMenu.itemPadding
        radius: Theme.appMenu.itemRadius
        color: highlighted ? Theme.appMenu.selected : "transparent"

        RowLayout {
            id: rowContent
            anchors.fill: parent
            anchors.margins: Theme.appMenu.itemPadding
            spacing: Theme.appMenu.spacing

            IconImage {
                visible: row.iconSize > 0   // 0 : ligne sans icône (menu contextuel)
                implicitSize: row.iconSize
                source: row.icon
            }

            ColumnLayout {
                id: texts
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.label
                    font.family: Theme.font.text
                    font.pixelSize: Theme.appMenu.fontSize
                    color: row.highlighted ? Theme.appMenu.selectedText : Theme.appMenu.text
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: row.description !== ""
                    text: row.description
                    font.family: Theme.font.text
                    font.pixelSize: Theme.appMenu.descriptionFontSize
                    color: row.highlighted ? Theme.appMenu.selectedText : Theme.appMenu.description
                    elide: Text.ElideRight
                }
            }
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? row.rightClicked(mouse.x, mouse.y) : row.clicked()
        }
    }

    // Boîte de liste : fond `base`, bordure `overlay0`, rayon 20 px (nwg-menu).
    component ListBox: Rectangle {
        default property alias content: column.data

        implicitWidth: column.implicitWidth + 2 * (Theme.appMenu.itemPadding + Theme.appMenu.itemMargin)
        implicitHeight: column.implicitHeight + 2 * (Theme.appMenu.itemPadding + Theme.appMenu.itemMargin)
        color: Theme.appMenu.listBackground
        border.width: Theme.appMenu.border
        border.color: Theme.appMenu.borderColor
        radius: Theme.appMenu.radius

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Theme.appMenu.itemPadding + Theme.appMenu.itemMargin
            spacing: 2 * Theme.appMenu.itemMargin
        }
    }

    // Bouton de session : ton SVG, sans fond ; survol : `rgba(255,255,255,0.1)` et bordure `overlay0` (nwg-menu).
    component SessionButton: Rectangle {
        id: button

        property url image
        signal clicked

        implicitWidth: Theme.appMenu.sessionIconSize + 2 * Theme.appMenu.itemPadding
        implicitHeight: implicitWidth
        radius: Theme.appMenu.itemRadius
        color: hover.hovered ? Theme.appMenu.buttonHover : "transparent"
        border.width: Theme.appMenu.border
        border.color: hover.hovered ? Theme.appMenu.buttonHoverBorder : "transparent"

        Image {
            anchors.centerIn: parent
            source: button.image
            sourceSize.width: Theme.appMenu.sessionIconSize
            sourceSize.height: Theme.appMenu.sessionIconSize
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            onClicked: button.clicked()
        }
    }

    Rectangle {
        id: frame

        y: Theme.panel.gap
        width: layout.implicitWidth + 2 * (Theme.appMenu.border + Theme.appMenu.padding)
        height: layout.implicitHeight + 2 * (Theme.appMenu.border + Theme.appMenu.padding)
        color: Theme.appMenu.background
        border.width: Theme.appMenu.border
        border.color: Theme.appMenu.borderColor
        radius: Theme.appMenu.radius

        // Les clics sur le cadre ne le ferment pas ; ils ferment le menu contextuel.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.contextEntry = null
        }

        // Hauteur d'une ligne d'application, pour le défilement par page.
        MenuRow {
            id: largeRow
            visible: false
            iconSize: Theme.appMenu.largeIconSize
            label: "Ag"
            description: "Ag"
        }

        RowLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.appMenu.border + Theme.appMenu.padding
            spacing: Theme.appMenu.spacing

            // --- Colonne de gauche : dossiers, favoris, session ---
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.max(places.implicitWidth, favorites.implicitWidth, session.implicitWidth)
                spacing: Theme.appMenu.spacing

                ListBox {
                    id: places
                    Layout.fillWidth: true

                    Repeater {
                        model: Places.folders

                        MenuRow {
                            required property var modelData
                            Layout.fillWidth: true
                            icon: Quickshell.iconPath(Theme.appMenu.placeIcons[modelData.key] ?? "", true)
                            label: modelData.name
                            onClicked: root.run(() => Places.open(modelData.path))
                        }
                    }
                }

                ListBox {
                    id: favorites
                    Layout.fillWidth: true
                    visible: Apps.favoriteEntries.length > 0

                    Repeater {
                        model: Apps.favoriteEntries

                        MenuRow {
                            id: favorite
                            required property var modelData
                            Layout.fillWidth: true
                            icon: Apps.iconSource(modelData.icon)
                            label: modelData.name
                            onClicked: root.activate(root.appItem(modelData))
                            onRightClicked: (x, y) => context.show(modelData, favorite, x, y)
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    id: session
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.appMenu.spacing

                    SessionButton {
                        image: Theme.image.lock
                        onClicked: root.run(() => Session.lock())
                    }

                    SessionButton {
                        image: Theme.image.logout
                        onClicked: root.run(() => Session.logout())
                    }

                    SessionButton {
                        image: Theme.image.restart
                        onClicked: root.run(() => Session.reboot())
                    }

                    SessionButton {
                        image: Theme.image.shutdown
                        onClicked: root.run(() => Session.poweroff())
                    }
                }
            }

            // --- Catégories et applications, recherche en bas ---
            ColumnLayout {
                Layout.fillHeight: true
                spacing: Theme.appMenu.spacing

                RowLayout {
                    Layout.fillHeight: true
                    spacing: Theme.appMenu.spacing

                    ListBox {
                        id: categoryBox
                        Layout.alignment: Qt.AlignTop

                        Repeater {
                            model: root.categories

                            MenuRow {
                                id: categoryRow
                                required property var modelData
                                Layout.fillWidth: true
                                icon: Quickshell.iconPath(modelData.icon, true)
                                label: modelData.name
                                highlighted: search.text === "" && root.category === modelData.key
                                // Survol : change de catégorie hors recherche seulement ; il n'efface jamais la recherche (défaut de
                                // nwg-menu, à ne pas reproduire). Un clic, lui, quitte la recherche.
                                onHoveredChanged: if (hovered && search.text === "") root.setCategory(modelData.key)
                                onClicked: root.setCategory(modelData.key)
                            }
                        }
                    }

                    // Applications : liste défilante, de la hauteur des catégories.
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: Theme.appMenu.appsWidth
                        color: Theme.appMenu.listBackground
                        border.width: Theme.appMenu.border
                        border.color: Theme.appMenu.borderColor
                        radius: Theme.appMenu.radius

                        ListView {
                            id: list

                            readonly property bool overflows: contentHeight > height

                            anchors.fill: parent
                            anchors.margins: Theme.appMenu.itemPadding + Theme.appMenu.itemMargin
                            anchors.rightMargin: anchors.margins + (overflows ? Theme.appMenu.scrollbarWidth : 0)
                            clip: true
                            spacing: 2 * Theme.appMenu.itemMargin
                            boundsBehavior: Flickable.StopAtBounds
                            currentIndex: root.selected
                            highlightFollowsCurrentItem: false
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                            model: ScriptModel {
                                values: root.items
                                objectProp: "id"
                            }

                            delegate: MenuRow {
                                id: appRow
                                required property var modelData
                                required property int index
                                width: list.width
                                iconSize: Theme.appMenu.largeIconSize
                                icon: modelData.icon
                                label: modelData.name
                                description: modelData.description ?? ""
                                highlighted: root.pane === "apps" && root.selected === index
                                onHoveredChanged: if (hovered) {
                                    root.pane = "apps";
                                    root.selected = index;
                                }
                                onClicked: root.activate(modelData)
                                onRightClicked: (x, y) => {
                                    if (modelData.entry)
                                        context.show(modelData.entry, appRow, x, y);
                                }
                            }
                        }

                        // Curseur de défilement (thème GTK) : dans une gouttière de 25 px, bordure transparente de 4 px.
                        Rectangle {
                            visible: list.overflows
                            readonly property real track: list.height - 2 * Theme.appMenu.scrollbarInset
                            x: parent.width - Theme.appMenu.itemPadding - Theme.appMenu.scrollbarWidth + Theme.appMenu.scrollbarInset
                            y: list.y + Theme.appMenu.scrollbarInset + list.visibleArea.yPosition * track
                            width: Theme.appMenu.scrollbarWidth - 2 * Theme.appMenu.scrollbarInset
                            height: Math.max(Theme.appMenu.scrollbarMinLength, list.visibleArea.heightRatio * track)
                            radius: width / 2
                            color: sliderHover.hovered ? Theme.appMenu.scrollbarHover : Theme.appMenu.scrollbar

                            HoverHandler {
                                id: sliderHover
                            }
                        }
                    }
                }

                // Recherche : soulignement 1 px `overlay2`, rayon 10 px, 24 px (nwg-menu) ; loupe à droite (Cinnamon).
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: search.implicitHeight + 2 * Theme.appMenu.itemPadding + Theme.appMenu.searchUnderline
                    radius: Theme.appMenu.searchRadius
                    color: Theme.appMenu.searchUnderlineColor

                    Rectangle {
                        width: parent.width
                        height: parent.height - Theme.appMenu.searchUnderline
                        radius: Theme.appMenu.searchRadius
                        color: Theme.appMenu.background
                    }

                    TextInput {
                        id: search
                        x: Theme.appMenu.itemPadding
                        y: Theme.appMenu.itemPadding
                        width: parent.width - 2 * Theme.appMenu.itemPadding - searchGlyph.width - Theme.appMenu.spacing
                        clip: true
                        font.family: Theme.font.text
                        font.pixelSize: Theme.appMenu.searchFontSize
                        color: Theme.appMenu.text
                        onTextChanged: root.pane = "apps"
                        Keys.onPressed: event => event.accepted = root.handleKey(event)
                    }

                    Text {
                        id: searchGlyph
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.appMenu.itemPadding
                        anchors.verticalCenter: search.verticalCenter
                        text: Theme.icon.search
                        font.family: Theme.font.icons
                        font.pixelSize: Theme.appMenu.fontSize
                        color: Theme.appMenu.text
                    }
                }
            }
        }

        // Menu contextuel d'une application (clic droit) : ajouter aux favoris ou en retirer.
        ListBox {
            id: context

            function show(entry: var, from: Item, x: real, y: real): void {
                const p = from.mapToItem(frame, x, y);
                root.contextEntry = entry;
                context.x = Math.min(p.x, frame.width - context.width - Theme.appMenu.border);
                context.y = Math.min(p.y, frame.height - context.height - Theme.appMenu.border);
            }

            visible: root.contextEntry !== null
            z: 1

            MenuRow {
                Layout.fillWidth: true
                iconSize: 0
                label: root.contextEntry && Apps.isFavorite(root.contextEntry) ? "Remove from favorites" : "Add to favorites"
                onClicked: {
                    Apps.toggleFavorite(root.contextEntry);
                    root.contextEntry = null;
                }
            }
        }
    }
}
