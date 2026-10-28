import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config

// Menu d'une application du tray (THEME.md § 3 « Menus du tray ») : copie des menus GTK du thème, texte en Inter.
// Menu principal : popup avec prise du clavier et de la souris (`grabFocus`), fermé par wlroots au clic sur une autre
// application ; un clic sur une barre le ferme aussi (BarState.closePopups). Sous-menus : même composant, avec prise aussi
// (sans prise, Qt 6.12 envoie leurs clics au menu principal, qui se ferme). Clavier (la barre l'accepte pendant le survol des
// icônes et tant que le menu est ouvert, Tray.qml) : ↑/↓ pour choisir, Entrée ou Espace pour activer, → / ← pour ouvrir /
// fermer un sous-menu, Échap pour fermer ; il va au dernier sous-menu ouvert.
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
    // Menu affiché qui se vide (application partie, menu effacé) : fermé.
    function update(): void {
        if (!open || (visible && entries.length === 0))
            visible = false;
        else if (entries.length > 0 && !visible)
            Qt.callLater(root.show);
    }
    function show(): void {
        visible = open && entries.length > 0;
    }

    // Toujours sans entrées 2 s après la demande (menu vide, application muette) : abandonné (il s'afficherait sinon plus tard,
    // tout seul, et garderait le clavier de la barre).
    Timer {
        running: root.open && !root.visible
        interval: 2000
        onTriggered: {
            if (root.isRoot)
                root.open = false;
            else
                root.closeRequested();
        }
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

    // Sous-menu d'une autre entrée : recréé (un popup affiché ne change ni de taille ni de place proprement). L'ancien est
    // caché d'abord, avec ses propres sous-menus : encore là (destruction différée), il garderait la prise et Qt lui rattacherait
    // le nouveau, fermé avec lui.
    function openSubmenu(entry: QsMenuEntry, item: Item): void {
        if (!item || (submenuEntry === entry && submenuItem === item))
            return;
        submenu.item?.hideChain();
        submenuEntry = null;
        submenuItem = item;
        submenuEntry = entry;
    }

    // Ce menu et ses sous-menus cachés, le plus profond d'abord.
    function hideChain(): void {
        submenu.item?.hideChain();
        visible = false;
    }

    // Survol : ligne choisie aussitôt ; sous-menu ouvert, changé ou fermé après le délai de GTK (gtk-menu-popup-delay,
    // 225 ms), pour qu'on puisse passer en diagonale sur d'autres lignes jusqu'au sous-menu ouvert.
    property Item hoverRow: null
    property point hoverPosition
    signal pointerEntered

    // Même ligne sans mouvement (pointeur rendu à ce menu quand un sous-menu se ferme) : ignoré, sinon ← rouvrirait le sous-menu.
    function hover(row: Item, position: point): void {
        if (row === hoverRow && position.x === hoverPosition.x && position.y === hoverPosition.y)
            return;
        hoverPosition = position;
        currentEntry = row.modelData;
        hoverRow = row;
        submenuTimer.restart();
        if (!isRoot)
            pointerEntered();
    }

    Timer {
        id: submenuTimer
        interval: 225
        onTriggered: {
            const row = root.hoverRow;
            if (!row || root.currentEntry !== row.modelData)
                return;
            if (row.modelData.hasChildren && row.modelData.enabled)
                root.openSubmenu(row.modelData, row);
            else
                root.submenuEntry = null;
        }
    }

    grabFocus: true
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
            hoverPosition = Qt.point(-1, -1);
            if (!isRoot)
                closeRequested();   // sous-menu vidé : le parent l'oublie (il pourra le rouvrir)
        }
    }

    // Menu tenu seulement pendant la demande : chaque ouverture renvoie AboutToShow et « opened », la fermeture « closed »
    // (les applications qui reconstruisent leur menu à l'ouverture montrent sinon l'ancien).
    QsMenuOpener {
        id: opener
        menu: root.open ? root.menu : null
    }

    readonly property var entries: opener.children.values

    // Rien de sélectionné : Bas part du début, Haut de la fin (comme GTK). Le sous-menu d'une autre entrée se ferme.
    function move(step: int): void {
        const n = entries.length;
        const start = current >= 0 ? current : step > 0 ? -1 : n;
        for (let k = 1; k <= n; k++) {
            const i = ((start + step * k) % n + n) % n;
            if (!entries[i].isSeparator && entries[i].enabled) {
                submenuTimer.stop();
                currentEntry = entries[i];
                if (submenuEntry !== currentEntry)
                    submenuEntry = null;
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
        radius: Theme.trayMenu.radius + Theme.trayMenu.outlineWidth
        color: Theme.trayMenu.outline

        // Pointeur arrivé n'importe où dans un sous-menu (séparateur, marge compris) : le parent le garde ouvert.
        HoverHandler {
            onHoveredChanged: {
                if (hovered && !root.isRoot)
                    root.pointerEntered();
            }
        }

        // Le clavier va au dernier popup « grab » ouvert ; à défaut, ce menu le passe au sous-menu actif.
        Keys.onEscapePressed: root.closeAll()
        Keys.onUpPressed: root.keyTarget().move(-1)
        Keys.onDownPressed: root.keyTarget().move(1)
        Keys.onReturnPressed: root.keyTarget().activateCurrent()
        Keys.onEnterPressed: root.keyTarget().activateCurrent()
        Keys.onSpacePressed: root.keyTarget().activateCurrent()
        Keys.onRightPressed: {
            // Sous-menu ouvert au survol, rien de choisi : sa première entrée (comme GTK).
            const target = root.keyTarget();
            if (!target.isRoot && !target.currentEntry)
                target.move(1);
            else
                target.enterSubmenu();
        }
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
                            textFormat: Text.PlainText   // comme GTK : « <b> » affiché tel quel
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

                    // À l'entrée et à chaque mouvement (après un choix au clavier, bouger sur la ligne la choisit de nouveau).
                    HoverHandler {
                        enabled: !row.modelData.isSeparator
                        // Ligne quittée avant le délai (vers l'extérieur du menu) : rien n'est ouvert ni fermé.
                        onHoveredChanged: {
                            if (hovered)
                                root.hover(row, point.scenePosition);
                            else if (root.hoverRow === row)
                                submenuTimer.stop();
                        }
                        onPointChanged: {
                            if (hovered && root.currentEntry !== row.modelData)
                                root.hover(row, point.scenePosition);
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

    // Entrée : comme →, sur une entrée à sous-menu.
    function activateCurrent(): void {
        if (currentEntry?.hasChildren)
            enterSubmenu();
        else
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
            item.anchor.rect.height = root.submenuItem.height + 2 * root.inset;
            item.anchor.edges = Edges.Top | Edges.Right;
            item.anchor.gravity = Edges.Bottom | Edges.Right;
            // Seulement ce sous-menu : l'ancien, remplacé, peut se fermer après l'ouverture du suivant.
            const sub = item;
            sub.closeRequested.connect(() => {
                if (submenu.item === sub)
                    root.submenuEntry = null;
            });
            // Pointeur arrivé dans le sous-menu : il reste ouvert, son entrée parente choisie.
            sub.pointerEntered.connect(() => {
                submenuTimer.stop();
                root.currentEntry = root.submenuEntry;
                if (!root.isRoot)
                    root.pointerEntered();
            });
            item.open = true;
        }
    }
}
