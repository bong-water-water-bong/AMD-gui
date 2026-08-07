import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: "#141414"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text {
            text: "Tuning"
            color: "white"
            font.pixelSize: 20
            font.bold: true
        }
        Text {
            text: "Overdrive (pp_od_clk_voltage) — GPU clock range on the Strix Halo"
            color: "#9a9a9a"
            font.pixelSize: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#1e1e1e"
            border.color: "#262626"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 18

                // segmented Default/Custom
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 240
                    height: 34
                    radius: 17
                    color: "#141414"
                    RowLayout {
                        anchors.fill: parent
                        spacing: 2
                        SegButton {
                            text: "Default"
                            on: !customSwitch.checked
                            onClicked: {
                                customSwitch.checked = false
                                backend.setPerfLevel("auto")
                            }
                        }
                        SegButton {
                            text: "Custom"
                            on: customSwitch.checked
                            onClicked: customSwitch.checked = true
                        }
                    }
                }

                // Adrenalin presets: Quiet / Balanced / Rage -> low / auto / high
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    PresetButton { text: "Quiet"; level: "low"; desc: "Least noise, least performance" }
                    PresetButton { text: "Balanced"; level: "auto"; desc: "Default power management" }
                    PresetButton { text: "Rage"; level: "high"; desc: "Maximum performance" }
                }

                // clock sliders
                RowLayout {
                    Text {
                        text: "Min SCLK"
                        color: "#9a9a9a"
                        Layout.preferredWidth: 70
                    }
                    Slider {
                        id: minSlider
                        Layout.fillWidth: true
                        from: 400
                        to: backend.sclkMax
                        value: backend.sclkMin
                        stepSize: 10
                        enabled: customSwitch.checked && backend.sclkMax > 0
                        onMoved: minValue.text = value + " MHz"
                    }
                    Text {
                        id: minValue
                        text: backend.sclkMin + " MHz"
                        color: "white"
                        font.bold: true
                        Layout.preferredWidth: 90
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Text {
                        text: "Max SCLK"
                        color: "#9a9a9a"
                        Layout.preferredWidth: 70
                    }
                    Slider {
                        id: maxSlider
                        Layout.fillWidth: true
                        from: backend.sclkMin
                        to: 3200
                        value: backend.sclkMax
                        stepSize: 10
                        enabled: customSwitch.checked && backend.sclkMax > 0
                        onMoved: maxValue.text = value + " MHz"
                    }
                    Text {
                        id: maxValue
                        text: backend.sclkMax + " MHz"
                        color: "white"
                        font.bold: true
                        Layout.preferredWidth: 90
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // perf level + apply
                RowLayout {
                    Text {
                        text: "Performance level"
                        color: "#9a9a9a"
                    }
                    ComboBox {
                        model: backend.perfLevels
                        currentIndex: Math.max(0, backend.perfLevels.indexOf(backend.perfLevel))
                        onActivated: backend.setPerfLevel(currentText)
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: "Apply clocks"
                        enabled: customSwitch.checked && backend.sclkMax > 0
                        onClicked: backend.applySclk(minSlider.value, maxSlider.value)
                    }
                    Button {
                        text: "Reset"
                        onClicked: backend.resetOverdrive()
                    }
                }

                // clock states
                Text {
                    text: "Clock states (pp_dpm_sclk):"
                    color: "#9a9a9a"
                    font.pixelSize: 12
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: backend.sclkStates
                        Rectangle {
                            height: 26
                            radius: 13
                            color: modelData.endsWith("*") ? "#2e1618" : "#242424"
                            border.color: modelData.endsWith("*") ? "#ED1C24" : "#2e2e2e"
                            Text {
                                anchors.centerIn: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: modelData
                                color: modelData.endsWith("*") ? "#ff5a5a" : "#ccc"
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Connections {
                    target: backend
                    function onError(msg) { errorLabel.text = msg }
                }
                Text {
                    id: errorLabel
                    color: "#ED1C24"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    component SegButton: Rectangle {
        property string text
        property bool on
        signal clicked()
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 15
        color: on ? "#ED1C24" : "transparent"
        Text {
            anchors.centerIn: parent
            text: parent.text
            color: on ? "white" : "#9a9a9a"
            font.pixelSize: 12
            font.bold: on
        }
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    component PresetButton: Rectangle {
        property string text
        property string level
        property string desc
        Layout.fillWidth: true
        implicitHeight: 54
        radius: 10
        color: backend.perfLevel === level ? "#2e1618" : "#242424"
        border.color: backend.perfLevel === level ? "#ED1C24" : "#2e2e2e"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2
            Text {
                text: parent.parent.text
                color: backend.perfLevel === parent.parent.level ? "#ff5a5a" : "white"
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                text: parent.parent.desc
                color: "#9a9a9a"
                font.pixelSize: 10
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.setPerfLevel(parent.level)
        }
    }

    // invisible switch driving the segmented control
    Switch {
        id: customSwitch
        visible: false
    }
}
