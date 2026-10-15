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
                    required property var modelData
                    modules: modelData
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
                    required property var modelData
                    modules: modelData
                }
            }
        }
    }
}
