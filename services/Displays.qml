pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// HDR et VRR des écrans compatibles (bascules du panneau de réglages, ARCHITECTURE § 10.1.4).
// Une bascule agit sur tous les écrans compatibles à la fois, comme ton `$mod+d` (DP-1 et DP-3) ; elle est « activée » quand
// tous le sont. Écran non compatible : ignoré ; aucun écran compatible : bascule masquée.
Singleton {
    id: root

    // De gauche à droite.
    readonly property var hdrOutputs: Compositor.outputs.filter(o => o.hdrCapable).sort((a, b) => a.x - b.x)
    readonly property var vrrOutputs: Compositor.outputs.filter(o => o.vrrCapable).sort((a, b) => a.x - b.x)
    readonly property bool hdr: hdrOutputs.length > 0 && hdrOutputs.every(o => o.hdr)
    readonly property bool vrr: vrrOutputs.length > 0 && vrrOutputs.every(o => o.vrr)

    function toggleHdr(): void {
        Compositor.setHdr(hdrOutputs.map(o => o.name), !hdr);
    }

    function toggleVrr(): void {
        Compositor.setVrr(vrrOutputs.map(o => o.name), !vrr);
    }

    // `$mod+d` (phase 10) : `qs ipc call display toggleHdr`.
    IpcHandler {
        target: "display"

        function toggleHdr(): void {
            root.toggleHdr();
        }

        function toggleVrr(): void {
            root.toggleVrr();
        }
    }
}
