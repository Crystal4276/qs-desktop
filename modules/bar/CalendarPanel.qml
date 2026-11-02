import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

// Calendrier de l'horloge (ARCHITECTURE.md § 8.3, THEME.md § 3 « Calendrier ») : remplace le tooltip calendrier de Waybar. Une carte
// comme celles du tray (Panel.qml) : aperçu du mois en cours au survol, épinglée au clic, mêmes fermetures.
// Épinglée : flèches (clic ou clavier) et molette changent de mois, clic sur le titre : retour au mois en cours.
// Semaine selon la locale du système (dimanche en premier pour en_US, comme Waybar).
Panel {
    id: root

    // Mois affiché : décalage par rapport au mois en cours.
    property int monthOffset: 0

    frameWidth: Math.ceil(frameItem.bodyWidth) + 2 * Theme.panel.padding
    initialFocus: content

    onPinnedChanged: monthOffset = 0

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

    ColumnLayout {
        id: content

        spacing: Theme.calendar.spacing
        Keys.onLeftPressed: root.monthOffset--
        Keys.onRightPressed: root.monthOffset++

        WheelSteps {
            parent: root.frameItem   // toute la carte, marges comprises
            enabled: root.pinned
            onStep: direction => root.monthOffset -= direction
        }

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
