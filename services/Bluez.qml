pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth (module natif du tray, remplace blueman ; ARCHITECTURE R6, § 10.2).
// État, connexion, oubli : Quickshell.Bluetooth (BlueZ). Appairage : Quickshell n'a pas d'agent BlueZ ; `bluetoothctl` est lancé
// le temps d'un appairage demandé ici, avec son propre agent dans la même session que `pair` : BlueZ utilise cet agent sans
// toucher à l'agent par défaut. Chaque demande (code à confirmer, PIN à saisir…) est montrée dans le panneau ; jamais d'acceptation
// automatique. Les messages de `bluetoothctl` 5.x reconnus sont regroupés dans `onAgentLine`.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: Bluetooth.devices.values
    readonly property var paired: devices.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Appareils à proximité non appairés ; sans nom, BlueZ donne leur adresse (« 68-8B-F1-… ») : ils sont masqués.
    readonly property var others: devices.filter(d => !d.paired && d.name !== "" && d.name.replace(/-/g, ":") !== d.address)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property bool anyConnected: devices.some(d => d.connected)

    // Icône du tray, noms du thème Papirus-Dark utilisés par blueman : éteint, appareil connecté, allumé.
    readonly property string icon: !enabled ? "blueman-tray-disabled" : anyConnected ? "blueman-tray-active" : "blueman-tray"

    function setEnabled(value: bool): void {
        if (adapter)
            adapter.enabled = value;
    }

    // Recherche d'appareils tant que le panneau est ouvert et l'adaptateur allumé.
    property bool scanning: false
    Binding {
        when: root.adapter !== null && root.enabled
        target: root.adapter
        property: "discovering"
        value: root.scanning
    }

    // --- Appairage ---

    property BluetoothDevice pairingDevice: null
    // Adresse de l'appareil en cours d'appairage : gardée même si le panneau se ferme (cancelPairing vide pairingDevice)
    // alors que bluetoothctl annonce encore la réussite.
    property string pairingAddress: ""
    // Demande en cours : "" | "confirm" (code à vérifier) | "authorize" | "pin" | "passkey" (à saisir) | "display" (code à taper
    // sur l'appareil) ; `request` : texte du code affiché.
    property string requestType: ""
    property string request: ""
    property string pairingError: ""

    function pair(device: BluetoothDevice): void {
        if (agent.running)
            return;
        pairingDevice = device;
        pairingAddress = device.address;
        requestType = "";
        request = "";
        pairingError = "";
        agentBuffer = "";
        agent.running = true;
        agent.write("agent KeyboardDisplay\n");
        agent.write(`pair ${device.address}\n`);
    }

    // Réponse à une demande : oui / non, ou code saisi.
    function answer(value: string): void {
        if (!agent.running || requestType === "")
            return;
        agent.write(`${value}\n`);
        requestType = "";
        request = "";
    }

    function cancelPairing(): void {
        if (agent.running) {
            if (requestType === "confirm" || requestType === "authorize")
                agent.write("no\n");
            agent.write(`cancel-pairing ${pairingDevice?.address ?? ""}\n`);
            agent.write("quit\n");
        }
        pairingDevice = null;
        requestType = "";
    }

    // Sortie de bluetoothctl : morceaux bruts (les questions de l'agent n'ont pas de saut de ligne final) ; lignes complètes
    // traitées une à une, reste examiné s'il contient une question.
    property string agentBuffer: ""
    function onAgentOutput(chunk: string): void {
        const lines = (agentBuffer + chunk).split("\n");
        agentBuffer = lines.pop();
        for (const l of lines)
            onAgentLine(l);
        if (/\(yes\/no\)|Enter PIN code|Enter passkey/i.test(agentBuffer)) {
            onAgentLine(agentBuffer);
            agentBuffer = "";
        }
    }

    function onAgentLine(raw: string): void {
        // Sans couleurs ni invite (« [bluetooth]# »). Seules les lignes de l'agent (« [agent] … ») et les résultats de `pair`
        // en début de ligne sont lus : les lignes [NEW] / [CHG] / [DEL] portent les noms des appareils voisins, qu'un appareil
        // pourrait choisir pour imiter une question ou un résultat (« Pairing successful »…) — revue de code.
        const line = raw.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\r/g, "").replace(/^(\[(?!agent\])[^\]]*\][#>]\s*)+/, "").trim();
        if (/^\[(NEW|CHG|DEL)\]/.test(line))
            return;
        const agentLine = /^\[agent\][#>]?\s/.test(line);
        let m;
        if (agentLine && (m = line.match(/Confirm passkey (\d+)/i))) {
            requestType = "confirm";
            request = m[1];
        } else if (agentLine && line.match(/Authorize service|Accept pairing/i)) {
            requestType = "authorize";
            request = "";
        } else if (agentLine && line.match(/Enter PIN code/i)) {
            requestType = "pin";
        } else if (agentLine && line.match(/Enter passkey/i)) {
            requestType = "passkey";
        } else if (agentLine && (m = line.match(/(?:Passkey|PIN code):\s*(\d+)/i))) {
            requestType = "display";
            request = m[1];
        } else if (/^Pairing successful$/i.test(line)) {
            // Reconnexion automatique, comme blueman ; l'appareil est retrouvé par son adresse si le panneau a été fermé entre-temps.
            const device = pairingDevice ?? Bluetooth.devices.values.find(d => d.address === pairingAddress);
            if (device)
                device.trusted = true;
            if (agent.running) {
                agent.write(`connect ${pairingAddress}\n`);
                agent.write("quit\n");
            }
            requestType = "";
        } else if ((m = line.match(/^Failed to pair: (.*)$/i))) {
            pairingError = m[1].replace(/^org\.bluez\.Error\./, "");
            requestType = "";
            agent.write("quit\n");
        }
    }

    Process {
        id: agent
        command: ["bluetoothctl"]
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: chunk => root.onAgentOutput(chunk)
        }
        onExited: {
            root.requestType = "";
            if (root.pairingError === "")
                root.pairingDevice = null;
        }
    }
}
