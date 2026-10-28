import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Calendrier de l'horloge (ARCHITECTURE.md § 8.3, THEME.md § 3 « Calendrier ») : remplace le tooltip calendrier de Waybar.
//  - survol de l'horloge : aperçu du mois en cours, fermé quand le pointeur quitte l'horloge ;
//  - clic : calendrier épinglé ; flèches (clic ou clavier) et molette changent de mois, clic sur le titre : retour au mois en cours.
//    Fermeture : Échap, clic n'importe où ailleurs (il atteint aussi ce qui est dessous : fenêtre, module de la barre),
//    ou pointeur resté hors du calendrier et de l'horloge pendant Theme.calendar.autoCloseDelay.
//    Mécanisme (ARCHITECTURE § 8.3) : pendant le survol de l'horloge, sa barre accepte le clavier « à la demande » ; le clic
//    qui épingle lui donne donc le focus (Échap, ←/→). Un clic sur une fenêtre le lui reprend : le calendrier se ferme au plus
//    tard après le délai automatique (pointeur dehors), pas aussitôt : le survol d'une fenêtre la focalise aussi (focus_follows_mouse).
//    Un appui sur une barre le ferme directement (Bar.qml), tout comme le passage du focus à une fenêtre, pointeur sur le calendrier (événement du
//    compositeur : nécessaire après un clic dans le calendrier, que Sway traite comme un clic sur l'espace de travail). À la fermeture, la barre repasse sans clavier et Sway rend
//    le focus à la fenêtre précédente. Un clic sur le fond d'écran traverse `swaybg` et focalise l'espace de travail : il ferme
//    aussi, sauf juste après un clic dans le calendrier (focus déjà sur l'espace) ; [phase 8b] voir WALLPAPERS.md. (Sway retire le focus à une surface « à la demande » à chaque réarrangement des
//    couches : seul un clic le lui donne durablement ; un popup `grabFocus` n'est pas fermé au clic extérieur.)
// Semaine selon la locale du système (dimanche en premier pour en_US, comme Waybar).
Item {
    id: root

    required property Item anchorItem
    property bool hovered: false
    property bool pinned: false
    // Après une fermeture par clic, l'aperçu attend que le pointeur ait quitté l'horloge.
    property bool hoverSuppressed: false

    // Mois affiché : décalage par rapport au mois en cours.
    property int monthOffset: 0

    readonly property Item owner: pinned ? anchorItem : null   // appui sur l'horloge : la barre la laisse fermer le calendrier
    readonly property int ownerButtons: Qt.LeftButton          // clic de l'horloge (TapHandler)

    Connections {
        target: BarState
        function onClosePopups(keep) {
            if (!keep.includes(root))
                root.pinned = false;
        }
    }

    // Focus passé à une fenêtre : fermeture si le pointeur est sur le calendrier ou l'horloge (raccourci clavier). Pointeur dehors :
    // c'est souvent le survol d'une fenêtre qui la focalise (`focus_follows_mouse` de Sway, `follow_mouse` de Hyprland, actifs
    // chez toi) ; le délai de fermeture automatique s'en charge (le calendrier se fermait sinon dès la sortie du pointeur).
    Connections {
        target: Compositor
        function onWindowFocused() {
            if (root.hovered || root.popupHovered)
                root.pinned = false;
        }
    }

    // Clic sur l'horloge.
    function toggle(): void {
        // Épinglé (la barre le laisse ouvert pour l'appui sur l'horloge, `owner`) : ce clic le ferme et bloque l'aperçu.
        if (pinned) {
            pinned = false;
            hoverSuppressed = true;   // pas d'aperçu tant que le pointeur reste sur l'horloge
        } else {
            pinned = true;
        }
    }

    // Le pointeur a quitté l'horloge : l'aperçu peut de nouveau s'afficher.
    onHoveredChanged: {
        if (!hovered)
            hoverSuppressed = false;
    }

    // Pointeur sur le calendrier (le HoverHandler du cadre ne voit pas le survol d'un enfant qui a le sien).
    readonly property bool popupHovered: frameHover.hovered || previousHover.hovered || nextHover.hovered || titleHover.hovered
    readonly property string screenName: anchorItem.QsWindow.window?.screen?.name ?? ""
    readonly property bool wantsKeyboard: pinned || hovered
    readonly property string keyboardScreen: wantsKeyboard ? screenName : ""
    onKeyboardScreenChanged: BarState.claimKeyboard(root, keyboardScreen, false)

    // Barre détruite (écran retiré) calendrier ouvert ou survolé : rien ne doit rester inscrit.
    Component.onDestruction: {
        BarState.setPopupOpen(root, false);
        BarState.claimKeyboard(root, "", false);
    }

    onPinnedChanged: {
        monthOffset = 0;
        BarState.setPopupOpen(root, pinned);
        if (pinned)
            keys.forceActiveFocus();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    readonly property date today: clock.date
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

    // 6 semaines × 7 jours, à partir du premier jour de semaine de la locale avant le 1er du mois.
    readonly property var days: {
        const first = (Qt.locale().firstDayOfWeek % 7);   // Qt : 1 = lundi … 7 = dimanche ; JS : 0 = dimanche
        const start = new Date(month);
        start.setDate(1 - ((month.getDay() - first + 7) % 7));
        return Array.from({ length: 42 }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
    }

    PopupWindow {
        id: popup

        anchor.item: root.anchorItem
        anchor.rect.x: (root.anchorItem.width - width) / 2
        anchor.rect.y: root.anchorItem.height + Theme.bar.pillBorder + Theme.calendar.gap
        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight
        color: "transparent"

        visible: root.pinned || (root.hovered && !root.hoverSuppressed)
        onVisibleChanged: {
            if (!visible)
                root.monthOffset = 0;
        }

        Rectangle {
            id: frame

            implicitWidth: content.implicitWidth + 2 * Theme.calendar.padding
            implicitHeight: content.implicitHeight + 2 * Theme.calendar.padding
            radius: Theme.calendar.radius
            color: Theme.calendar.background
            border.width: Theme.calendar.border
            border.color: Theme.calendar.borderColor

            HoverHandler {
                id: frameHover
            }

            WheelSteps {
                enabled: root.pinned
                onStep: direction => root.monthOffset -= direction
            }

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: Theme.calendar.spacing

                // Titre « 2026 October » (format du tooltip Waybar), flèches visibles quand le calendrier est épinglé.
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        visible: root.pinned
                        text: Theme.icon.previous
                        font.family: Theme.font.icons
                        font.pixelSize: Theme.calendar.fontSize
                        color: previousHover.hovered ? Theme.calendar.title : Theme.calendar.text
                        HoverHandler {
                            id: previousHover
                        }
                        TapHandler {
                            onTapped: root.monthOffset--
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.month.toLocaleDateString(Qt.locale(), "yyyy MMMM")
                        font.family: Theme.font.text
                        font.pixelSize: Theme.calendar.titleSize
                        color: Theme.calendar.title
                        HoverHandler {
                            id: titleHover
                        }
                        TapHandler {
                            enabled: root.pinned
                            onTapped: root.monthOffset = 0
                        }
                    }

                    Text {
                        visible: root.pinned
                        text: Theme.icon.next
                        font.family: Theme.font.icons
                        font.pixelSize: Theme.calendar.fontSize
                        color: nextHover.hovered ? Theme.calendar.title : Theme.calendar.text
                        HoverHandler {
                            id: nextHover
                        }
                        TapHandler {
                            onTapped: root.monthOffset++
                        }
                    }
                }

                GridLayout {
                    columns: 7
                    rowSpacing: 0
                    columnSpacing: 0

                    // Jours de la semaine, abrégés à deux lettres comme le calendrier GTK de Waybar.
                    Repeater {
                        model: 7
                        Text {
                            required property int index
                            Layout.preferredWidth: Theme.calendar.cell
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().dayName((Qt.locale().firstDayOfWeek + index) % 7, Locale.ShortFormat).slice(0, 2)
                            font.family: Theme.font.text
                            font.pixelSize: Theme.calendar.fontSize
                            color: Theme.calendar.weekday
                        }
                    }

                    Repeater {
                        model: root.days
                        Item {
                            id: day

                            required property date modelData
                            readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                            readonly property bool isToday: modelData.toDateString() === root.today.toDateString()

                            Layout.preferredWidth: Theme.calendar.cell
                            Layout.preferredHeight: Theme.calendar.cell

                            Rectangle {
                                anchors.fill: parent
                                visible: day.isToday
                                radius: Theme.calendar.todayRadius
                                color: Theme.calendar.today
                            }

                            Text {
                                anchors.centerIn: parent
                                text: day.modelData.getDate()
                                font.family: Theme.font.text
                                font.pixelSize: Theme.calendar.fontSize
                                font.bold: day.isToday
                                color: day.isToday ? Theme.calendar.todayText : day.inMonth ? Theme.calendar.text : Theme.calendar.otherMonth
                            }
                        }
                    }
                }
            }
        }
    }

    // Fermeture automatique : pointeur hors du calendrier et de l'horloge pendant un moment.
    Timer {
        interval: Theme.calendar.autoCloseDelay
        running: root.pinned && !root.hovered && !root.popupHovered
        onTriggered: root.pinned = false
    }

    // Reçoit le clavier de la barre quand le calendrier est épinglé ; la perte du focus (clic sur une fenêtre) le ferme.
    Item {
        id: keys

        Keys.onEscapePressed: root.pinned = false
        Keys.onLeftPressed: root.monthOffset--
        Keys.onRightPressed: root.monthOffset++
        onActiveFocusChanged: {
            // Un clic dans le calendrier retire aussi le focus à la barre : il ne doit pas le fermer. Pointeur hors du calendrier et
            // de l'horloge (fenêtre focalisée au survol, clic sur une fenêtre) : fermeture par le délai automatique.
            if (!activeFocus && root.pinned && root.hovered && !root.popupHovered)
                root.pinned = false;
        }
    }
}
