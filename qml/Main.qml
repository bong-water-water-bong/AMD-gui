import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1200
    height: 780
    visible: true
    color: "#141414"
    title: "AMD-gui — Radeon Software for Linux"

    ListModel {
        id: navModel
        ListElement { name: "home"; tip: "Home" }
        ListElement { name: "gaming"; tip: "Gaming" }
        ListElement { name: "performance"; tip: "Performance" }
        ListElement { name: "prefs"; tip: "Settings" }
    }

    RowLayout {
        spacing: 0
        anchors.fill: parent

        // icon rail
        Rectangle {
            Layout.preferredWidth: 72
            Layout.fillHeight: true
            color: "#1b1b1b"
            ColumnLayout {
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 34
                    height: 34
                    radius: 9
                    color: "#ED1C24"
                    Text {
                        anchors.centerIn: parent
                        text: "A"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 19
                    }
                }
                Item { height: 14 }

                Repeater {
                    model: navModel
                    delegate: IconButton {
                        iconName: name
                        tip: tip
                        active: stack.currentIndex === index
                        onClicked: stack.currentIndex = index
                    }
                }
            }
        }

        // content
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            HomePage {}
            GamingPage {}
            PerformancePage {}
            SystemPage {}
            Component.onCompleted: {
                var a = Qt.application.arguments
                for (var i = 0; i < a.length; ++i)
                    if (a[i] === "--page")
                        stack.currentIndex = parseInt(a[i + 1])
            }
        }
    }
}
