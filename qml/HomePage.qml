import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Home: hero card + HYPR-RX-style profiles + quick stats
Rectangle {
    id: page
    color: "#141414"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: backend.refreshMetrics()
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 18

            // hero
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 150
                radius: 12
                gradient: Gradient {
                    GradientStop { position: 0; color: "#2b1013" }
                    GradientStop { position: 0.55; color: "#191919" }
                    GradientStop { position: 1; color: "#1b1b1b" }
                }
                border.color: "#332"
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 6
                    Text {
                        text: "AMD Software"
                        color: "#ED1C24"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: backend.gpuName
                        color: "white"
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        text: "Overdrive " + backend.sclkMin + "–" + backend.sclkMax + " MHz · perf level: "
                              + backend.perfLevel + " · kernel " + backend.kernelVersion
                        color: "#9a9a9a"
                        font.pixelSize: 12
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        spacing: 26
                        MiniStat { label: "GPU temp"; value: backend.gpuTemp.toFixed(0) + "°C" }
                        MiniStat { label: "GPU power"; value: backend.gpuPower.toFixed(1) + " W" }
                        MiniStat { label: "GPU busy"; value: backend.gpuBusy + "%" }
                    }
                }
            }

            // HYPR-RX-style profile cards
            Text {
                text: "Profiles"
                color: "#9a9a9a"
                font.pixelSize: 13
                font.bold: true
            }
            RowLayout {
                spacing: 14
                ProfileCard {
                    title: "Default"
                    desc: "Balanced clocks, automatic power management"
                    level: "auto"
                    active: backend.perfLevel === "auto"
                }
                ProfileCard {
                    title: "Performance"
                    desc: "Maximum clocks for gaming sessions"
                    level: "high"
                    active: backend.perfLevel === "high"
                }
                ProfileCard {
                    title: "Eco"
                    desc: "Power saving — lower clocks, lower draw"
                    level: "low"
                    active: backend.perfLevel === "low"
                }
            }

            Text {
                text: "Perf-level writes need root unless the permission rule is installed"
                      + " (sudo scripts/install-permissions.sh)."
                color: "#666"
                font.pixelSize: 11
            }
        }
    }

    component MiniStat: ColumnLayout {
        property string label
        property string value
        spacing: 2
        Text { text: label; color: "#9a9a9a"; font.pixelSize: 11 }
        Text { text: value; color: "white"; font.pixelSize: 17; font.bold: true }
    }

    component ProfileCard: Rectangle {
        property string title
        property string desc
        property string level
        property bool active
        Layout.fillWidth: true
        implicitHeight: 86
        radius: 10
        color: active ? "#2e1618" : "#1e1e1e"
        border.color: active ? "#ED1C24" : "#2a2a2a"
        border.width: active ? 1 : 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: title
                    color: active ? "#ff5a5a" : "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: active ? "#ED1C24" : "#3a3a3a"
                }
            }
            Text {
                text: desc
                color: "#9a9a9a"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.setPerfLevel(level)
        }
    }
}
