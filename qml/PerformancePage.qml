import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#121218"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: backend.refreshMetrics()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            text: "Performance"
            color: "white"
            font.pixelSize: 22
            font.bold: true
        }
        Text {
            text: "Live metrics from amdgpu sysfs (1 s poll)"
            color: "#888"
            font.pixelSize: 12
        }

        RowLayout {
            spacing: 24
            Gauge { label: "GPU temp"; value: backend.gpuTemp; unit: "°C"; max: 110 }
            Gauge { label: "GPU power"; value: backend.gpuPower; unit: "W"; max: 120 }
            Gauge { label: "GPU busy"; value: backend.gpuBusy; unit: "%"; max: 100 }
            Gauge { label: "VCN busy"; value: backend.vcnBusy; unit: "%"; max: 100 }
        }
    }

    component Gauge: Rectangle {
        property string label
        property real value
        property string unit
        property real max
        color: "#1a1a22"
        radius: 8
        implicitWidth: 220
        implicitHeight: 160
        Layout.fillWidth: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            Text { text: label; color: "#888"; font.pixelSize: 12 }
            Text {
                text: value.toFixed(1) + " " + unit
                color: "white"
                font.pixelSize: 28
                font.bold: true
            }
            Rectangle {
                Layout.fillWidth: true
                height: 8
                radius: 4
                color: "#2a2a32"
                Rectangle {
                    height: parent.height
                    width: parent.width * (value / max)
                    radius: 4
                    color: "#ff5b5b"
                }
            }
        }
    }
}
