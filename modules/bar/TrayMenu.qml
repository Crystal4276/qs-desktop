import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config

// Menu d'une application du tray (THEME.md § 3 « Menus du tray ») : copie des menus GTK du thème, texte en Inter.
// Menu principal : popup avec prise du clavier et de la souris (`grabFocus`), fermé par wlroots au clic sur une autre
// application ; un clic sur une barre le ferme aussi (BarState.closePopups). Sous-menus : même composant, sans prise.
// Clavier : ↑/↓ pour choisir, Entrée pour activer, → / ← pour ouvrir / fermer un sous-menu, Échap pour fermer.
PopupWindow {
    id: root

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
    onEntriesChanged: update()
    function update(): void {
        if (!open)
            visible = false;
        else if (entries.length > 0 && !visible)
            Qt.callLater(() => visible = open);
    }

    // Élément survolé ou choisi au clavier (-1 : aucun) et sous-menu ouvert.
    property int current: -1
    property var submenuEntry: null
    property Item submenuItem: null

    function closeAll(): void {
        if (isRoot)
            open = false;
        else
            rootMenu.closeAll();
    }

    grabFocus: isRoot
    color: "transparent"
    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    onVisibleChanged: {
        if (!visible) {
            open = false;   // fermé par wlroots (clic sur une autre application)
            current = -1;
            submenuEntry = null;
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.menu
    }

    readonly property var entries: opener.children.values

    function move(step: int): void {
        const n = entries.length;
        for (let k = 1; k <= n; k++) {
            const i = (current + step * k + n * k) % n;
            if (!entries[i].isSeparator && entries[i].enabled) {
                current = i;
                return;
            }
        }
    }

    function activate(index: int, item: Item): void {
        const entry = entries[index];
        if (!entry || entry.isSeparator || !entry.enabled)
            return;
        if (entry.hasChildren) {
            submenuItem = item;
            submenuEntry = entry;
            return;
        }
        entry.triggered();
        closeAll();
    }

    Rectangle {
        id: frame

        // Liseré extérieur 1 px, puis cadre (fond, bordure intérieure) — mesurés sur le menu GTK.
        implicitWidth: column.implicitWidth + 2 * (Theme.trayMenu.padding + 2)
        implicitHeight: column.implicitHeight + 2 * (Theme.trayMenu.padding + 2)
        radius: Theme.trayMenu.radius + 1
        color: Theme.trayMenu.outline

        focus: true
        Keys.onEscapePressed: root.closeAll()
        Keys.onUpPressed: root.move(-1)
        Keys.onDownPressed: root.move(1)
        Keys.onReturnPressed: root.activate(root.current, repeater.itemAt(root.current))
        Keys.onEnterPressed: root.activate(root.current, repeater.itemAt(root.current))
        Keys.onRightPressed: root.activate(root.current, repeater.itemAt(root.current))
        Keys.onLeftPressed: {
            if (!root.isRoot)
                root.closeRequested();
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.trayMenu.radius
            color: Theme.trayMenu.background
            border.width: 1
            border.color: Qt.tint(Theme.trayMenu.background, Theme.trayMenu.frame)
        }

        // Largeur commune : celle de l'élément le plus large.
        ColumnLayout {
            id: column
            x: Theme.trayMenu.padding + 2
            y: Theme.trayMenu.padding + 2
            spacing: 0

            Repeater {
                id: repeater
                model: root.entries

                Item {
                    id: row

                    required property QsMenuEntry modelData
                    required property int index

                    readonly property bool highlighted: root.current === index || root.submenuEntry === modelData

                    Layout.fillWidth: true
                    implicitWidth: modelData.isSeparator ? 0
                        : Theme.trayMenu.itemPaddingH * 2 + Theme.trayMenu.toggleSize + Theme.trayMenu.toggleSpacing + label.implicitWidth
                            + (modelData.hasChildren ? Theme.trayMenu.arrowMargin + Theme.trayMenu.toggleSize : 0)
                    implicitHeight: modelData.isSeparator ? 1 + 2 * Theme.trayMenu.separatorMargin
                        : Math.max(label.implicitHeight, Theme.trayMenu.toggleSize) + 2 * Theme.trayMenu.itemPaddingV

                    // Séparateur
                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
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
                            // Case et radio : marge gauche de -3 px dans le thème GTK.
                            x: Theme.trayMenu.itemPaddingH - (isToggle ? 3 : 0)
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
                            root.current = row.index;
                            if (row.modelData.hasChildren && row.modelData.enabled)
                                root.activate(row.index, row);
                            else
                                root.submenuEntry = null;
                        }
                    }

                    TapHandler {
                        enabled: !row.modelData.isSeparator
                        onTapped: root.activate(row.index, row)
                    }
                }
            }
        }
    }

    // Sous-menu : aligné sur l'élément parent, à sa droite (basculé à gauche s'il déborde).
    // Chargé par URL : un composant ne peut pas s'instancier lui-même directement.
    Loader {
        id: submenu
        active: root.submenuEntry !== null && root.visible
        source: Qt.resolvedUrl("TrayMenu.qml")
        onLoaded: {
            item.rootMenu = Qt.binding(() => root.rootMenu);
            item.menu = Qt.binding(() => root.submenuEntry);
            item.anchor.item = root.submenuItem;
            item.anchor.rect.x = root.submenuItem.width + Theme.trayMenu.padding + 2;
            item.anchor.rect.y = -(Theme.trayMenu.padding + 2);
            item.anchor.edges = Edges.Top | Edges.Left;
            item.anchor.gravity = Edges.Bottom | Edges.Right;
            item.closeRequested.connect(() => root.submenuEntry = null);
            item.open = true;
        }
    }
}
