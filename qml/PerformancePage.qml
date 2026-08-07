import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Performance tab: Metrics | Tuning (Adrenalin sub-tab structure)
Rectangle {
    color: "#141414"
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        Text {
            text: "Performance"
            color: "white"
            font.pixelSize: 20
            font.bold: true
        }

        TabBar {
            id: subTabs
            Layout.fillWidth: true
            background: Rectangle { color: "transparent" }
            TabButton {
                text: "Metrics"
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: subTabs.currentIndex === 0 ? "#ED1C24" : "#8a8a8a"
                    font.bold: subTabs.currentIndex === 0
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            TabButton {
                text: "Tuning"
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: subTabs.currentIndex === 1 ? "#ED1C24" : "#8a8a8a"
                    font.bold: subTabs.currentIndex === 1
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: subTabs.currentIndex

            // ---- Metrics ----
            Rectangle {
                color: "transparent"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Sampling interval"; color: "#9a9a9a" }
                        Slider {
                            id: intervalSlider
                            Layout.fillWidth: true
                            from: 1
                            to: 5
                            stepSize: 1
                            value: 1
                        }
                        Text {
                            text: intervalSlider.value + " s"
                            color: "white"
                            font.bold: true
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Timer {
                        interval: intervalSlider.value * 1000
                        running: true
                        repeat: true
                        onTriggered: backend.refreshMetrics()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16
                        RingGauge { label: "GPU TEMP"; value: backend.gpuTemp; unit: "°C"; max: 110 }
                        RingGauge { label: "GPU POWER"; value: backend.gpuPower; unit: "W"; max: 120 }
                        RingGauge { label: "GPU BUSY"; value: backend.gpuBusy; unit: "%"; max: 100 }
                        RingGauge { label: "VCN BUSY"; value: backend.vcnBusy; unit: "%"; max: 100 }
                    }
                }
            }

            // ---- Tuning ----
            TuningPage {}
        }
    }

    component RingGauge: Rectangle {
        property string label
        property real value
        property string unit
        property real max
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 190
        radius: 12
        color: "#1e1e1e"
        border.color: "#262626"

        Canvas {
            id: ring
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 108
            height: 108
            onPaint: {
                var ctx = getContext("2d");
                var c = width / 2, r = 46;
                ctx.clearRect(0, 0, width, height);
                ctx.lineWidth = 7;
                ctx.lineCap = "round";
                ctx.strokeStyle = "#2c2c2c";
                ctx.beginPath();
                ctx.arc(c, c, r, 0, Math.PI * 2);
                ctx.stroke();
                var frac = max > 0 ? Math.min(value / max, 1) : 0;
                ctx.strokeStyle = frac >= 0.9 ? "#ED1C24" : (frac >= 0.6 ? "#ff8c42" : "#e8e8e8");
                ctx.beginPath();
                ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
                ctx.stroke();
            }
        }
        Text {
            id: valueText
            anchors.centerIn: ring
            text: value.toFixed(1)
            color: "white"
            font.pixelSize: 26
            font.bold: true
        }
        Text {
            anchors.top: valueText.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: valueText.horizontalCenter
            text: unit
            color: "#9a9a9a"
            font.pixelSize: 11
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            text: label
            color: "#8a8a8a"
            font.pixelSize: 11
            font.bold: true
        }

        onValueChanged: ring.requestPaint()
    }
}
