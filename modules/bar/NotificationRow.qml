import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// Ligne de l'historique du centre de notifications (refaite le 2026-10-20, ta demande ; disposition de KDE et GNOME) : l'icône
// dit déjà l'application, le contenu passe donc en premier. En-tête en texte secondaire : titre de la notification (expéditeur,
// numéro…) sans le nom de l'application qu'il répète parfois (« whatsdesk - … ») ; le nom de l'application s'y ajoute si
// l'icône ne la montre pas (avatar, aucune icône). Heure relative à droite (comme KDE), croix.
// Dessous, le corps en `text` sur 2 lignes (même taille que l'en-tête, la couleur fait la différence) ; un clic déplie jusqu'à
// 6 lignes (comme GNOME). Sans corps : le titre devient le texte principal, et l'application l'en-tête. Non vue : en-tête en
// `green`.
Rectangle {
    id: root

    required property var entry   // élément de Notifs.history
    property real now: Date.now()

    property bool expanded: false
    readonly property bool expandable: expanded || bodyText.truncated

    // Texte simple (balises retirées, entités courantes décodées), sauts de ligne gardés.
    function plain(text: string): string {
        return text.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "").replace(/[ \t]+/g, " ")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&amp;/g, "&").trim();
    }

    // Titre sans l'application en préfixe (« whatsdesk - Alice » → « Alice ») ; vide s'il ne dit que l'application.
    function title(summary: string, app: string): string {
        const s = plain(summary).replace(/\s+/g, " ");
        if (app === "" || s.toLowerCase() === app.toLowerCase())
            return app === "" ? s : "";
        const prefix = s.slice(0, app.length).toLowerCase() === app.toLowerCase() ? s.slice(app.length).match(/^\s*[-–—:·|]\s*(.*)$/) : null;
        return prefix ? prefix[1] : s;
    }

    // Heure relative, comme KDE (HeadingButtons.qml) : « now », « 5 min ago », heure du jour, « Yesterday », puis la date.
    function age(timestamp: real, now: real): string {
        const t = new Date(timestamp), minutes = Math.floor((now - timestamp) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes} min ago`;
        const today = new Date(now);
        today.setHours(0, 0, 0, 0);
        if (timestamp >= today.getTime())
            return Qt.formatTime(t, "HH:mm");
        if (timestamp >= today.getTime() - 86400000)
            return "Yesterday";
        return Qt.formatDate(t, "d MMM");
    }

    readonly property string titleText: title(entry.summary ?? "", entry.appName ?? "")
    readonly property string bodyPlain: plain(entry.body ?? "")
    // L'icône ne dit pas l'application (avatar envoyé en données, ou pas d'icône) : son nom s'ajoute à l'en-tête.
    readonly property bool iconNamesApp: (entry.icon ?? "") !== "" && !Notifs.isDataImage(entry.icon)
    readonly property string headerText: bodyPlain === "" || titleText === "" ? entry.appName
        : iconNamesApp ? titleText : `${titleText} · ${entry.appName}`
    readonly property string mainText: bodyPlain !== "" ? bodyPlain : titleText

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 2 * Theme.panel.rowPadding
    radius: Theme.panel.rowRadius
    color: root.expandable && hover.hovered ? Theme.panel.rowHover : "transparent"

    // Clavier (Tab, flèches) : Entrée ou Espace déplient, comme le clic ; liseré quand la ligne est choisie.
    activeFocusOnTab: expandable
    border.width: activeFocus ? Theme.panel.border : 0
    border.color: Theme.panel.focusRing
    Keys.onReturnPressed: expanded = !expanded
    Keys.onEnterPressed: expanded = !expanded
    Keys.onSpacePressed: expanded = !expanded

    HoverHandler {
        id: hover
    }

    // Sous le contenu : la croix consomme ses propres clics.
    MouseArea {
        anchors.fill: parent
        enabled: root.expandable
        onClicked: root.expanded = !root.expanded
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.panel.rowPadding
        }
        spacing: Theme.panel.spacing

        IconImage {
            Layout.alignment: Qt.AlignTop
            implicitSize: Theme.notificationCentre.iconSize
            // Sans icône : icône générique (alignement).
            readonly property string icon: root.entry.icon || "preferences-desktop-notification"
            source: icon.startsWith("image:") || icon.startsWith("file:") ? icon : `image://icon/${icon}`
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.panel.spacing

                PanelSection {
                    text: root.headerText
                    color: root.entry.seen ? Theme.panel.secondaryText : Theme.panel.accent
                }

                PanelSection {
                    Layout.fillWidth: false
                    text: root.age(root.entry.timestamp, root.now)
                }

                // Croix : retire la notification de l'historique.
                GlyphButton {
                    size: Theme.panel.iconSize
                    glyphSize: Theme.panel.smallFontSize
                    glyph: Theme.icon.close
                    glyphColor: Theme.panel.secondaryText
                    glyphHoverColor: Theme.panel.text
                    hoverColor: Theme.panel.buttonHover
                    onClicked: Notifs.removeHistory(root.entry.key)
                }
            }

            Text {
                id: bodyText
                Layout.fillWidth: true
                visible: text !== ""
                text: root.mainText
                textFormat: Text.PlainText
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize   // ton choix du 2026-10-20 (20 px essayé)
                color: Theme.panel.text
                wrapMode: Text.Wrap
                maximumLineCount: root.expanded ? Theme.notificationCentre.expandedLines : Theme.notificationCentre.bodyLines
                elide: Text.ElideRight
            }
        }
    }
}
