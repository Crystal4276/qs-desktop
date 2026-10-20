import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.modules.bar

// Fenêtre du lanceur : thème `launcher.rasi` (THEME.md § 5) et comportement de Rofi 2.0.0 (code lu, ARCHITECTURE § 10.1.3).
// Surface de la couche Overlay qui couvre la zone utile de l'écran focalisé (hors barres) : le cadre y est centré comme Rofi,
// le clavier lui est réservé, un clic à côté du cadre, sur une barre ou sur un autre écran le ferme (`click-to-exit`).
// Clavier : Entrée lance (sans résultat : le texte comme commande ; Maj+Entrée : dans un terminal), Ctrl+Entrée lance le texte,
// Ctrl+Maj+Entrée dans un terminal, Haut/Bas/Tab/Pages/Début/Fin pour la sélection, Ctrl+Haut/Bas pour les textes déjà saisis,
// Maj+Suppr retire de l'historique, raccourcis d'édition Emacs de Rofi, Échap ferme.
// Souris : clic = sélection, double clic = lancement, molette = ligne suivante ou précédente. Défilement par page.
OverlayPopup {
    id: root

    property int selected: 0
    property alias query: input.text
    readonly property var results: Apps.filter(input.text)
    readonly property int rowHeight: Math.max(Theme.launcher.itemIconSize, measure.implicitHeight + 2 * Theme.launcher.itemTextMargin)
        + 2 * Theme.launcher.itemPadding
    readonly property int rows: Math.max(1, Math.floor((list.height + Theme.launcher.listSpacing) / (rowHeight + Theme.launcher.listSpacing)))
    readonly property int pageStart: Math.floor(selected / rows) * rows

    // Textes saisis (Ctrl+Haut / Ctrl+Bas) : les précédents, puis la saisie en cours.
    property var inputHistory: []
    property int inputIndex: 0

    // Sur l'écran focalisé ; déjà ouvert : remis à zéro sur place (sans se fermer, ce qui enregistrerait la saisie en cours, ni
    // changer d'écran).
    function open(): void {
        if (!visible)
            screen = Quickshell.screens.find(s => s.name === Compositor.focusedOutput) ?? Quickshell.screens[0];
        prepareOpen(null);   // les autres popups se ferment (OverlayPopup)
        inputHistory = [...Apps.inputs, ""];
        inputIndex = inputHistory.length - 1;
        input.text = "";
        selected = 0;
        visible = true;
        input.forceActiveFocus();
    }

    function toggle(): void {
        visible ? close() : open();
    }

    function accept(terminal: bool): void {
        const entry = results[selected];
        if (entry)
            Apps.launch(entry);
        else if (input.text !== "")
            Apps.run(input.text, terminal);
        close();
    }

    function runText(terminal: bool): void {
        if (input.text !== "")
            Apps.run(input.text, terminal);
        close();
    }

    function select(index: int): void {
        if (results.length > 0)
            selected = Math.max(0, Math.min(index, results.length - 1));
    }

    function recall(step: int): void {
        const index = inputIndex + step;
        if (index < 0 || index >= inputHistory.length)
            return;
        inputHistory[inputIndex] = input.text;
        inputIndex = index;
        input.text = inputHistory[index];
    }

    function wordBack(pos: int): int {
        const t = input.text;
        while (pos > 0 && /\s/.test(t[pos - 1]))
            pos--;
        while (pos > 0 && !/\s/.test(t[pos - 1]))
            pos--;
        return pos;
    }

    function wordForward(pos: int): int {
        const t = input.text;
        while (pos < t.length && /\s/.test(t[pos]))
            pos++;
        while (pos < t.length && !/\s/.test(t[pos]))
            pos++;
        return pos;
    }

    function handleKey(event: var): bool {
        const k = event.key;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        const enter = k === Qt.Key_Return || k === Qt.Key_Enter;
        const pos = input.cursorPosition;

        if (k === Qt.Key_Escape)
            close();
        else if (enter && ctrl)
            runText(shift);
        else if (enter || (ctrl && !alt && (k === Qt.Key_J || k === Qt.Key_M)))
            accept(enter && shift);
        else if (ctrl && k === Qt.Key_Up)
            recall(-1);
        else if (ctrl && k === Qt.Key_Down)
            recall(1);
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab || (ctrl && k === Qt.Key_P))
            select(selected - 1);
        else if (k === Qt.Key_Down || k === Qt.Key_Tab || (ctrl && k === Qt.Key_N))
            select(selected + 1);
        else if (k === Qt.Key_PageUp)
            select(selected < rows ? 0 : selected - rows);
        else if (k === Qt.Key_PageDown)
            select(selected + rows);
        else if (k === Qt.Key_Home)
            select(0);
        else if (k === Qt.Key_End)
            select(results.length - 1);
        else if (shift && k === Qt.Key_Delete) {
            if (results[selected] && Apps.inHistory(results[selected]))
                Apps.forget(results[selected]);
        } else if (ctrl && alt && k === Qt.Key_H)
            input.remove(wordBack(pos), pos);
        else if (ctrl && alt && k === Qt.Key_D)
            input.remove(pos, wordForward(pos));
        else if (alt && k === Qt.Key_B)
            input.cursorPosition = wordBack(pos);
        else if (alt && k === Qt.Key_F)
            input.cursorPosition = wordForward(pos);
        else if (ctrl && k === Qt.Key_A)
            input.cursorPosition = 0;
        else if (ctrl && k === Qt.Key_E)
            input.cursorPosition = input.text.length;
        else if (ctrl && k === Qt.Key_B)
            input.cursorPosition = Math.max(0, pos - 1);
        else if (ctrl && k === Qt.Key_F)
            input.cursorPosition = Math.min(input.text.length, pos + 1);
        else if (ctrl && k === Qt.Key_H)
            input.remove(Math.max(0, pos - 1), pos);
        else if (ctrl && k === Qt.Key_D)
            input.remove(pos, pos + 1);
        else if (ctrl && k === Qt.Key_K)
            input.remove(pos, input.text.length);
        else if (ctrl && k === Qt.Key_U)
            input.remove(0, pos);
        else if (ctrl && k === Qt.Key_W)
            input.text = "";
        else
            return false;
        return true;
    }

    // OverlayPopup (`click-to-exit` de Rofi) ; à la fermeture, la saisie rejoint les textes déjà saisis.
    WlrLayershell.namespace: "quickshell-launcher"
    frameItem: frame
    onClosing: {
        inputHistory[inputIndex] = input.text;
        Apps.saveInputs(inputHistory);
    }

    Rectangle {
        id: frame

        // Centré, arrondi vers le haut et la gauche comme Rofi.
        x: Math.floor((parent.width - width) / 2)
        y: Math.floor((parent.height - height) / 2)
        width: Theme.launcher.width
        height: Theme.launcher.height
        color: Theme.launcher.background
        border.width: Theme.launcher.border
        border.color: Theme.launcher.borderColor
        radius: Theme.launcher.radius

        // Les clics sur le cadre ne le ferment pas.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.launcher.border + Theme.launcher.padding
            spacing: Theme.launcher.spacing

            // Barre de saisie : bouton loupe, prompt, champ ; chaque élément prend toute la hauteur, texte en haut (Rofi).
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: Theme.launcher.itemSpacing

                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: searchGlyph.implicitWidth + 2 * Theme.launcher.searchButtonPaddingH
                    implicitHeight: searchGlyph.implicitHeight + 2 * Theme.launcher.searchButtonPaddingV
                    radius: Math.min(width, height) / 2
                    color: Theme.launcher.searchButton

                    Text {
                        id: searchGlyph
                        x: Theme.launcher.searchButtonPaddingH
                        y: Theme.launcher.searchButtonPaddingV
                        text: Theme.icon.search
                        font.family: Theme.font.icons
                        font.pointSize: Theme.font.launcherSearchIconPt
                        color: Theme.launcher.text
                    }
                }

                // Largeur : une cellule de Hack (0,6 em), l'avance que Pango donne au glyphe ; Qt lui en donne une plus large.
                Text {
                    Layout.fillHeight: true
                    Layout.preferredWidth: hackCell.implicitWidth + 2 * Theme.launcher.promptPadding
                    padding: Theme.launcher.promptPadding
                    text: Theme.icon.launcherPrompt
                    font.family: Theme.font.inlineIcons
                    font.pointSize: Theme.font.launcherPt
                    color: Theme.launcher.prompt

                    Text {
                        id: hackCell
                        visible: false
                        text: "0"
                        font: parent.font
                    }
                }

                // Champ : soulignement de 2 px arrondi aux coins (bordure basse seule, rayon 10 px).
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: input.implicitHeight + 2 * Theme.launcher.entryPadding + Theme.launcher.entryUnderline
                    radius: Theme.launcher.entryRadius
                    color: Theme.launcher.background

                    // Soulignement : bas d'un cadre arrondi de la couleur de bordure, recouvert par le fond remonté de 2 px.
                    Item {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Theme.launcher.entryRadius
                        clip: true

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.parent.height
                            radius: Theme.launcher.entryRadius
                            color: Theme.launcher.entryUnderlineColor
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height - Theme.launcher.entryUnderline
                        radius: Theme.launcher.entryRadius
                        color: Theme.launcher.background
                    }

                    TextInput {
                        id: input
                        anchors {
                            left: parent.left
                            right: launcherClear.visible ? launcherClear.left : parent.right
                            top: parent.top
                            margins: Theme.launcher.entryPadding
                        }
                        clip: true
                        font.family: Theme.font.text
                        font.pointSize: Theme.font.launcherPt
                        color: Theme.launcher.text
                        onTextChanged: root.selected = 0
                        Keys.onPressed: event => event.accepted = root.handleKey(event)

                        Text {
                            visible: input.text === ""
                            text: Theme.launcher.placeholder
                            font: input.font
                            color: Theme.launcher.placeholderColor
                        }
                    }

                    ClearButton {
                        id: launcherClear
                        field: input
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.launcher.entryPadding
                        anchors.verticalCenter: input.verticalCenter
                        font.pointSize: Theme.font.launcherPt
                        normalColor: Theme.launcher.placeholderColor
                        hoverColor: Theme.launcher.text
                    }
                }
            }

            // Liste : une page de lignes entières, la sélection toujours visible (`scroll-method 0`).
            Item {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    id: measure
                    visible: false
                    text: "Ag"
                    font.family: Theme.font.text
                    font.pointSize: Theme.font.launcherPt
                }

                Column {
                    width: parent.width
                    spacing: Theme.launcher.listSpacing

                    // ScriptModel : une application qui reste dans la page garde sa ligne (et son icône chargée) d'une frappe à l'autre.
                    Repeater {
                        model: ScriptModel {
                            values: root.results.slice(root.pageStart, root.pageStart + root.rows)
                            objectProp: "id"
                        }

                        Rectangle {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property bool current: root.pageStart + index === root.selected

                            width: parent.width
                            height: root.rowHeight
                            radius: current ? Theme.launcher.selectedRadius : Theme.launcher.itemRadius
                            color: current ? Theme.launcher.selected : Theme.launcher.background

                            Row {
                                x: Theme.launcher.itemPadding
                                width: parent.width - 2 * Theme.launcher.itemPadding
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.launcher.itemSpacing

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: Theme.launcher.itemIconSize
                                    source: Icons.iconSource(row.modelData.icon)
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    leftPadding: Theme.launcher.itemTextMargin
                                    width: parent.width - Theme.launcher.itemIconSize - Theme.launcher.itemSpacing
                                    text: row.modelData.name
                                    font.family: Theme.font.text
                                    font.pointSize: Theme.font.launcherPt
                                    color: row.current ? Theme.launcher.selectedText : Theme.launcher.text
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: root.select(root.pageStart + row.index)
                                onDoubleClicked: root.accept(false)
                            }
                        }
                    }
                }

                WheelSteps {
                    onStep: direction => root.select(root.selected - direction)
                }
            }
        }
    }
}
