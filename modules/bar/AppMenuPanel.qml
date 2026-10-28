import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.services

// Carte d'une application du tray (ta demande du 2026-10-28, remplace le menu copié de GTK) : nom de l'application en titre,
// entrées de son menu (dbusmenu) en lignes ; séparateurs en traits de bordure ; un sous-menu devient une section avec ses
// entrées. Menu demandé à l'application seulement pendant l'affichage (elle le reconstruit à chaque ouverture).
// Entrée choisie : carte fermée, puis fenêtre de l'application affichée (showWindowAfter).
Panel {
    id: root

    required property SystemTrayItem item

    title: {
        const name = item.tooltipTitle || item.title || item.id;
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    // Largeur ajustée au contenu (titre, entrée la plus longue), pas celle des autres cartes.
    frameWidth: Math.max(titleMetrics.advanceWidth, list.implicitWidth) + 2 * Theme.panel.padding

    TextMetrics {
        id: titleMetrics
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.fontSize
        font.bold: true
        text: root.title
    }

    // Largeur d'une ligne (PanelRow) : texte (`textWidth`), marges, espacement de la colonne de droite (vide), icône éventuelle.
    function rowWidth(textWidth: real, icon: string): real {
        return Math.ceil(textWidth) + 2 * Theme.panel.rowPadding + Theme.panel.spacing
            + (icon !== "" ? Theme.panel.iconSize + Theme.panel.spacing : 0);
    }

    // Les mnémoniques GTK (« _Fichier ») ne sont pas affichées.
    function label(text: string): string {
        return text.replace(/_(?!_)/g, "").replace(/__/g, "_");
    }

    // Fenêtre de l'application affichée après une entrée (ta demande du 2026-10-28) : Steam (Store, Library, Friends… s'ouvrent
    // sur son espace de travail, invisibles depuis un autre), sauf ses jeux récents (premier groupe, avant le premier
    // séparateur) et « Exit Steam ».
    function showWindowAfter(entry: QsMenuEntry, group: int): bool {
        return item.id === "steam" && group > 0 && !/^exit\b/i.test(entry.text);
    }

    // `group` : nombre de séparateurs avant l'entrée (Steam : 0 = jeux récents). Entrée activée avant la fermeture (qui libère
    // le menu et ses entrées).
    function trigger(entry: QsMenuEntry, group: int): void {
        const showWindow = showWindowAfter(entry, group);
        entry.triggered();
        close();
        if (showWindow)
            Compositor.showAppWindow(item.id);
    }

    QsMenuOpener {
        id: opener
        menu: root.visible && root.item.hasMenu ? root.item.menu : null
    }

    PanelSection {
        visible: opener.children.values.length === 0
        text: root.item.hasMenu ? "Loading…" : "No menu"
    }

    ColumnLayout {
        id: list
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: opener.children

            Loader {
                id: slot

                required property QsMenuEntry modelData
                required property int index
                readonly property int group: {
                    const values = opener.children.values;
                    let n = 0;
                    for (let i = 0; i < index && i < values.length; i++) {
                        if (values[i].isSeparator)
                            n++;
                    }
                    return n;
                }

                Layout.fillWidth: true
                sourceComponent: modelData.isSeparator ? separator : modelData.hasChildren ? submenu : row

                Component {
                    id: separator

                    Rectangle {
                        implicitHeight: Theme.panel.border + 2 * Theme.panel.rowPadding
                        color: "transparent"

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: Theme.panel.border
                            color: Theme.panel.borderColor
                        }
                    }
                }

                Component {
                    id: row

                    PanelRow {
                        id: entryRow
                        implicitWidth: root.rowWidth(entryMetrics.advanceWidth, slot.modelData.icon)
                        icon: slot.modelData.icon
                        text: root.label(slot.modelData.text)
                        active: slot.modelData.checkState === Qt.Checked
                        enabled: slot.modelData.enabled
                        onClicked: root.trigger(slot.modelData, slot.group)

                        TextMetrics {
                            id: entryMetrics
                            font.family: Theme.font.text
                            font.pixelSize: Theme.panel.fontSize
                            text: entryRow.text
                        }
                    }
                }

                // Sous-menu : section titrée, ses entrées dessous (un seul niveau).
                Component {
                    id: submenu

                    ColumnLayout {
                        spacing: 0

                        QsMenuOpener {
                            id: subOpener
                            menu: slot.modelData
                        }

                        PanelSection {
                            Layout.topMargin: Theme.panel.rowPadding
                            text: root.label(slot.modelData.text)
                        }

                        Repeater {
                            model: subOpener.children

                            PanelRow {
                                id: subRow
                                required property QsMenuEntry modelData

                                visible: !modelData.isSeparator
                                implicitWidth: root.rowWidth(subMetrics.advanceWidth, modelData.icon)
                                icon: modelData.icon
                                text: root.label(modelData.text)
                                active: modelData.checkState === Qt.Checked
                                enabled: modelData.enabled && !modelData.hasChildren
                                onClicked: root.trigger(modelData, slot.group)

                                TextMetrics {
                                    id: subMetrics
                                    font.family: Theme.font.text
                                    font.pixelSize: Theme.panel.fontSize
                                    text: subRow.text
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
