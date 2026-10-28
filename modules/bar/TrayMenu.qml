import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config

// Menu d'une application du tray (THEME.md § 3 « Menus du tray ») : copie des menus GTK du thème, texte en Inter.
// Menu principal : popup avec prise du clavier et de la souris (`grabFocus`), fermé par wlroots au clic sur une autre
// application ; un clic sur une barre le ferme aussi (BarState.closePopups). Sous-menus : même composant, sans prise.
// Clavier (la barre l'accepte pendant le survol des icônes et tant que le menu est ouvert, Tray.qml) : ↑/↓ pour choisir,
// Entrée pour activer, → / ← pour ouvrir / fermer un sous-menu, Échap pour fermer ; il va au sous-menu où une entrée est choisie.
PopupWindow {
    id: root

    // Du bord de la fenêtre au contenu : liseré extérieur, bordure intérieure, marge.
    readonly property int inset: Theme.trayMenu.outlineWidth + Theme.trayMenu.frameWidth + Theme.trayMenu.padding

    // Menu à afficher (SystemTrayItem.menu ou entrée parente d'un sous-menu).
    property QsMenuHandle menu
    // Menu principal (racine) : c'est lui que l'on ferme quand un élément est choisi.
    property var rootMenu: root
    readonly property bool isRoot: rootMenu === root
    signal closeRequested

    // Ouverture demandée : la fenêtre n'apparaît qu'une fois les entrées reçues (D-Bus, asynchrone) ; un popup déjà affiché
    // ne se redimensionne pas proprement (Sway étire l'ancienne image).
    property bool open: false
    onOpenChanged: update()
    onEntriesChanged: {
        if (submenuEntry && !entries.includes(submenuEntry))
            submenuEntry = null;
        if (currentEntry && !entries.includes(currentEntry))
            currentEntry = null;
        if (selectFirst && !currentEntry)
            move(1);
        update();
    }
    function update(): void {
        if (!open)
            visible = false;
        else if (entries.length > 0 && !visible)
            Qt.callLater(root.show);
    }
    function show(): void {
        visible = open && entries.length > 0;
    }

    // Entrée survolée ou choisie au clavier (null : aucune ; suivie par objet, l'index change quand l'application en ajoute
    // ou en retire), sous-menu ouvert et ligne de son entrée.
    property QsMenuEntry currentEntry: null
    readonly property int current: entries.indexOf(currentEntry)
    property QsMenuEntry submenuEntry: null
    property Item submenuItem: null
    // Sous-menu ouvert au clavier : sa première entrée est choisie dès qu'elle arrive.
    property bool selectFirst: false

    // Ligne de l'entrée disparue (menu mis à jour) : sous-menu fermé.
    onSubmenuItemChanged: {
        if (!submenuItem)
            submenuEntry = null;
    }

    function closeAll(): void {
        if (isRoot)
            open = false;
        else
            rootMenu.closeAll();
    }

    // Sous-menu d'une autre entrée : recréé (un popup affiché ne change ni de taille ni de place proprement).
    function openSubmenu(entry: QsMenuEntry, item: Item): void {
        if (submenuEntry === entry && submenuItem === item)
            return;
        submenuEntry = null;
        submenuItem = item;
        submenuEntry = entry;
    }

    grabFocus: isRoot
    color: "transparent"
    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    // Clavier au cadre à chaque affichage (avec un `focus: true` déclaré, Qt 6.12 plante sur un clic droit au coin du menu).
    onVisibleChanged: {
        if (visible) {
            frame.forceActiveFocus();
        } else {
            open = false;   // fermé par wlroots (clic sur une autre application)
            currentEntry = null;
            submenuEntry = null;
            selectFirst = false;
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.menu
    }

    readonly property var entries: opener.children.values

    // Rien de sélectionné : Bas part du début, Haut de la fin (comme GTK).
    function move(step: int): void {
        const n = entries.length;
        const start = current >= 0 ? current : step > 0 ? -1 : n;
        for (let k = 1; k <= n; k++) {
            const i = ((start + step * k) % n + n) % n;
            if (!entries[i].isSeparator && entries[i].enabled) {
                currentEntry = entries[i];
                return;
            }
        }
    }

    function activate(entry: QsMenuEntry, item: Item): void {
        if (!entry || entry.isSeparator || !entry.enabled)
            return;
        if (entry.hasChildren) {
            openSubmenu(entry, item);
            return;
        }
        entry.triggered();
        closeAll();
    }

    // Menu qui reçoit le clavier : le sous-menu affiché le plus profond où une entrée est choisie (ou en attente de la première).
    function keyTarget(): var {
        const sub = submenu.item;
        return sub && (sub.currentEntry || sub.selectFirst) ? sub.keyTarget() : root;
    }

    function currentRow(): Item {
        return current >= 0 ? repeater.itemAt(current) : null;
    }

    // → : ouvre le sous-menu de l'entrée choisie et y passe (rien sur une entrée simple, comme GTK).
    function enterSubmenu(): void {
        if (!currentEntry?.hasChildren || !currentEntry.enabled)
            return;
        openSubmenu(currentEntry, currentRow());
        if (submenu.item) {
            submenu.item.selectFirst = true;
            submenu.item.move(1);
        }
    }

    Rectangle {
        id: frame

        // Liseré extérieur 1 px, puis cadre (fond, bordure intérieure) — mesurés sur le menu GTK.
        implicitWidth: column.implicitWidth + 2 * root.inset
        implicitHeight: column.implicitHeight + 2 * root.inset
        radius: Theme.trayMenu.radius + 1
        color: Theme.trayMenu.outline

        // Seul le menu principal a le clavier (popup « grab ») : il le passe au sous-menu actif.
        Keys.onEscapePressed: root.closeAll()
        Keys.onUpPressed: root.keyTarget().move(-1)
        Keys.onDownPressed: root.keyTarget().move(1)
        Keys.onReturnPressed: root.keyTarget().activateCurrent()
        Keys.onEnterPressed: root.keyTarget().activateCurrent()
        Keys.onRightPressed: root.keyTarget().enterSubmenu()
        Keys.onLeftPressed: {
            const target = root.keyTarget();
            if (!target.isRoot)
                target.closeRequested();
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.trayMenu.outlineWidth
            radius: Theme.trayMenu.radius
            color: Theme.trayMenu.background
            border.width: Theme.trayMenu.frameWidth
            border.color: Qt.tint(Theme.trayMenu.background, Theme.trayMenu.frame)
        }

        // Largeur commune : celle de l'élément le plus large.
        ColumnLayout {
            id: column
            x: root.inset
            y: root.inset
            spacing: 0

            Repeater {
                id: repeater
                // Modèle d'objets : une mise à jour du menu garde les lignes des entrées inchangées.
                model: opener.children

                Item {
                    id: row

                    required property QsMenuEntry modelData

                    readonly property bool highlighted: root.currentEntry === modelData || root.submenuEntry === modelData

                    Layout.fillWidth: true
                    implicitWidth: modelData.isSeparator ? 0
                        : Theme.trayMenu.itemPaddingH * 2 + Theme.trayMenu.toggleSize + Theme.trayMenu.toggleSpacing + label.implicitWidth
                            + (modelData.hasChildren ? Theme.trayMenu.arrowMargin + Theme.trayMenu.toggleSize : 0)
                    implicitHeight: modelData.isSeparator ? Theme.trayMenu.separatorHeight + 2 * Theme.trayMenu.separatorMargin
                        : Math.max(label.implicitHeight, Theme.trayMenu.toggleSize) + 2 * Theme.trayMenu.itemPaddingV

                    // Séparateur
                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Theme.trayMenu.separatorHeight
                        color: Theme.trayMenu.separator
                    }

                    Rectangle {
                        visible: !row.modelData.isSeparator && row.highlighted && row.modelData.enabled
                        anchors.fill: parent
                        radius: Theme.trayMenu.itemRadius
                        color: Theme.trayMenu.itemHover
                    }

                    Item {
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        opacity: row.modelData.enabled ? 1 : Theme.trayMenu.disabledOpacity

                        // Marge gauche : case, radio ou icône de l'application.
                        Item {
                            id: toggle
                            x: Theme.trayMenu.itemPaddingH + (isToggle ? Theme.trayMenu.toggleMarginLeft : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.trayMenu.toggleSize
                            height: Theme.trayMenu.toggleSize

                            readonly property bool isToggle: row.modelData.buttonType !== QsMenuButtonType.None
                            readonly property bool checked: row.modelData.checkState === Qt.Checked

                            Rectangle {
                                visible: toggle.isToggle
                                anchors.fill: parent
                                radius: width / 2
                                color: toggle.checked ? Theme.trayMenu.toggleChecked : Theme.trayMenu.toggleBackground
                            }

                            // Marques du thème GTK (small-checkbox-checked-symbolic, small-radio-checked-symbolic), 16 × 16.
                            Shape {
                                visible: toggle.isToggle && toggle.checked
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeWidth: 0
                                    strokeColor: "transparent"
                                    fillColor: Theme.trayMenu.toggleMark
                                    PathSvg {
                                        path: row.modelData.buttonType === QsMenuButtonType.RadioButton
                                            ? "M 8,6 C 9.1045695,6 10,6.8954305 10,8 10,9.1045695 9.1045695,10 8,10 6.8954305,10 6,9.1045695 6,8 6,6.8954305 6.8954305,6 8,6 Z"
                                            : "m 11.943359,5.4550781 c 0.12781,0 0.255582,0.04855 0.353516,0.1464844 0.195869,0.1958686 0.195869,0.5111627 0,0.7070313 L 7.3457031,11.257812 c -0.1958686,0.19587 -0.5111626,0.19587 -0.7070312,0 L 3.8105469,8.4296875 c -0.1958686,-0.1958686 -0.1958686,-0.5111627 0,-0.7070313 0.1958686,-0.1958685 0.5111626,-0.1958685 0.7070312,0 L 6.9921875,10.197266 11.587891,5.6015625 c 0.09793,-0.097934 0.227659,-0.1464844 0.355468,-0.1464844 z"
                                    }
                                }
                            }

                            Image {
                                visible: !toggle.isToggle && row.modelData.icon !== ""
                                anchors.fill: parent
                                source: row.modelData.icon
                                sourceSize: Qt.size(width, height)
                                asynchronous: true
                            }
                        }

                        Text {
                            id: label
                            x: Theme.trayMenu.itemPaddingH + Theme.trayMenu.toggleSize + Theme.trayMenu.toggleSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            // Les mnémoniques GTK (« _Fichier ») ne sont pas affichées.
                            text: row.modelData.text.replace(/_(?!_)/g, "").replace(/__/g, "_")
                            font.family: Theme.font.text
                            font.pixelSize: Theme.trayMenu.fontSize
                            color: Theme.trayMenu.gtkForeground
                        }

                        // Flèche de sous-menu (pan-end-symbolic : triangle vers la droite).
                        Shape {
                            visible: row.modelData.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.trayMenu.itemPaddingH
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.trayMenu.toggleSize
                            height: Theme.trayMenu.toggleSize
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: 0
                                strokeColor: "transparent"
                                fillColor: Theme.trayMenu.gtkForeground
                                PathSvg {
                                    path: "M 6,4 L 10,8 L 6,12 Z"
                                }
                            }
                        }
                    }

                    HoverHandler {
                        enabled: !row.modelData.isSeparator
                        onHoveredChanged: {
                            if (!hovered)
                                return;
                            root.currentEntry = row.modelData;
                            if (row.modelData.hasChildren && row.modelData.enabled)
                                root.openSubmenu(row.modelData, row);
                            else
                                root.submenuEntry = null;
                        }
                    }

                    TapHandler {
                        enabled: !row.modelData.isSeparator
                        onTapped: root.activate(row.modelData, row)
                    }
                }
            }
        }
    }

    function activateCurrent(): void {
        activate(currentEntry, currentRow());
    }

    // Sous-menu : à droite du cadre, aligné sur l'élément parent ; ancré sur toute la ligne (cadre compris) pour qu'en
    // débordant, il bascule à gauche du cadre au lieu de le recouvrir. Chargé par URL : un composant ne peut pas
    // s'instancier lui-même directement.
    Loader {
        id: submenu
        active: root.submenuEntry !== null && root.visible
        source: Qt.resolvedUrl("TrayMenu.qml")
        onLoaded: {
            item.rootMenu = Qt.binding(() => root.rootMenu);
            item.menu = root.submenuEntry;
            item.anchor.item = root.submenuItem;
            item.anchor.rect.x = -root.inset;
            item.anchor.rect.y = -root.inset;
            item.anchor.rect.width = root.submenuItem.width + 2 * root.inset;
            item.anchor.rect.height = root.submenuItem.height + root.inset;
            item.anchor.edges = Edges.Top | Edges.Right;
            item.anchor.gravity = Edges.Bottom | Edges.Right;
            item.closeRequested.connect(() => root.submenuEntry = null);
            item.open = true;
        }
    }
}
