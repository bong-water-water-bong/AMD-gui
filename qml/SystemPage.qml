import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#141414"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 10

        Text {
            text: "Settings"
            color: "white"
            font.pixelSize: 22
            font.bold: true
        }

        InfoRow { k: "GPU"; v: backend.gpuName }
        InfoRow { k: "VRAM"; v: backend.vramGB > 0 ? backend.vramUsedGB.toFixed(1) + " / " + backend.vramGB.toFixed(0) + " GB" : "—" }
        InfoRow { k: "Kernel"; v: backend.kernelVersion }
        InfoRow { k: "Fan"; v: backend.fanRpm + " RPM" }
        InfoRow { k: "Power limit"; v: backend.powerCap > 0 ? backend.powerCap + " W" : "—" }
        InfoRow { k: "Temps"; v: (backend.gpuTemp.toFixed(0) + " / " + backend.junctionTemp.toFixed(0) + " / " + backend.memTemp.toFixed(0)) + " °C (edge/junction/mem)" }
        InfoRow { k: "Perf level"; v: backend.perfLevel }
        InfoRow { k: "SCLK range"; v: backend.sclkMin > 0 ? backend.sclkMin + "–" + backend.sclkMax + " MHz" : "no overdrive" }
        InfoRow { k: "Clock states"; v: backend.sclkStates.join("  ") }
    }

    component InfoRow: RowLayout {
        property string k
        property string v
        Layout.fillWidth: true
        Text { text: k + ":"; color: "#888"; font.pixelSize: 13; Layout.preferredWidth: 110 }
        Text {
            text: v
            color: "#ddd"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
