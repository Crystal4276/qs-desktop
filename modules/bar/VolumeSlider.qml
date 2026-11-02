import QtQuick
import qs.config

// Curseur de volume (THEME.md § 3) : rail `crust`, partie remplie `text`, bouton `surface2`. Barre (Slider.qml) et panneau audio.
// Clic / glisser : 0–100 % ; molette ±5 %. Le centre du bouton suit la valeur sur toute la longueur du rail (il déborde aux
// extrémités, mesuré sur la référence) : `inset` réserve la place du débordement.
Item {
    id: root

    property real value: 0
    property int inset: Theme.slider.padding
    signal moved(real value)

    implicitHeight: Theme.slider.knobSize

    function emit(v: real): void {
        root.moved(Math.max(0, Math.min(1, Math.round(100 * v) / 100)));
    }

    // Molette, clavier : plafond à 100 %, sauf volume déjà au-dessus (réglé ailleurs), qui ne retombe pas à 100 % d'un cran (Audio.step).
    function step(points: int): void {
        root.moved(Math.max(0, Math.min(Math.max(1, value), Math.round(100 * value + points) / 100)));
    }

    Rectangle {
        id: trough
        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - 2 * root.inset
        height: Theme.slider.troughHeight
        radius: Theme.slider.troughRadius
        color: Theme.slider.trough

        Rectangle {
            width: Math.min(1, root.value) * trough.width
            height: parent.height
            radius: Theme.slider.troughRadius
            color: Theme.slider.fill
        }

        Rectangle {
            x: Math.min(1, root.value) * trough.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.slider.knobSize
            height: Theme.slider.knobSize
            radius: width / 2
            color: Theme.slider.knob
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => root.emit((mouse.x - trough.x) / trough.width)
        onPositionChanged: mouse => {
            if (pressed)
                root.emit((mouse.x - trough.x) / trough.width);
        }
    }

    // Clavier : Gauche / Droite ±5 % (comme la molette) ; liseré quand le curseur est choisi.
    activeFocusOnTab: true
    Keys.onLeftPressed: root.step(-5)
    Keys.onRightPressed: root.step(5)

    Rectangle {
        anchors.fill: parent
        visible: root.activeFocus
        color: "transparent"
        radius: height / 2
        border.width: Theme.panel.border
        border.color: Theme.panel.focusRing
    }

    WheelSteps {
        onStep: direction => root.step(5 * direction)
    }
}
