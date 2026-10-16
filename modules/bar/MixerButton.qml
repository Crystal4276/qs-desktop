import QtQuick
import QtQuick.Layouts
import qs.services

// « Advanced… » aligné à droite : ouvre pavucontrol (panneau audio, panneau de réglages). `opened` : le panneau se ferme.
RowLayout {
    id: root

    signal opened

    Layout.fillWidth: true

    Item {
        Layout.fillWidth: true
    }

    PanelButton {
        text: "Advanced…"
        onClicked: {
            root.opened();
            Audio.openMixer();
        }
    }
}
