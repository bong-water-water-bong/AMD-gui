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
