import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#121218"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            text: "Tuning"
            color: "white"
            font.pixelSize: 22
            font.bold: true
        }
        Text {
            text: "Overdrive (pp_od_clk_voltage) — GPU clock range. Writes need root."
            color: "#888"
            font.pixelSize: 12
        }

        RowLayout {
            Text { text: "Min SCLK"; color: "#aaa" }
            Slider {
                id: minSlider
                Layout.fillWidth: true
                from: 400
                to: backend.sclkMax
                value: backend.sclkMin
                stepSize: 10
                enabled: backend.sclkMax > 0
            }
            Text { text: minSlider.value + " MHz"; color: "white"; Layout.preferredWidth: 90 }
        }

        RowLayout {
            Text { text: "Max SCLK"; color: "#aaa" }
            Slider {
                id: maxSlider
                Layout.fillWidth: true
                from: backend.sclkMin
                to: 3200
                value: backend.sclkMax
                stepSize: 10
                enabled: backend.sclkMax > 0
            }
            Text { text: maxSlider.value + " MHz"; color: "white"; Layout.preferredWidth: 90 }
        }

        RowLayout {
            Text { text: "Performance level"; color: "#aaa" }
            ComboBox {
                model: backend.perfLevels
                currentIndex: backend.perfLevels.indexOf(backend.perfLevel)
                onActivated: backend.setPerfLevel(currentText)
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Apply clocks"
                enabled: backend.sclkMax > 0
                onClicked: backend.applySclk(minSlider.value, maxSlider.value)
            }
            Button {
                text: "Reset"
                onClicked: backend.resetOverdrive()
            }
        }

        Text {
            text: "Clock states (pp_dpm_sclk):"
            color: "#aaa"
            font.pixelSize: 12
        }
        Repeater {
            model: backend.sclkStates
            Text {
                text: modelData
                color: modelData.endsWith("*") ? "#ff5b5b" : "#ccc"
                font.pixelSize: 12
            }
        }

        Connections {
            target: backend
            function onError(msg) { errorLabel.text = msg }
        }
        Text {
            id: errorLabel
            color: "#ff5b5b"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
