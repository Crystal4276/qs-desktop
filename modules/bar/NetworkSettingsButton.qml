import QtQuick
import QtQuick.Layouts
import qs.services

// Pied des panneaux réseau et Wi-Fi : « Network settings… » à droite, ferme le panneau et ouvre l'éditeur de connexions
// (`nm-connection-editor`) ; seulement si NetworkManager gère le réseau.
RowLayout {
    required property Panel panel

    visible: Network.managed
    Layout.fillWidth: true

    Item {
        Layout.fillWidth: true
    }

    PanelButton {
        text: "Network settings…"
        onClicked: {
            parent.panel.close();
            Network.openEditor();
        }
    }
}
