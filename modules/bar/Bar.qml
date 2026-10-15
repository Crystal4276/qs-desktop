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
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.bar.exclusiveZone
        exclusiveZone: Theme.bar.exclusiveZone
        color: Theme.bar.background

        // Nom de module (hosts/*.json) → composant. Les modules pas encore écrits n'affichent rien.
        readonly property var modules: ({
            workspaces: workspacesModule,
            clock: clockModule,
            clockDate: clockDateModule
        })

        Component {
            id: workspacesModule
            Workspaces {
                output: bar.modelData?.name ?? ""
            }
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

        RowLayout {
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: Theme.bar.marginSide
                topMargin: Theme.bar.marginTop
            }
            spacing: Theme.bar.spacing

            Repeater {
                model: bar.layout.left
                Pill {
                    id: pill

                    required property var modelData

                    Repeater {
                        model: pill.modelData
                        Loader {
                            required property string modelData
                            Layout.fillHeight: true
                            sourceComponent: bar.modules[modelData] ?? null
                        }
                    }
                }
            }
        }

        RowLayout {
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: Theme.bar.marginSide
                topMargin: Theme.bar.marginTop
            }
            spacing: Theme.bar.spacing

            Repeater {
                model: bar.layout.right
                Pill {
                    id: pill

                    required property var modelData

                    Repeater {
                        model: pill.modelData
                        Loader {
                            required property string modelData
                            Layout.fillHeight: true
                            sourceComponent: bar.modules[modelData] ?? null
                        }
                    }
                }
            }
        }
    }
}
