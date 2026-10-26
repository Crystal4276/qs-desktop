pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Bluetooth (module natif du tray, remplace blueman ; ARCHITECTURE R6, § 10.2).
// État, connexion, oubli, nom : Quickshell.Bluetooth (BlueZ). Appairage : Quickshell n'a pas d'agent BlueZ ; `bluetoothctl` est
// lancé le temps d'un appairage demandé ici, avec son propre agent dans la même session que `pair` : BlueZ utilise cet agent sans
// toucher à l'agent par défaut. Chaque demande (code à confirmer, PIN à saisir…) est montrée dans le panneau ; jamais d'acceptation
// automatique. Les messages de `bluetoothctl` 5.x reconnus sont regroupés dans `onAgentLine`.
// Repris de blueman (ta demande du 2026-10-26, ARCHITECTURE § 10.2.1) : notifications de connexion avec la batterie, reconnexion
// automatique toutes les 60 s, profil audio des casques (`pw-dump` / `wpctl`) ; alerte de batterie faible (GNOME).
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
    // Manette connectée : la veille des écrans est suspendue (Bar.qml), comme le module GameControllerWakelock de blueman.
    readonly property bool gamepadConnected: devices.some(d => d.connected && d.icon === "input-gaming")
    // Adaptateur qui s'allume ou s'éteint, appareil qui se connecte, se déconnecte ou s'appaire : icône du tray animée (GNOME, KDE).
    readonly property bool busy: adapter?.state === BluetoothAdapterState.Enabling || adapter?.state === BluetoothAdapterState.Disabling
        || devices.some(d => isBusy(d))

    // Icône du tray, noms du thème Papirus-Dark utilisés par blueman : éteint, appareil connecté, allumé.
    readonly property string icon: !enabled ? "blueman-tray-disabled" : anyConnected ? "blueman-tray-active" : "blueman-tray"

    function isBusy(device: BluetoothDevice): bool {
        return device.pairing || device.state === BluetoothDeviceState.Disconnecting || isConnecting(device);
    }

    // Connexion visible : pas une tentative de la reconnexion automatique (silencieuse, comme blueman : jusqu'à 25 s chaque minute
    // pour une manette éteinte), sauf si elle est aussi demandée depuis le panneau.
    function isConnecting(device: BluetoothDevice): bool {
        return device.state === BluetoothDeviceState.Connecting && (!autoAttempts[device.address] || !!requested[device.address]);
    }

    // Type d'appareil, lu dans l'icône que BlueZ déduit de sa classe (sous-titre des lignes, comme KDE).
    readonly property var typeNames: ({
        "audio-card": "Audio device",
        "audio-headphones": "Headphones",
        "audio-headset": "Headset",
        "camera-photo": "Camera",
        "camera-video": "Video camera",
        "computer": "Computer",
        "input-gaming": "Gamepad",
        "input-keyboard": "Keyboard",
        "input-mouse": "Mouse",
        "input-tablet": "Tablet",
        "modem": "Modem",
        "multimedia-player": "Media player",
        "network-wireless": "Network",
        "phone": "Phone",
        "printer": "Printer",
        "scanner": "Scanner",
        "video-display": "Display"
    })

    function typeName(device: BluetoothDevice): string {
        return typeNames[device?.icon ?? ""] ?? "";
    }

    function batteryPercent(device: BluetoothDevice): int {
        return Math.round(device.battery * 100);   // battery : fraction 0–1
    }

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

    // --- Connexion ---

    // Connexions demandées depuis le panneau (adresse → vrai) et celles qui ont échoué : « Connection failed » sur la ligne (KDE)
    // jusqu'à la tentative suivante. Les tentatives de la reconnexion automatique (`autoAttempts`) n'y entrent pas.
    property var requested: ({})
    property var failed: ({})
    property var autoAttempts: ({})

    function withFlag(map: var, address: string, value: bool): var {
        if (!!map[address] === value)
            return map;
        const copy = Object.assign({}, map);
        if (value)
            copy[address] = true;
        else
            delete copy[address];
        return copy;
    }

    function connectDevice(device: BluetoothDevice): void {
        requested = withFlag(requested, device.address, true);
        failed = withFlag(failed, device.address, false);
        device.connect();
    }

    function disconnectDevice(device: BluetoothDevice): void {
        failed = withFlag(failed, device.address, false);
        device.disconnect();
    }

    // Oublié : retiré aussi de la reconnexion automatique (sinon reconnecté sans le demander s'il est de nouveau appairé).
    function forget(device: BluetoothDevice): void {
        setAutoConnect(device, false);
        failed = withFlag(failed, device.address, false);
        device.forget();
    }

    // Nouveau nom (alias BlueZ) ; vide : nom donné par l'appareil.
    function rename(device: BluetoothDevice, name: string): void {
        device.name = name.trim();
    }

    // --- Reconnexion automatique (module AutoConnect de blueman) ---

    // Adresses des appareils à reconnecter, gardées dans l'état de Quickshell ; reprises de blueman au premier lancement.
    readonly property var autoConnect: autoConnectFile.addresses

    function isAutoConnect(device: BluetoothDevice): bool {
        return autoConnect.includes(device.address);
    }

    function setAutoConnect(device: BluetoothDevice, on: bool): void {
        const others = autoConnect.filter(a => a !== device.address);
        autoConnectFile.addresses = on ? [...others, device.address] : others;
    }

    FileView {
        path: Quickshell.statePath("bluetooth.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: bluemanImport.running = true

        JsonAdapter {
            id: autoConnectFile
            property list<string> addresses: []
        }
    }

    // Réglage de blueman : [('F4:6A:…', '00000000-…'), …] ; seules les adresses sont reprises (blueman y connecte tous les profils).
    Process {
        id: bluemanImport
        command: ["gsettings", "get", "org.blueman.plugins.autoconnect", "services"]
        stdout: StdioCollector {
            onStreamFinished: autoConnectFile.addresses = [...new Set((text.match(/([0-9A-F]{2}:){5}[0-9A-F]{2}/gi) ?? [])
                .map(a => a.toUpperCase()))]
        }
    }

    // Comme blueman : toutes les 60 s, adaptateur allumé, appareils de la liste appairés et déconnectés.
    Timer {
        interval: 60000
        repeat: true
        running: root.enabled && root.autoConnect.length > 0
        onTriggered: {
            for (const device of root.devices) {
                if (root.isAutoConnect(device) && device.paired && device.state === BluetoothDeviceState.Disconnected) {
                    root.autoAttempts = root.withFlag(root.autoAttempts, device.address, true);
                    device.connect();
                }
            }
        }
    }

    // --- Profil audio d'un casque (module PulseAudioProfile de blueman) ---

    // Carte PipeWire de chaque appareil audio connecté (adresse → { id, active, profiles: [{ index, description }] }), lue à la
    // demande (détails dépliés) : Quickshell.Services.Pipewire n'expose pas les profils. Relue quand les nœuds PipeWire de
    // l'appareil changent (`audioNodes`) : WirePlumber crée la carte après la connexion, et recrée les nœuds après un changement
    // de profil, une fois le profil actif.
    function audioNodes(device: BluetoothDevice): string {
        const key = `.${device.address.replace(/:/g, "_")}`;
        return Pipewire.nodes.values.filter(n => n.name.startsWith("bluez_") && n.name.includes(key)).map(n => n.id).join(",");
    }

    property var audioCards: ({})

    function setAudioCard(address: string, card: var): void {
        const cards = Object.assign({}, audioCards);
        if (card)
            cards[address] = card;
        else
            delete cards[address];
        audioCards = cards;
    }

    function readAudioCard(device: BluetoothDevice): void {
        if (device?.connected)
            cardReader.createObject(root, { address: device.address }).running = true;
    }

    function setAudioProfile(device: BluetoothDevice, index: int): void {
        const card = audioCards[device.address];
        if (card)
            profileSetter.createObject(root, { device: device, command: ["wpctl", "set-profile", String(card.id), String(index)] }).running = true;
    }

    Component {
        id: cardReader

        Process {
            id: reader

            property string address

            command: ["pw-dump", `bluez_card.${address.replace(/:/g, "_")}`]
            stdout: StdioCollector {
                onStreamFinished: {
                    let card = null;
                    try {
                        const object = JSON.parse(text).find(o => o.type === "PipeWire:Interface:Device");
                        const params = object?.info?.params ?? {};
                        const profiles = (params.EnumProfile ?? []).filter(p => p.name !== "off" && p.available !== "no")
                            .map(p => ({ index: p.index, description: p.description }));
                        if (object && profiles.length > 0)
                            card = { id: object.id, active: params.Profile?.[0]?.index ?? -1, profiles: profiles };
                    } catch (e) {}
                    root.setAudioCard(reader.address, card);
                    reader.destroy();
                }
            }
        }
    }

    Component {
        id: profileSetter

        Process {
            property BluetoothDevice device
            onExited: {
                root.readAudioCard(device);
                destroy();
            }
        }
    }

    // Notification envoyée par `notify-send --print-id` ; `done(id)` reçoit son identifiant.
    Component {
        id: idSender

        Process {
            id: idProcess

            signal done(string id)
            stdout: StdioCollector {
                onStreamFinished: {
                    idProcess.done(text.trim());
                    idProcess.destroy();
                }
            }
        }
    }

    // --- Suivi de chaque appareil appairé : échecs, notifications, batterie ---

    Variants {
        model: root.paired

        Scope {
            id: watch

            required property BluetoothDevice modelData
            property int lastState: modelData?.state ?? BluetoothDeviceState.Disconnected
            // Notification « Connected » en attente de la batterie (BlueZ la publie après la connexion) : remplacée par
            // « Connected 80% », comme ConnectionNotifier de blueman.
            property string notificationId: ""
            property int sent: 0   // notifications « Connected » envoyées : seul l'identifiant de la dernière est gardé
            property bool awaitingBattery: false
            property int batteryAlerted: 101   // plus bas seuil déjà signalé ; réarmé quand la batterie remonte

            function connectedBody(): string {
                return modelData.batteryAvailable ? `Connected ${root.batteryPercent(modelData)}%` : "Connected";
            }

            function batteryArrived(): void {
                if (!awaitingBattery || notificationId === "" || !modelData.batteryAvailable)
                    return;
                awaitingBattery = false;
                Quickshell.execDetached(["notify-send", "--app-name=Bluetooth", "--transient", `--replace-id=${notificationId}`, "--icon=battery",
                    modelData.name, connectedBody()]);
            }

            // Seuils de la batterie du laptop : une notification par seuil franchi (GNOME), réarmée quand la batterie remonte.
            function checkBattery(): void {
                if (!modelData.connected || !modelData.batteryAvailable)
                    return;
                const percent = root.batteryPercent(modelData);
                const level = Battery.levelOf(percent);
                if (level === 101)
                    batteryAlerted = 101;
                if (level >= batteryAlerted)
                    return;
                batteryAlerted = level;
                Battery.notifyLow(modelData.name, percent, level);
            }

            Connections {
                target: watch.modelData

                function onStateChanged(): void {
                    const device = watch.modelData;
                    if (watch.lastState === BluetoothDeviceState.Connecting && device.state === BluetoothDeviceState.Disconnected
                        && root.requested[device.address])
                        root.failed = root.withFlag(root.failed, device.address, true);
                    if (device.state !== BluetoothDeviceState.Connecting) {
                        root.requested = root.withFlag(root.requested, device.address, false);
                        root.autoAttempts = root.withFlag(root.autoAttempts, device.address, false);
                    }
                    watch.lastState = device.state;
                }

                function onConnectedChanged(): void {
                    const device = watch.modelData;
                    if (device.connected) {
                        root.failed = root.withFlag(root.failed, device.address, false);
                        watch.notificationId = "";
                        watch.awaitingBattery = !device.batteryAvailable;
                        const sent = ++watch.sent;
                        const process = idSender.createObject(watch, { command: ["notify-send", "--print-id", "--app-name=Bluetooth",
                            "--transient", `--icon=${device.icon || "bluetooth"}`, device.name, watch.connectedBody()] });
                        process.done.connect(id => {
                            if (sent !== watch.sent)
                                return;
                            watch.notificationId = id;
                            watch.batteryArrived();
                        });
                        process.running = true;
                        watch.checkBattery();
                    } else {
                        watch.awaitingBattery = false;
                        Quickshell.execDetached(["notify-send", "--app-name=Bluetooth", "--transient", `--icon=${device.icon || "bluetooth"}`,
                            device.name, "Disconnected"]);
                        root.setAudioCard(device.address, null);
                    }
                }

                function onBatteryAvailableChanged(): void {
                    watch.batteryArrived();
                    watch.checkBattery();
                }

                function onBatteryChanged(): void {
                    watch.batteryArrived();
                    watch.checkBattery();
                }
            }
        }
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
