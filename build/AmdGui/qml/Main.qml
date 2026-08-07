import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1100
    height: 720
    visible: true
    title: "AMD-gui — Radeon Software for Linux"

    // the CNext WS panel set (spec/ui-inventory.md); pages without a
    // functional view show the placeholder state
    ListModel {
        id: navModel
        ListElement { name: "Gaming"; icon: "🎮" }
        ListElement { name: "Tuning"; icon: "⚡" }
        ListElement { name: "Performance"; icon: "📊" }
        ListElement { name: "Display"; icon: "🖥️" }
        ListElement { name: "System"; icon: "ℹ️" }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            color: "#1a1a22"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                Text {
                    text: "AMD-gui"
                    color: "#ff5b5b"
                    font.bold: true
                    font.pixelSize: 18
                }
                Text {
                    text: backend.gpuName
                    color: "#888"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: navModel
                    delegate: Button {
                        Layout.fillWidth: true
                        text: icon + "  " + name
                        flat: true
                        highlighted: navView.currentIndex === index
                        onClicked: navView.currentIndex = index
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    text: backend.perfLevel + " · " + backend.gpuTemp.toFixed(0) + "°C"
                    color: "#888"
                    font.pixelSize: 11
                }
            }
        }

        StackLayout {
            id: navView
            Layout.fillWidth: true
            Layout.fillHeight: true

            PlaceholderPage { pageName: "Gaming" }
            TuningPage {}
            PerformancePage {}
            PlaceholderPage { pageName: "Display" }
            SystemPage {}
        }
    }

    component PlaceholderPage: Rectangle {
        property string pageName
        color: "#121218"
        Text {
            anchors.centerIn: parent
            color: "#666"
            font.pixelSize: 16
            text: pageName + " — not implemented yet"
        }
    }
}
