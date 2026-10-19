import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar

// Panneau de statistiques système (remplace btop et nvtop, ARCHITECTURE § 11.5 ; ton choix du 2026-10-19 : panneau surgissant) :
// processeur (total, température, cœurs), mémoire et swap, GPU (charge, mémoire vidéo, température, consommation, ventilateur,
// fréquence), disques, réseau ; processus triables (nom, PID, utilisateur, CPU, mémoire, mémoire vidéo), recherche, arrêt de tes
// processus avec confirmation (SIGTERM, puis « Force » : SIGKILL). Mesures relevées seulement panneau ouvert (Monitor.users).
// Un processus choisi fige l'ordre de la liste (les valeurs continuent de changer, les nouveaux processus s'ajoutent en bas) jusqu'à
// ce qu'on le désélectionne (nouveau clic), qu'il s'arrête, ou qu'on change le tri ou la recherche (la liste est alors refigée).
OverlayPopup {
    id: root

    property string sortKey: "cpu"
    property bool descending: true
    property int selectedPid: -1
    property string confirm: ""      // "", "end" ou "force" : confirmation en cours pour le processus choisi

    // Ordre des PID figé tant qu'un processus est choisi (null : liste triée en direct).
    property var frozen: null

    readonly property var sorted: {
        const q = search.text.toLowerCase();
        const list = Monitor.processes.filter(p => q === "" || p.name.toLowerCase().includes(q) || String(p.pid).startsWith(q)
            || p.user.toLowerCase().includes(q));
        const k = sortKey, d = descending ? -1 : 1;
        return list.sort((a, b) => (typeof a[k] === "string" ? a[k].localeCompare(b[k]) : a[k] - b[k]) * d);
    }
    readonly property var rows: {
        if (!frozen)
            return sorted;
        const byPid = {};
        for (const p of sorted)
            byPid[p.pid] = p;
        const known = new Set(frozen);
        return frozen.filter(pid => byPid[pid]).map(pid => byPid[pid]).concat(sorted.filter(p => !known.has(p.pid)));
    }
    readonly property var selectedProcess: Monitor.processes.find(p => p.pid === selectedPid) ?? null

    // Processus choisi arrêté : sélection levée, la liste reprend son tri.
    onSelectedProcessChanged: {
        if (selectedPid >= 0 && !selectedProcess)
            select(-1);
    }

    function select(pid: int): void {
        selectedPid = pid;
        confirm = "";
        frozen = null;
        if (pid >= 0)
            frozen = rows.map(p => p.pid);
    }

    // Tri ou recherche changés : nouvel ordre, figé de nouveau si un processus est choisi.
    function refreeze(): void {
        if (selectedPid >= 0)
            select(selectedPid);
    }

    function toggle(): void {
        if (visible) {
            close();
            return;
        }
        screen = Quickshell.screens.find(s => s.name === Compositor.focusedOutput) ?? Quickshell.screens[0];
        prepareOpen(null);
        search.text = "";
        select(-1);
        visible = true;
        search.focusInput();
    }

    function bytes(v: real): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return `${v.toFixed(i >= 3 ? 1 : 0)} ${units[i]}`;
    }

    function sortBy(key: string): void {
        if (sortKey === key)
            descending = !descending;
        else {
            sortKey = key;
            descending = key !== "name" && key !== "user";
        }
        refreeze();
    }

    WlrLayershell.namespace: "quickshell-monitor"
    frameItem: frame

    onVisibleChanged: Monitor.users += visible ? 1 : -1
    Component.onDestruction: {
        if (visible)
            Monitor.users--;
    }

    // Jauge : piste `surface0`, remplissage de la couleur du module, texte à droite.
    component Gauge: RowLayout {
        property string label: ""
        property real labelWidth: -1    // largeur commune des étiquettes d'une carte (jauges alignées)
        property real value: 0          // 0 → 1
        property string text: ""
        property color tint: Theme.monitor.cpu

        Layout.fillWidth: true
        spacing: Theme.panel.spacing

        Text {
            visible: parent.label !== ""
            Layout.preferredWidth: parent.labelWidth
            elide: Text.ElideRight
            text: parent.label
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            color: Theme.panel.secondaryText
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.monitor.barHeight
            radius: height / 2
            color: Theme.monitor.track

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.parent.value))
                height: parent.height
                radius: height / 2
                color: parent.parent.tint
            }
        }

        Text {
            text: parent.text
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
            color: Theme.panel.text
        }
    }

    // Carte : titre et valeurs.
    component Card: Rectangle {
        default property alias content: column.data
        property string title: ""

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        implicitHeight: column.implicitHeight + 2 * Theme.panel.padding
        radius: Theme.panel.rowRadius
        color: Theme.panel.fieldBackground

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.panel.padding
            spacing: Theme.panel.spacing / 2

            Text {
                text: parent.parent.title
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.fontSize
                font.bold: true
                color: Theme.panel.title
            }
        }
    }

    // Largeur commune des étiquettes RAM, Swap, Load, VRAM.
    Text {
        id: labelMeasure
        visible: false
        text: "VRAM"
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.smallFontSize
    }

    PanelFrame {
        id: frame

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(Theme.monitor.width, parent.width - 2 * Theme.bar.marginSide)
        maxHeight: parent.height - 2 * Theme.panel.gap
        onCloseRequested: root.close()

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            Card {
                title: `CPU  ${Monitor.cpuTotal} %${Monitor.cpuTemperature >= 0 ? `  ·  ${Monitor.cpuTemperature} °C` : ""}`

                Gauge {
                    value: Monitor.cpuTotal / 100
                    text: `${Monitor.cpuTotal} %`
                    tint: Theme.monitor.cpu
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: Theme.monitor.coreColumns
                    columnSpacing: Theme.panel.spacing
                    rowSpacing: Theme.panel.spacing / 4

                    Repeater {
                        model: Monitor.cores

                        Gauge {
                            required property int modelData
                            required property int index
                            label: String(index)
                            value: modelData / 100
                            tint: Theme.monitor.cpu
                        }
                    }
                }
            }

            Card {
                title: "Memory"

                Gauge {
                    label: "RAM"
                    labelWidth: labelMeasure.implicitWidth
                    value: Monitor.memTotal > 0 ? Monitor.memUsed / Monitor.memTotal : 0
                    text: `${root.bytes(Monitor.memUsed)} / ${root.bytes(Monitor.memTotal)}`
                    tint: Theme.monitor.memory
                }

                Gauge {
                    visible: Monitor.swapTotal > 0
                    label: "Swap"
                    labelWidth: labelMeasure.implicitWidth
                    value: Monitor.swapTotal > 0 ? Monitor.swapUsed / Monitor.swapTotal : 0
                    text: `${root.bytes(Monitor.swapUsed)} / ${root.bytes(Monitor.swapTotal)}`
                    tint: Theme.monitor.memory
                }

                Text {
                    Layout.topMargin: Theme.panel.spacing
                    text: "Network"
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.fontSize
                    font.bold: true
                    color: Theme.panel.title
                }

                Text {
                    text: `↓ ${root.bytes(Network.downBytesPerSecond)}/s    ↑ ${root.bytes(Network.upBytesPerSecond)}/s`
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.smallFontSize
                    color: Theme.panel.text
                }
            }

            Card {
                visible: Monitor.gpu !== null
                title: Monitor.gpu?.name ?? "GPU"

                Gauge {
                    visible: (Monitor.gpu?.load ?? -1) >= 0
                    label: "Load"
                    labelWidth: labelMeasure.implicitWidth
                    value: (Monitor.gpu?.load ?? 0) / 100
                    text: `${Monitor.gpu?.load ?? 0} %`
                    tint: Theme.monitor.gpu
                }

                Gauge {
                    visible: (Monitor.gpu?.memTotal ?? -1) > 0
                    label: "VRAM"
                    labelWidth: labelMeasure.implicitWidth
                    value: (Monitor.gpu?.memTotal ?? 0) > 0 ? Monitor.gpu.memUsed / Monitor.gpu.memTotal : 0
                    text: `${root.bytes((Monitor.gpu?.memUsed ?? 0) * 1048576)} / ${root.bytes((Monitor.gpu?.memTotal ?? 0) * 1048576)}`
                    tint: Theme.monitor.gpu
                }

                Text {
                    text: [
                        (Monitor.gpu?.temperature ?? -1) >= 0 ? `${Monitor.gpu.temperature} °C` : "",
                        (Monitor.gpu?.power ?? -1) >= 0 ? `${Math.round(Monitor.gpu.power)} W` : "",
                        (Monitor.gpu?.fan ?? -1) >= 0 ? `fan ${Monitor.gpu.fan} %` : "",
                        (Monitor.gpu?.clock ?? -1) >= 0 ? `${Monitor.gpu.clock} MHz` : ""
                    ].filter(t => t !== "").join("  ·  ")
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.smallFontSize
                    color: Theme.panel.text
                }
            }
        }

        // Disques : toute la largeur, deux colonnes.
        Card {
            title: "Disks"
            Layout.fillHeight: false

            FontMetrics {
                id: mountMetrics
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 2 * Theme.panel.spacing
                rowSpacing: Theme.panel.spacing / 4

                Repeater {
                    model: Monitor.disks

                    Gauge {
                        required property var modelData
                        label: modelData.mount
                        labelWidth: Math.ceil(Math.max(0, ...Monitor.disks.map(d => mountMetrics.advanceWidth(d.mount))))
                        value: modelData.size > 0 ? modelData.used / modelData.size : 0
                        text: `${root.bytes(modelData.used)} / ${root.bytes(modelData.size)}`
                        tint: Theme.monitor.disk
                    }
                }
            }
        }

        // --- Processus ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            PanelField {
                id: search
                placeholder: "Search processes"
                onTextChanged: root.refreeze()
                Keys.onEscapePressed: root.close()
            }

            // Processus choisi (les tiens seulement) : arrêter, forcer ; confirmation avant l'envoi du signal.
            Text {
                visible: root.confirm !== "" && root.selectedProcess !== null
                text: root.confirm === "force" ? `Force quit ${root.selectedProcess?.name} (${root.selectedPid})?`
                    : `End ${root.selectedProcess?.name} (${root.selectedPid})?`
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
                color: Theme.panel.warning
            }

            PanelButton {
                visible: root.confirm !== ""
                text: "Cancel"
                onClicked: root.confirm = ""
            }

            PanelButton {
                visible: root.confirm !== ""
                text: "Confirm"
                checked: true
                onClicked: {
                    Monitor.stop(root.selectedPid, root.confirm === "force");
                    root.confirm = "";
                }
            }

            PanelButton {
                visible: root.confirm === "" && root.selectedProcess !== null && root.selectedProcess.user === Monitor.me
                text: "End process"
                onClicked: root.confirm = "end"
            }

            PanelButton {
                visible: root.confirm === "" && root.selectedProcess !== null && root.selectedProcess.user === Monitor.me
                text: "Force quit"
                onClicked: root.confirm = "force"
            }
        }

        // En-têtes : clic = tri (de nouveau : sens inverse).
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            Repeater {
                model: [
                    { key: "name", name: "Name", fill: true },
                    { key: "pid", name: "PID" },
                    { key: "user", name: "User" },
                    { key: "cpu", name: "CPU" },
                    { key: "memory", name: "Memory" },
                    { key: "gpu", name: "VRAM" }
                ]

                Text {
                    required property var modelData
                    Layout.fillWidth: modelData.fill === true
                    Layout.preferredWidth: modelData.fill === true ? -1 : frame.width / 9
                    horizontalAlignment: modelData.fill === true ? Text.AlignLeft : Text.AlignRight
                    text: modelData.name + (root.sortKey === modelData.key ? (root.descending ? " ▾" : " ▴") : "")
                    font.family: Theme.font.text
                    font.pixelSize: Theme.panel.smallFontSize
                    font.bold: true
                    color: root.sortKey === modelData.key ? Theme.panel.title : Theme.panel.secondaryText

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.sortBy(parent.modelData.key)
                    }
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Theme.monitor.processRows * (measure.implicitHeight + Theme.panel.rowPadding)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: root.rows
                objectProp: "pid"
            }

            Text {
                id: measure
                visible: false
                text: "Ag"
                font.family: Theme.font.text
                font.pixelSize: Theme.panel.smallFontSize
            }

            delegate: Rectangle {
                id: row

                required property var modelData
                width: list.width
                height: measure.implicitHeight + Theme.panel.rowPadding
                radius: Theme.panel.rowRadius / 2
                color: root.selectedPid === modelData.pid ? Theme.monitor.selected : "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.panel.spacing

                    Repeater {
                        model: [
                            { text: row.modelData.name, fill: true },
                            { text: String(row.modelData.pid) },
                            { text: row.modelData.user },
                            { text: `${row.modelData.cpu.toFixed(1)} %` },
                            { text: root.bytes(row.modelData.memory) },
                            { text: row.modelData.gpu > 0 ? `${row.modelData.gpu} MiB` : "" }
                        ]

                        Text {
                            required property var modelData
                            Layout.fillWidth: modelData.fill === true
                            Layout.preferredWidth: modelData.fill === true ? -1 : frame.width / 9
                            horizontalAlignment: modelData.fill === true ? Text.AlignLeft : Text.AlignRight
                            text: modelData.text
                            elide: Text.ElideRight
                            font.family: Theme.font.text
                            font.pixelSize: Theme.panel.smallFontSize
                            color: Theme.panel.text
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.select(root.selectedPid === row.modelData.pid ? -1 : row.modelData.pid)
                }
            }
        }
    }
}
