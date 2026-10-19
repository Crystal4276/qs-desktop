import Quickshell.Io

// Lecture par une commande (Network : nmcli du Wi-Fi) : `request()` la lance, ou la refait à la fin de celle en cours, sans
// quoi la lecture en cours, faite avant un changement (autre réseau, réseaux apparus), resterait affichée.
Process {
    id: root

    property bool again: false

    function request(): void {
        if (running)
            again = true;
        else
            running = true;
    }

    onExited: {
        if (again) {
            again = false;
            running = true;
        }
    }
}
