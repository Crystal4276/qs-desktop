import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.modules.bar

// Panneau de statistiques système (remplace btop et nvtop, ARCHITECTURE § 7.16 ; ton choix du 2026-10-19 : panneau surgissant) :
// processeur (total, température, cœurs), mémoire et swap, GPU (charge, mémoire vidéo, température, consommation, ventilateur,
// fréquence), disques, réseau ; processus triables (nom, PID, utilisateur, CPU, mémoire, mémoire vidéo), recherche, arrêt de tes
// processus avec confirmation (SIGTERM, puis « Force » : SIGKILL). Mesures relevées seulement panneau ouvert (Monitor.users).
// Un processus choisi fige l'ordre de la liste (les valeurs continuent de changer, les nouveaux processus s'ajoutent en bas) jusqu'à
// ce qu'on le désélectionne (nouveau clic) ou qu'il s'arrête. Tri ou recherche changés : liste refigée et ramenée sur lui ; sélection
// levée s'il ne correspond plus à la recherche (pas d'arrêt d'un processus qu'on ne voit plus).
OverlayPopup {
    id: root

    property string sortKey: "cpu"
    property bool descending: true
    property string view: "applications"
    readonly property bool applicationView: view === "applications"
    readonly property var sourceRows: applicationView ? Monitor.applications : Monitor.processes
    property string selectedKey: ""
    property var confirmedApplication: null
    property string confirm: ""      // "", "end" ou "force" : confirmation en cours pour le processus choisi

    // Ordre des identités figé tant qu'un processus est choisi (null : liste triée en direct).
    property var frozen: null

    readonly property var sorted: {
        const q = search.text.toLowerCase();
        const list = sourceRows.filter(p => q === "" || p.name.toLowerCase().includes(q) || String(applicationView ? p.count : p.pid).startsWith(q)
            || p.user.toLowerCase().includes(q));
        const k = applicationView && sortKey === "pid" ? "count" : sortKey, d = descending ? -1 : 1;
        // Départage par identité : le tri du moteur n'est pas stable, les lignes à égalité s'échangeraient à chaque relevé.
        return list.sort((a, b) => (typeof a[k] === "string" ? a[k].localeCompare(b[k]) : a[k] - b[k]) * d || a.key.localeCompare(b.key));
    }
    // Identités des lignes, modèle de la liste : avec des objets et objectProp, ScriptModel garde l'ancien objet d'une ligne qui change
    // de rang (vérifié sur Quickshell 0.3.2), et ses valeurs resteraient périmées.
    readonly property var rows: {
        const pids = sorted.map(p => p.key);
        if (!frozen)
            return pids;
        const found = new Set(pids), known = new Set(frozen);
        return frozen.filter(pid => found.has(pid)).concat(pids.filter(pid => !known.has(pid)));
    }
    readonly property var rowByKey: {
        const byPid = {};
        for (const p of sourceRows)
            byPid[p.key] = p;
        return byPid;
    }
    readonly property var selectedProcess: rowByKey[selectedKey] ?? null

    // Processus choisi arrêté : sélection levée, la liste reprend son tri (après coup : changer selectedKey ici, pendant
    // l'évaluation de selectedProcess, ferait une boucle de liaison).
    onSelectedProcessChanged: {
        if (selectedKey !== "" && !selectedProcess)
            Qt.callLater(() => {
                if (selectedKey !== "" && !selectedProcess)
                    select("");
            });
    }

    function select(pid: string): void {
        selectedKey = pid;
        confirm = "";
        confirmedApplication = null;
        // D'un processus à un autre : même ordre, la ligne cliquée reste sous le pointeur.
        if (pid === "")
            frozen = null;
        else if (!frozen)
            frozen = rows;
    }

    // Tri ou recherche changés : nouvel ordre, figé de nouveau si un processus est choisi ; vue ramenée sur lui, sinon en haut.
    function refreeze(): void {
        if (selectedKey !== "") {
            const found = sorted.some(p => p.key === selectedKey);
            frozen = null;
            select(found ? selectedKey : "");
        }
        Qt.callLater(() => {
            const i = selectedKey !== "" ? rows.indexOf(selectedKey) : -1;
            if (i >= 0)
                list.positionViewAtIndex(i, ListView.Contain);
            else
                list.positionViewAtBeginning();
        });
    }

    // `from` : rangée de modules de la pilule cliquée, qui referme le panneau et donne l'écran ; null (raccourci) : écran focalisé.
    function toggle(from: Item): void {
        if (!beginOpen(from))
            return;
        screen = from ? from.QsWindow.window.screen : Outputs.focusedScreen();
        view = "applications";
        Monitor.stopError = "";
        search.text = "";
        select("");
        list.positionViewAtBeginning();
        visible = true;
        search.focusInput();
    }

    function changeView(key: string): void {
        select("");
        if (sortKey === "pid") sortKey = "cpu";
        search.text = "";
        view = key;
        Monitor.stopError = "";
        list.positionViewAtBeginning();
    }

    // Largeur commune d'une colonne de textes (jauges de même longueur).
    function widest(texts: var): int {
        return Math.ceil(Math.max(0, ...texts.map(t => smallMetrics.advanceWidth(t))));
    }

    // Largeur de « utilisé / total » : la valeur utilisée la plus large, pour que la jauge ne bouge pas quand elle change.
    function usageWidest(totals: var): int {
        return widest(totals.map(total => `888.8 GiB / ${bytes(total)}`));
    }

    readonly property int coreCount: Monitor.cores.length
    readonly property int coreLabelWidth: widest(Array.from({ length: coreCount }, (_, i) => String(i)))
    readonly property int memoryValueWidth: usageWidest([Monitor.memTotal, Monitor.swapTotal])
    readonly property real gpuMemoryTotal: (Monitor.gpu?.memTotal ?? 0) * 1048576
    readonly property int gpuValueWidth: usageWidest([gpuMemoryTotal])

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
        property real valueWidth: -1    // largeur commune des valeurs (jauges de même longueur)
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
            visible: parent.text !== ""
            Layout.preferredWidth: parent.valueWidth
            horizontalAlignment: Text.AlignRight
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

    FontMetrics {
        id: smallMetrics
        font.family: Theme.font.text
        font.pixelSize: Theme.panel.smallFontSize
    }

    // Largeur commune des étiquettes RAM, Swap, Load, VRAM.
    readonly property int shortLabelWidth: widest(["VRAM"])

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
                    valueWidth: root.widest(["100 %"])
                    tint: Theme.monitor.cpu
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: Theme.monitor.coreColumns
                    columnSpacing: Theme.panel.spacing
                    rowSpacing: Theme.panel.spacing / 4

                    // Modèles en nombre d'éléments (cœurs, disques, cellules d'une ligne) : les valeurs changent à chaque relevé sans
                    // recréer les délégués.
                    Repeater {
                        model: root.coreCount

                        Gauge {
                            required property int index
                            label: String(index)
                            labelWidth: root.coreLabelWidth   // jauges alignées
                            value: (Monitor.cores[index] ?? 0) / 100
                            tint: Theme.monitor.cpu
                        }
                    }
                }
            }

            Card {
                title: "Memory"

                Gauge {
                    label: "RAM"
                    labelWidth: root.shortLabelWidth
                    valueWidth: root.memoryValueWidth
                    value: Monitor.memTotal > 0 ? Monitor.memUsed / Monitor.memTotal : 0
                    text: `${root.bytes(Monitor.memUsed)} / ${root.bytes(Monitor.memTotal)}`
                    tint: Theme.monitor.memory
                }

                Gauge {
                    visible: Monitor.swapTotal > 0
                    label: "Swap"
                    labelWidth: root.shortLabelWidth
                    valueWidth: root.memoryValueWidth
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
                    labelWidth: root.shortLabelWidth
                    valueWidth: root.gpuValueWidth
                    value: (Monitor.gpu?.load ?? 0) / 100
                    text: `${Monitor.gpu?.load ?? 0} %`
                    tint: Theme.monitor.gpu
                }

                Gauge {
                    visible: (Monitor.gpu?.memTotal ?? -1) > 0
                    label: "VRAM"
                    labelWidth: root.shortLabelWidth
                    valueWidth: root.gpuValueWidth
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

            GridLayout {
                id: diskGrid
                readonly property int labelWidth: root.widest(Monitor.disks.map(d => d.mount))
                readonly property int valueWidth: root.usageWidest(Monitor.disks.map(d => d.size))

                Layout.fillWidth: true
                columns: 2
                columnSpacing: 2 * Theme.panel.spacing
                rowSpacing: Theme.panel.spacing / 4

                Repeater {
                    model: Monitor.disks.length

                    Gauge {
                        required property int index
                        readonly property var modelData: Monitor.disks[index] ?? { mount: "", size: 0, used: 0 }
                        label: modelData.mount
                        labelWidth: diskGrid.labelWidth
                        valueWidth: diskGrid.valueWidth
                        value: modelData.size > 0 ? modelData.used / modelData.size : 0
                        text: `${root.bytes(modelData.used)} / ${root.bytes(modelData.size)}`
                        tint: Theme.monitor.disk
                    }
                }
            }
        }


        Text {
            visible: Monitor.stopError !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Monitor.stopError
            color: Theme.panel.warning
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
        }

        // --- Processus ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            // One hit area: clicking either side always flips the view.
            Rectangle {
                id: viewToggle
                objectName: "monitor-view-toggle"
                readonly property real inset: Theme.panel.spacing / 2
                implicitWidth: 2 * Theme.mediaCard.buttonSize + 2 * inset
                implicitHeight: Theme.mediaCard.buttonSize + 2 * inset
                radius: height / 2
                color: Theme.panel.background
                border.width: Theme.panel.border
                border.color: activeFocus ? Theme.panel.focusRing : Theme.panel.borderColor
                activeFocusOnTab: true
                Accessible.name: "Applications / Processes"
                Accessible.role: Accessible.CheckBox
                Accessible.checkable: true
                Accessible.checked: root.applicationView
                Accessible.onToggleAction: flip(null)
                Keys.onReturnPressed: event => flip(event)
                Keys.onEnterPressed: event => flip(event)
                Keys.onSpacePressed: event => flip(event)

                function flip(event: KeyEvent): void {
                    if (!event?.isAutoRepeat)
                        root.changeView(root.applicationView ? "processes" : "applications");
                }

                Rectangle {
                    x: viewToggle.inset + (root.applicationView ? 0 : Theme.mediaCard.buttonSize)
                    y: viewToggle.inset
                    width: Theme.mediaCard.buttonSize
                    height: width
                    radius: width / 2
                    color: Theme.quickSettings.checked
                    Behavior on x {
                        enabled: root.visible
                        NumberAnimation {
                            duration: Theme.monitor.toggleDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    Repeater {
                        model: [
                            { key: "applications", glyph: Theme.icon.captureWindow, font: Theme.font.icons },
                            { key: "processes", glyph: Theme.icon.cpu, font: Theme.font.inlineIcons }
                        ]
                        Text {
                            required property var modelData
                            width: Theme.mediaCard.buttonSize
                            height: width
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.glyph
                            font.family: modelData.font
                            font.pixelSize: Theme.mediaCard.glyphSize
                            color: root.view === modelData.key ? Theme.quickSettings.checkedText : Theme.panel.secondaryText
                        }
                    }
                }

                MouseArea {
                    objectName: "monitor-view-toggle-hit"
                    anchors.fill: parent
                    onClicked: viewToggle.flip(null)
                }
                HoverHandler { id: toggleHover }
                Rectangle {
                    visible: toggleHover.hovered || viewToggle.activeFocus
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Theme.panel.spacing
                    width: toggleLabel.implicitWidth + 2 * Theme.panel.buttonPaddingH
                    height: toggleLabel.implicitHeight + 2 * Theme.panel.buttonPaddingV
                    radius: Theme.panel.rowRadius
                    color: Theme.panel.background
                    border.width: Theme.panel.border
                    border.color: Theme.panel.borderColor
                    Text {
                        id: toggleLabel
                        anchors.centerIn: parent
                        text: root.applicationView ? "Show processes" : "Show applications"
                        color: Theme.panel.text
                        font.family: Theme.font.text
                        font.pixelSize: Theme.panel.smallFontSize
                    }
                }
            }

            PanelField {
                id: search
                placeholder: root.applicationView ? "Search applications" : "Search processes"
                search: true
                onTextChanged: Qt.callLater(root.refreeze)   // après la mise à jour de `sorted`
                Keys.onEscapePressed: root.close()
            }

            // Processus choisi (les tiens seulement) : arrêter, forcer ; confirmation avant l'envoi du signal.
            Text {
                visible: root.confirm !== "" && root.selectedProcess !== null
                text: root.confirm === "force" ? `Force quit ${root.selectedProcess?.name} (${root.applicationView ? `${root.confirmedApplication?.members.length ?? 0} processes` : root.selectedProcess?.pid})?`
                    : `End ${root.selectedProcess?.name} (${root.applicationView ? `${root.confirmedApplication?.members.length ?? 0} processes` : root.selectedProcess?.pid})?`
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
                    if (root.applicationView)
                        Monitor.stopApplication(root.selectedKey, root.confirm === "force", root.confirmedApplication);
                    else
                        Monitor.stopProcess(root.selectedKey, root.confirm === "force");
                    root.confirm = "";
                }
            }

            PanelButton {
                visible: root.confirm === "" && root.selectedProcess !== null && root.selectedProcess.user === Monitor.me
                enabled: !root.selectedProcess?.blocked
                text: root.applicationView ? "End application" : "End process"
                onClicked: { root.confirmedApplication = root.selectedProcess; root.confirm = "end"; }
            }

            PanelButton {
                visible: root.confirm === "" && root.selectedProcess !== null && root.selectedProcess.user === Monitor.me
                enabled: !root.selectedProcess?.blocked
                text: "Force quit"
                onClicked: { root.confirmedApplication = root.selectedProcess; root.confirm = "force"; }
            }
        }

        Text {
            visible: root.applicationView && (root.selectedProcess?.blocked ?? false)
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "This process hosts multiple applications. Use Processes to inspect it."
            color: Theme.panel.warning
            font.family: Theme.font.text
            font.pixelSize: Theme.panel.smallFontSize
        }

        // En-têtes : clic = tri (de nouveau : sens inverse).
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Theme.panel.spacing

            Repeater {
                model: [
                    { key: "name", name: "Name", fill: true },
                    { key: "pid", name: root.applicationView ? "Processes" : "PID" },
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
                    // Sens du tri : glyphe de la police d'icônes (absent d'Inter), à côté du nom.
                    textFormat: Text.RichText
                    text: modelData.name + (root.sortKey !== modelData.key ? ""
                        : ` <span style="font-family: '${Theme.font.icons}'">${root.descending ? Theme.icon.sortDown : Theme.icon.sortUp}</span>`)
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

                required property string modelData    // Stable row identity
                // Absent le temps qu'une ligne soit retirée du modèle.
                readonly property var process: root.rowByKey[modelData] ?? null
                readonly property var cells: process ? [process.name, String(root.applicationView ? process.count : process.pid), process.user, `${process.cpu.toFixed(1)} %`,
                    root.bytes(process.memory), process.gpu > 0 ? `${process.gpu} MiB` : ""] : ["", "", "", "", "", ""]
                width: list.width
                height: measure.implicitHeight + Theme.panel.rowPadding
                radius: Theme.panel.rowRadius / 2
                color: root.selectedKey === modelData ? Theme.monitor.selected : "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.panel.spacing

                    Repeater {
                        model: 6

                        Text {
                            required property int index
                            readonly property bool fill: index === 0   // nom
                            Layout.fillWidth: fill
                            Layout.preferredWidth: fill ? -1 : frame.width / 9
                            horizontalAlignment: fill ? Text.AlignLeft : Text.AlignRight
                            text: row.cells[index]
                            elide: Text.ElideRight
                            font.family: Theme.font.text
                            font.pixelSize: Theme.panel.smallFontSize
                            color: Theme.panel.text
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.select(root.selectedKey === row.modelData ? "" : row.modelData)
                }
            }
        }
    }
}
