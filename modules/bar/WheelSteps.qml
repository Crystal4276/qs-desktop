import QtQuick

// Molette en crans : un cran de souris vaut 120 (convention Qt) ; les petits pas (pavé tactile, molette haute résolution)
// s'additionnent jusqu'à un cran, comme les événements discrets que GTK donnait à Waybar. Un seul axe par gestionnaire
// (`orientation`, vertical par défaut).
WheelHandler {
    id: root

    // +1 vers le haut (ou la gauche), -1 vers le bas (ou la droite).
    signal step(int direction)

    property real accumulated: 0

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        accumulated += orientation === Qt.Horizontal ? event.angleDelta.x : event.angleDelta.y;
        while (Math.abs(accumulated) >= 120) {
            const direction = accumulated > 0 ? 1 : -1;
            accumulated -= 120 * direction;
            root.step(direction);
        }
    }
}
