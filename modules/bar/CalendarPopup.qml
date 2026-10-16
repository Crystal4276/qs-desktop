import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config

// Calendrier de l'horloge (ARCHITECTURE.md § 8.3, THEME.md § 3 « Calendrier ») : remplace le tooltip calendrier de Waybar.
//  - survol de l'horloge : aperçu du mois en cours, fermé quand le pointeur quitte l'horloge ;
//  - clic : calendrier épinglé ; flèches (clic ou clavier) et molette changent de mois, clic sur le titre : retour au mois en cours.
//    Fermeture : Échap, ou clic n'importe où ailleurs (horloge comprise), capté par une couche transparente sur chaque écran.
//    (Un popup `grabFocus` ne convient pas : Sway ne le ferme pas au clic extérieur, et il bloque le clic sur l'horloge.)
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

    onHoveredChanged: {
        if (!hovered)
            hoverSuppressed = false;
    }
    onPinnedChanged: {
        monthOffset = 0;
        if (!pinned)
            hoverSuppressed = true;
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

    // Calendrier épinglé : couche transparente sur chaque écran, au-dessus des fenêtres et de la barre (le popup reste
    // au-dessus d'elle) ; elle prend le clavier pour Échap et les flèches.
    Variants {
        model: root.pinned ? Quickshell.screens : []

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            WlrLayershell.namespace: "quickshell-dismiss"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                focus: true
                onPressed: root.pinned = false
                Keys.onEscapePressed: root.pinned = false
                Keys.onLeftPressed: root.monthOffset--
                Keys.onRightPressed: root.monthOffset++
            }
        }
    }
}
