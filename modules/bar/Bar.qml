import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Une barre par écran actif, créée et détruite avec les écrans.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        readonly property var output: Compositor.output(modelData?.name ?? "")

        // Disposition (modules de chaque pilule) : une nouvelle recrée tous les modules (~50 ms). Appliquée une fois l'écran connu,
        // au tour suivant de la boucle (écrans d'une même réponse ensemble), et seulement si son contenu a changé.
        // Écran que le compositeur ne décrit pas (miroir, compositeur inconnu) : disposition par défaut, s'il ne l'est toujours pas 2 s
        // après les autres (un écran branché est décrit un peu après son apparition : pas de barre provisoire à reconstruire).
        readonly property bool outputsKnown: Compositor.outputs.length > 0 || Compositor.type === ""
        property bool fallbackDue: false
        property bool described: false   // décrit au moins une fois : un retrait passager garde la disposition, sans repli
        onOutputChanged: {
            if (output)
                described = true;
        }
        readonly property string wantedLayout: output || (fallbackDue && !described)
            ? JSON.stringify(Settings.barFor(output?.description ?? "", Outputs.isPrimary(modelData?.name ?? ""))) : ""
        property string appliedLayout: ""
        readonly property var layout: appliedLayout !== "" ? JSON.parse(appliedLayout) : ({ left: [], right: [] })

        // Écran disparu un instant : disposition gardée ; sans effet si rien n'a changé. Minuteur de la barre (détruit avec elle,
        // écran débranché : pas d'écriture sur une barre disparue).
        onWantedLayoutChanged: layoutTimer.restart()
        Component.onCompleted: layoutTimer.restart()   // écran déjà connu à la création : aucun « changed » pour la valeur initiale

        Timer {
            interval: 2000
            running: !bar.output && !bar.described && bar.outputsKnown && !bar.fallbackDue
            onTriggered: bar.fallbackDue = true
        }

        Timer {
            id: layoutTimer
            interval: 0
            onTriggered: {
                if (bar.wantedLayout !== "")
                    bar.appliedLayout = bar.wantedLayout;
            }
        }

        screen: modelData
        WlrLayershell.namespace: "quickshell-bar"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.bar.exclusiveZone
        exclusiveZone: Theme.bar.exclusiveZone
        color: Theme.bar.background

        // Nom de module (hosts/*.json, ARCHITECTURE § 4) → composant.
        // Un module peut se masquer (`shown` faux) ; une pilule dont tous les modules sont masqués disparaît.
        readonly property var modules: ({
            menu: menuModule,
            workspaces: workspacesModule,
            mpris: mprisModule,
            volume: volumeModule,
            slider: sliderModule,
            updates: updatesModule,
            gpu: gpuModule,
            cpu: cpuModule,
            memory: memoryModule,
            clock: clockModule,
            clockDate: clockDateModule,
            network: networkModule,
            tray: trayModule,
            settings: settingsModule,
            battery: batteryModule,
            backlight: backlightModule
        })

        Component {
            id: menuModule
            MenuButton {}
        }
        Component {
            id: workspacesModule
            Workspaces {
                output: bar.modelData?.name ?? ""
            }
        }
        Component {
            id: mprisModule
            Mpris {}
        }
        Component {
            id: volumeModule
            Volume {}
        }
        Component {
            id: sliderModule
            Slider {}
        }
        Component {
            id: updatesModule
            UpdatesModule {}
        }
        Component {
            id: gpuModule
            GpuModule {}
        }
        Component {
            id: cpuModule
            Cpu {}
        }
        Component {
            id: memoryModule
            Memory {}
        }
        Component {
            id: clockModule
            Clock {}
        }
        Component {
            id: clockDateModule
            Clock {
                showDate: true
            }
        }
        Component {
            id: networkModule
            NetworkModule {}
        }
        Component {
            id: trayModule
            Tray {}
        }
        Component {
            id: settingsModule
            SettingsButton {}
        }
        Component {
            id: batteryModule
            BatteryModule {}
        }
        Component {
            id: backlightModule
            Backlight {}
        }

        component Side: RowLayout {
            id: side

            property var pills: []

            anchors.top: parent.top
            anchors.topMargin: Theme.bar.marginTop
            spacing: Theme.bar.spacing

            Repeater {
                model: side.pills

                Pill {
                    id: pill

                    required property var modelData

                    // Visible si l'un de ses modules veut s'afficher. Pas d'après la largeur de la rangée : une pilule
                    // cachée rend ses modules invisibles pour la mise en page, elle ne réapparaîtrait jamais.
                    readonly property var shownModules: Array.from({ length: pillModules.count }, (_, i) => pillModules.itemAt(i))
                        .filter(l => l?.wanted).map(l => l.item)
                    visible: shownModules.length > 0
                    // Survol en bloc (statistiques, InfoModule.qml) : seulement si tous ses modules affichés en demandent un (aucun ne
                    // garderait sinon son texte clair sur le fond) ; couleur du premier.
                    highlightColor: shownModules.length > 0 && shownModules.every(m => m.pillHighlight) ? shownModules[0].pillHighlight : null

                    Repeater {
                        id: pillModules
                        model: pill.modelData

                        Loader {
                            id: slot

                            required property string modelData
                            required property int index

                            Layout.fillHeight: true
                            // Le module veut s'afficher (`visible` lu ici serait la visibilité effective, fausse si la pilule est cachée).
                            readonly property bool wanted: item !== null && item.shown !== false

                            sourceComponent: bar.modules[modelData] ?? null
                            visible: wanted

                            // Premier module affiché de la pilule (le volume n'a de padding gauche qu'en tête : style.css).
                            Binding {
                                when: slot.item !== null && slot.item.leading !== undefined
                                target: slot.item
                                property: "leading"
                                value: !Array.from({ length: slot.index }, (_, i) => pillModules.itemAt(i)).some(l => l?.wanted)
                            }
                            Binding {
                                when: slot.item !== null && slot.item.pillHighlighted !== undefined
                                target: slot.item
                                property: "pillHighlighted"
                                value: pill.highlighted
                            }
                            // Dernier module affiché de la pilule (InfoModule : seul à garder un padding droit).
                            Binding {
                                when: slot.item !== null && slot.item.trailing !== undefined
                                target: slot.item
                                property: "trailing"
                                value: !Array.from({ length: pillModules.count - slot.index - 1 }, (_, i) => pillModules.itemAt(slot.index + 1 + i)).some(l => l?.wanted)
                            }
                        }
                    }
                }
            }
        }

        // Démarrage : contenu affiché en même temps que les fonds d'écran (Wallpapers.startupShown) ; la fenêtre, elle, est là dès
        // le début (zone réservée : les fenêtres ne sont pas réarrangées à son arrivée).
        Side {
            visible: Wallpapers.startupShown
            anchors.left: parent.left
            anchors.leftMargin: Theme.bar.marginSide
            pills: bar.layout.left
        }

        Side {
            visible: Wallpapers.startupShown
            anchors.right: parent.right
            anchors.rightMargin: Theme.bar.marginSide
            pills: bar.layout.right
        }

        // « Garder l'écran allumé » (panneau de réglages) ou manette Bluetooth connectée (Sway ne voit pas son activité ; module
        // GameControllerWakelock de blueman) : les barres sont toujours affichées, le compositeur respecte donc l'inhibiteur tant
        // qu'au moins un écran est allumé.
        IdleInhibitor {
            window: bar
            enabled: Session.keepAwake || Bluez.gamepadConnected
        }

        // Popup ouvert : un appui sur une barre le ferme, sauf sur son propre bouton (qui le ferme lui-même) ; l'appui n'est
        // pas accepté et atteint le module dessous.
        MouseArea {
            id: closeArea
            anchors.fill: parent
            z: 1
            enabled: BarState.openPopups > 0
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                BarState.closeFromBarPress(closeArea, mouse.x, mouse.y, mouse.button);
                mouse.accepted = false;
            }
        }
    }
}
