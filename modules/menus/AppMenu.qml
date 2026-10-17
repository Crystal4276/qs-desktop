import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Menu d'applications (remplace nwg-menu) : disposition de Cinnamon, style de nwg-menu (THEME.md § 7). Comportement :
// ARCHITECTURE § 10.1.5 (survol, visée vers la liste, clavier, recherche jamais effacée par le survol).
OverlayPopup {
    id: root

    property string category: "all"
    property string pane: "apps"    // colonne pilotée par Haut / Bas : "apps" ou "categories"
    property int selected: 0
    property var contextEntry: null // application du menu contextuel (clic droit), null : fermé
    property real anchorX: 0        // bord gauche voulu du cadre (pilule du bouton) ; le cadre reste dans l'écran
    property bool recentRead: false // fichiers récents relus depuis l'ouverture

    // Souris : dernière position dans le cadre (-1 : aucune depuis l'ouverture), visée vers la liste des applications.
    property point pointer: Qt.point(-1, -1)
    property int moves: 0   // vrais mouvements depuis l'ouverture (une liste recréée sous le pointeur n'en est pas un)
    property bool aiming: false
    property string hoveredCategory: ""
    // Ligne d'application sous le pointeur (null : aucune ; remise à null d'elle-même quand la ligne est détruite). Son indice suit
    // la liste ; une ligne retirée (en attente de destruction) a un indice hors liste.
    property Item hoveredRow: null

    readonly property var categories: [
        { key: "all", name: "All Applications", icon: Theme.appMenu.allIcon },
        ...[...Apps.categoryList, { key: "Other", name: "Other" }].filter(c => (Apps.byCategory[c.key] ?? []).length > 0)
            .map(c => ({ key: c.key, name: c.name, icon: Theme.appMenu.categoryIcons[c.key] })),
        { key: "recent", name: "Recent Files", icon: Theme.appMenu.recentIcon }
    ]

    readonly property var items: {
        if (search.text !== "")
            return Apps.filter(search.text).map(appItem);
        if (category === "recent")
            return Places.recent.map(f => ({
                id: `file:${f.path}`,
                name: f.name,
                description: f.path.slice(0, f.path.length - f.name.length - 1),
                mime: f.mime,   // icône cherchée par la ligne affichée (Icons.mimeIcon), pas pour toute la liste
                path: f.path
            }));
        return (category === "all" ? Apps.byName : Apps.byCategory[category] ?? []).map(appItem);
    }

    // Élément sélectionné : la sélection le suit quand la liste change d'elle-même (fichiers récents relus, applications installées).
    property string selectedId: ""
    onSelectedChanged: {
        selectedId = items[selected]?.id ?? "";
        list.positionViewAtIndex(selected, ListView.Contain);
    }
    onItemsChanged: {
        const i = selectedId === "" ? -1 : items.findIndex(item => item.id === selectedId);
        selected = i >= 0 ? i : Math.max(0, Math.min(selected, items.length - 1));
        selectedId = items[selected]?.id ?? "";   // élément disparu : la sélection suit désormais celui qui prend sa place
    }

    // Nouvelle liste demandée (saisie, catégorie) : première ligne choisie et visible, une fois la liste à jour.
    function resetList(): void {
        contextEntry = null;
        Qt.callLater(() => {
            selected = 0;
            selectedId = items[0]?.id ?? "";
            list.positionViewAtBeginning();
        });
    }

    function appItem(entry: var): var {
        return { id: entry.id, name: entry.name, description: entry.comment || entry.genericName, entry: entry };
    }

    // Mouvement dans le cadre. Visée : vers le bord gauche de la liste des applications, entre ses coins vus de la position
    // précédente ; tombe à l'arrêt (aimStop). Premier événement après l'ouverture : position notée, pas un mouvement.
    function movePointer(p: point): void {
        if (p.x === pointer.x && p.y === pointer.y)
            return;
        if (pointer.x < 0) {
            pointer = p;
            return;
        }
        const box = appsBox.mapToItem(frame, 0, 0);
        const dx = p.x - pointer.x, dy = p.y - pointer.y, ahead = box.x - pointer.x;
        aiming = dx > 0 && ahead > 0 && dy / dx >= (box.y - pointer.y) / ahead
            && dy / dx <= (box.y + appsBox.height - pointer.y) / ahead;
        pointer = p;
        moves++;
        aimStop.restart();
        // Ligne survolée sous un pointeur jusque-là immobile : prise maintenant.
        const row = hoveredRow;
        if (row && !contextEntry && row.index >= 0 && items[row.index]?.id === row.modelData.id
                && (pane !== "apps" || selected !== row.index)) {
            pane = "apps";
            selected = row.index;
        }
    }

    // Survol d'une ligne : décidé après l'événement, une fois le mouvement vu par le cadre (qui le reçoit après ses lignes) ; sans
    // mouvement (liste recréée ou défilée sous un pointeur immobile), rien ne change.
    function afterMove(action: var): void {
        const before = moves;
        Qt.callLater(() => {
            if (moves !== before)
                action();
        });
    }

    function hoverCategory(key: string, hovered: bool): void {
        if (!hovered) {
            if (hoveredCategory === key)
                hoveredCategory = "";
            return;
        }
        hoveredCategory = key;
        afterMove(() => {
            if (!aiming)
                takeHoveredCategory();
        });   // en visée : prise à l'arrêt du pointeur (aimStop)
    }

    // Catégorie survolée prise, sauf pendant une recherche (le survol ne l'efface pas), sous le menu contextuel, ou déjà choisie.
    function takeHoveredCategory(): void {
        if (hoveredCategory !== "" && hoveredCategory !== category && search.text === "" && !contextEntry)
            setCategory(hoveredCategory);
    }

    // Sous le bouton, aligné sur le bord gauche de sa pilule (nwg-menu : 10 px sous la barre).
    function toggle(from: Item): void {
        if (!beginOpen(from))
            return;
        screen = from.QsWindow.window.screen;
        anchorX = from.mapToItem(null, 0, 0).x - Theme.bar.pillBorder;
        search.text = "";
        category = "all";
        pane = "apps";
        selected = 0;
        contextEntry = null;
        aiming = false;
        hoveredCategory = "";
        hoveredRow = null;
        pointer = Qt.point(-1, -1);
        moves = 0;
        recentRead = false;
        list.positionViewAtBeginning();
        visible = true;
        search.forceActiveFocus();
    }

    function setCategory(key: string): void {
        search.text = "";
        category = key;
        resetList();
        if (key === "recent" && !recentRead) {
            recentRead = true;
            Places.refreshRecent();   // une fois par ouverture, quand on l'affiche (fichier de plusieurs centaines de Ko)
        }
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

    function handleKey(event: var): bool {
        const k = event.key;
        // Menu contextuel ouvert : Entrée valide son action, Échap le ferme, les flèches et Pages ne touchent pas la liste derrière.
        if (contextEntry && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Up, Qt.Key_Down, Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Left,
                Qt.Key_Right].includes(k)) {
            if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                Apps.toggleFavorite(contextEntry);
                contextEntry = null;
            }
            return true;
        }
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
        } else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
            select(selected + (k === Qt.Key_Tab ? 1 : -1));   // comme le lanceur ; le focus ne quitte pas la recherche
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
        } else if ((k === Qt.Key_PageUp || k === Qt.Key_PageDown) && pane === "categories") {
            setCategory(categories[k === Qt.Key_PageUp ? 0 : categories.length - 1].key);
        } else if (k === Qt.Key_PageUp || k === Qt.Key_PageDown) {
            const rows = Math.max(1, Math.floor((list.height + list.spacing) / (largeRow.height + list.spacing)));
            select(selected + (k === Qt.Key_PageUp ? -rows : rows));
        } else
            return false;
        return true;
    }

    WlrLayershell.namespace: "quickshell-menu"
    frameItem: frame

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
                    font.pixelSize: Theme.font.appMenu
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

        // Défile si le cadre est limité par la hauteur de l'écran (petit écran de laptop).
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.appMenu.itemPadding + Theme.appMenu.itemMargin
            clip: true
            contentHeight: column.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: column
                width: flick.width
                spacing: 2 * Theme.appMenu.itemMargin
            }
        }
    }

    // Bouton de session : ton SVG, sans fond ; survol : `rgba(255,255,255,0.1)` et bordure `overlay0` (nwg-menu).
    component SessionButton: QuickButton {
        activeFocusOnTab: false   // le clavier reste à la recherche (Entrée n'éteint jamais par surprise)
        imageSize: Theme.appMenu.sessionIconSize
        padding: Theme.appMenu.itemPadding
        radius: Theme.appMenu.itemRadius
        background: "transparent"
        hoverBackground: Theme.appMenu.buttonHover
        hoverBorder: Theme.appMenu.buttonHoverBorder
    }

    Rectangle {
        id: frame

        x: BarState.panelLeft(root.anchorX, width, root.width)
        y: Theme.panel.gap
        width: layout.implicitWidth + 2 * (Theme.appMenu.border + Theme.appMenu.padding)
        // Au plus la hauteur de l'écran sous la barre : au-delà, les colonnes défilent.
        height: Math.min(layout.implicitHeight + 2 * (Theme.appMenu.border + Theme.appMenu.padding),
            root.height - Theme.panel.gap - Theme.bar.marginSide)
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

        HoverHandler {
            id: frameHover
            onPointChanged: root.movePointer(point.position)
        }

        // Pointeur arrêté (intervalle de suivi du pointeur de Cinnamon, 30 ms) : fin de la visée, catégorie survolée prise.
        Timer {
            id: aimStop
            interval: 30
            onTriggered: {
                root.aiming = false;
                root.takeHoveredCategory();
            }
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
                Layout.preferredWidth: Math.min(Theme.appMenu.sidebarMaxWidth,
                    Math.max(places.implicitWidth, favorites.implicitWidth, session.implicitWidth))
                spacing: Theme.appMenu.spacing

                ListBox {
                    id: places
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.maximumHeight: implicitHeight

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
                    Layout.fillHeight: true
                    Layout.maximumHeight: implicitHeight
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
                        Layout.fillHeight: true
                        Layout.maximumHeight: implicitHeight

                        Repeater {
                            model: root.categories

                            MenuRow {
                                id: categoryRow
                                required property var modelData
                                Layout.fillWidth: true
                                icon: Quickshell.iconPath(modelData.icon, true)
                                label: modelData.name
                                highlighted: search.text === "" && root.category === modelData.key
                                // Survol : hors recherche et hors visée (hoverCategory) ; un clic, lui, quitte la recherche.
                                onHoveredChanged: root.hoverCategory(modelData.key, hovered)
                                onClicked: root.setCategory(modelData.key)
                            }
                        }
                    }

                    // Applications : liste défilante, de la hauteur des catégories.
                    Rectangle {
                        id: appsBox
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
                            onContentYChanged: root.contextEntry = null

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
                                icon: modelData.entry ? Apps.iconSource(modelData.entry.icon) : Icons.mimeIcon(modelData.mime)
                                label: modelData.name
                                description: modelData.description ?? ""
                                highlighted: root.pane === "apps" && root.selected === index
                                onHoveredChanged: {
                                    if (hovered)
                                        root.hoveredRow = appRow;
                                    else if (root.hoveredRow === appRow)
                                        root.hoveredRow = null;
                                    if (hovered)
                                        root.afterMove(() => {
                                            if (root.hoveredRow === appRow && !root.contextEntry) {
                                                root.pane = "apps";
                                                root.selected = index;
                                            }
                                        });
                                }
                                onClicked: root.activate(modelData)
                                onRightClicked: (x, y) => {
                                    if (modelData.entry)
                                        context.show(modelData.entry, appRow, x, y);
                                }
                            }
                        }

                        // Curseur de défilement (thème GTK) : dans une gouttière de 25 px, bordure transparente de 4 px, au moins
                        // 24 px de haut ; se fait glisser.
                        Rectangle {
                            id: thumb

                            readonly property real track: list.height - 2 * Theme.appMenu.scrollbarInset
                            readonly property real range: list.contentHeight - list.height   // défilement possible
                            readonly property real fraction: range > 0 ? (list.contentY - list.originY) / range : 0

                            visible: list.overflows
                            x: parent.width - Theme.appMenu.itemPadding - Theme.appMenu.itemMargin - Theme.appMenu.scrollbarWidth
                                + Theme.appMenu.scrollbarInset
                            y: list.y + Theme.appMenu.scrollbarInset + Math.max(0, Math.min(1, fraction)) * (track - height)
                            width: Theme.appMenu.scrollbarWidth - 2 * Theme.appMenu.scrollbarInset
                            height: Math.max(Theme.appMenu.scrollbarMinLength, list.visibleArea.heightRatio * track)
                            radius: width / 2
                            color: sliderHover.hovered || drag.pressed ? Theme.appMenu.scrollbarHover : Theme.appMenu.scrollbar

                            HoverHandler {
                                id: sliderHover
                            }

                            MouseArea {
                                id: drag

                                property real startY
                                property real startFraction

                                anchors.fill: parent
                                onPressed: mouse => {
                                    startY = mapToItem(null, mouse.x, mouse.y).y;
                                    startFraction = thumb.fraction;
                                }
                                onPositionChanged: mouse => {
                                    const free = thumb.track - thumb.height;
                                    const f = startFraction + (free > 0 ? (mapToItem(null, mouse.x, mouse.y).y - startY) / free : 0);
                                    list.contentY = list.originY + Math.max(0, Math.min(1, f)) * thumb.range;
                                }
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
                        font.pixelSize: Theme.font.appMenuSearch
                        color: Theme.appMenu.text
                        onTextChanged: {
                            root.pane = "apps";
                            root.resetList();
                        }
                        Keys.onPressed: event => event.accepted = root.handleKey(event)
                    }

                    Text {
                        id: searchGlyph
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.appMenu.itemPadding
                        anchors.verticalCenter: search.verticalCenter
                        text: Theme.icon.search
                        font.family: Theme.font.icons
                        font.pixelSize: Theme.font.appMenu
                        color: Theme.appMenu.text
                    }
                }
            }
        }

        // Menu contextuel ouvert : un appui ailleurs dans le cadre (ou sur sa bordure) le ferme seulement, sans agir dessous.
        MouseArea {
            anchors.fill: parent
            visible: root.contextEntry !== null
            z: 1
            acceptedButtons: Qt.AllButtons
            onPressed: root.contextEntry = null
        }

        // Menu contextuel d'une application (clic droit) : ajouter aux favoris ou en retirer.
        ListBox {
            id: context

            property point at   // point du clic droit ; la position suit la taille du menu et du cadre

            function show(entry: var, from: Item, x: real, y: real): void {
                at = from.mapToItem(frame, x, y);
                root.contextEntry = entry;
            }

            x: Math.min(at.x, frame.width - width - Theme.appMenu.border)
            y: Math.min(at.y, frame.height - height - Theme.appMenu.border)

            visible: root.contextEntry !== null
            z: 1

            // Le survol du menu contextuel ne passe pas aux lignes et catégories situées dessous.
            HoverHandler {
                blocking: true
            }

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
