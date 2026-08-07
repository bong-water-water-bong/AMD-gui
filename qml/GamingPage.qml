import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: page
    color: "#121218"

    function appName(id) {
        for (let i = 0; i < backend.apps.length; ++i)
            if (backend.apps[i].id === id) return backend.apps[i].name
        return "Unknown"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        Text {
            text: "Gaming"
            color: "white"
            font.pixelSize: 22
            font.bold: true
        }
        Text {
            text: "Applications + per-game profiles (persisted in ~/.config/amd-gui/profiles.json)"
            color: "#888"
            font.pixelSize: 12
        }

        TextField {
            id: search
            placeholderText: "Search applications…"
            Layout.fillWidth: true
            color: "white"
            placeholderTextColor: "#666"
            background: Rectangle { color: "#1a1a22"; radius: 6 }
        }

        RowLayout {
            Layout.fillHeight: true
            spacing: 16

            // game list — the GameSearchBar/GameList homage
            ListView {
                id: list
                Layout.fillHeight: true
                Layout.preferredWidth: 320
                clip: true
                model: backend.apps
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    width: list.width
                    height: 44
                    radius: 6
                    color: mouse.containsMouse || list.currentIndex === index ? "#2a2a32" : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: "#ff5b5b"
                            visible: !icon
                            Text {
                                anchors.centerIn: parent
                                text: name.charAt(0).toUpperCase()
                                color: "white"
                                font.bold: true
                            }
                        }
                        Image {
                            source: icon ? "file://" + icon : ""
                            width: 28; height: 28
                            visible: icon !== ""
                        }
                        Text {
                            text: name
                            color: "white"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            list.currentIndex = index
                            backend.selectedApp = id
                        }
                    }
                }
                onModelChanged: {
                    currentIndex = -1
                    backend.selectedApp = ""
                }
            }

            // profile editor for the selected app
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: "#1a1a22"
                radius: 8
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Text {
                        text: backend.selectedApp === ""
                              ? "Select an application"
                              : page.appName(backend.selectedApp)
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    property var profile: backend.selectedApp === ""
                            ? ({}) : backend.appProfile(backend.selectedApp)

                    RowLayout {
                        visible: backend.selectedApp !== ""
                        Text { text: "Perf level while playing"; color: "#aaa" }
                        Item { Layout.fillWidth: true }
                        ComboBox {
                            id: levelBox
                            model: backend.perfLevels
                            currentIndex: Math.max(0, backend.perfLevels.indexOf(
                                parent.parent.profile.perfLevel || "high"))
                        }
                    }

                    RowLayout {
                        visible: backend.selectedApp !== ""
                        Text { text: "GameMode"; color: "#aaa" }
                        Item { Layout.fillWidth: true }
                        Switch {
                            id: gmSwitch
                            checked: parent.parent.profile.gamemode === true
                        }
                    }

                    ColumnLayout {
                        visible: backend.selectedApp !== ""
                        spacing: 6
                        Text { text: "Extra environment (KEY=VALUE …)"; color: "#aaa" }
                        TextField {
                            id: envField
                            Layout.fillWidth: true
                            text: parent.parent.parent.profile.env || ""
                            color: "white"
                            placeholderText: "e.g. DXVK_HUD=fps GPU_MAX_HEAP_SIZE=8192"
                            placeholderTextColor: "#666"
                            background: Rectangle { color: "#121218"; radius: 6 }
                        }
                    }

                    RowLayout {
                        visible: backend.selectedApp !== ""
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "▶  Play"
                            onClicked: backend.launchApp(
                                backend.selectedApp, levelBox.currentText,
                                gmSwitch.checked, envField.text)
                        }
                    }

                    Item { Layout.fillHeight: true }
                    Text {
                        text: "Perf-level writes need root unless the udev rule is installed (scripts/install-permissions.sh)."
                        color: "#666"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
