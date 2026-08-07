import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#121218"

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: backend.refreshScreens()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        Text {
            text: "Display"
            color: "white"
            font.pixelSize: 22
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                color: "#1a1a22"
                radius: 8
                implicitHeight: 150
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Text { text: "Screens"; color: "#888"; font.pixelSize: 12 }
                    Repeater {
                        model: backend.screens
                        Text {
                            text: modelData.name + "  ·  " + modelData.width + "×" + modelData.height
                                  + "  ·  " + modelData.refresh + " Hz"
                                  + (modelData.primary ? "  (primary)" : "")
                            color: "#ddd"
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: "#1a1a22"
                radius: 8
                implicitHeight: 150
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Text { text: "Connectors (amdgpu)"; color: "#888"; font.pixelSize: 12 }
                    Repeater {
                        model: backend.connectors
                        Text {
                            text: modelData.name + "  ·  " + modelData.status
                            color: modelData.status === "connected" ? "#6fdc8c" : "#666"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: "#1a1a22"
            radius: 8
            implicitHeight: 150
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                Text { text: "Night light (GNOME)"; color: "#888"; font.pixelSize: 12 }
                RowLayout {
                    Text { text: "Enabled"; color: "#aaa" }
                    Switch {
                        checked: backend.nightLightEnabled
                        onToggled: backend.nightLightEnabled = checked
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: backend.nightLightTemp + " K"; color: "white" }
                }
                RowLayout {
                    Text { text: "Temperature"; color: "#aaa"; Layout.preferredWidth: 90 }
                    Slider {
                        id: nlSlider
                        Layout.fillWidth: true
                        from: 2000
                        to: 6500
                        stepSize: 100
                        value: backend.nightLightTemp
                        onMoved: backend.nightLightTemp = value
                    }
                }
                Text {
                    text: "Color controls (FreeSync, color depth, blue light) need a Wayland protocol or amdgpu DC support — planned."
                    color: "#666"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
