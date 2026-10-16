import QtQuick
import qs.config
import qs.services

// Curseur de volume (INVENTORY.md § 1, `pulseaudio/slider`) : rail `crust`, partie remplie `text`, bouton `surface2`.
// Clic / glisser : volume 0–100 ; molette ±5 % ; clic droit : pavucontrol.
// Mesuré sur la référence : le centre du bouton suit la valeur sur toute la longueur du rail (il déborde aux extrémités).
Item {
    id: root

    readonly property bool shown: Audio.ready

    implicitWidth: 2 * Theme.slider.padding + Theme.slider.minWidth
    implicitHeight: Theme.slider.knobSize

    Rectangle {
        id: trough
        x: Theme.slider.padding
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - 2 * Theme.slider.padding
        height: Theme.slider.troughHeight
        radius: Theme.slider.troughRadius
        color: Theme.slider.trough

        Rectangle {
            width: Math.min(1, Audio.volume) * trough.width
            height: parent.height
            radius: Theme.slider.troughRadius
            color: Theme.slider.fill
        }

        Rectangle {
            x: Math.min(1, Audio.volume) * trough.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.slider.knobSize
            height: Theme.slider.knobSize
            radius: width / 2
            color: Theme.slider.knob
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        function set(x: real): void {
            Audio.setVolume(Math.round(100 * (x - trough.x) / trough.width) / 100);
        }
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton)
                Audio.openMixer();
            else
                set(mouse.x);
        }
        onPositionChanged: mouse => {
            if (pressedButtons & Qt.LeftButton)
                set(mouse.x);
        }
    }

    WheelSteps {
        onStep: direction => Audio.step(5 * direction)
    }
}
