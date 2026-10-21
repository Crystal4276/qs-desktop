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
        readonly property var layout: Settings.barFor(output?.description ?? "", Outputs.isPrimary(modelData?.name ?? ""))

        screen: modelData
        WlrLayershell.namespace: "quickshell-bar"
        // Clavier « à la demande » seulement pendant le survol de l'horloge ou l'épinglage du calendrier (CalendarPopup.qml) :
        // le clic qui épingle donne alors le focus à la barre, sans le prendre aux fenêtres le reste du temps.
        WlrLayershell.keyboardFocus: BarState.keyboardScreen !== "" && BarState.keyboardScreen === (modelData?.name ?? "")
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
            cava: cavaModule,
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
            id: cavaModule
            CavaModule {}
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
                    visible: Array.from({ length: pillModules.count }, (_, i) => pillModules.itemAt(i)).some(l => l?.wanted)
                    // Survol en bloc (statistiques, InfoModule.qml) : seulement si tous ses modules affichés en demandent un (aucun ne
                    // garderait sinon son texte clair sur le fond) ; couleur du premier.
                    readonly property var shownModules: Array.from({ length: pillModules.count }, (_, i) => pillModules.itemAt(i))
                        .filter(l => l?.wanted).map(l => l.item)
                    highlightColor: shownModules.length > 0 && shownModules.every(m => m.pillHighlight?.a > 0)
                        ? shownModules[0].pillHighlight : "transparent"

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

        Side {
            anchors.left: parent.left
            anchors.leftMargin: Theme.bar.marginSide
            pills: bar.layout.left
        }

        Side {
            anchors.right: parent.right
            anchors.rightMargin: Theme.bar.marginSide
            pills: bar.layout.right
        }

        // « Garder l'écran allumé » (panneau de réglages) : les barres sont toujours affichées, le compositeur respecte donc
        // l'inhibiteur tant qu'au moins un écran est allumé.
        IdleInhibitor {
            window: bar
            enabled: Session.keepAwake
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
