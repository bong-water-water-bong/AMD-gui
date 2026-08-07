import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Gaming tab: Games | Graphics | Display (Adrenalin sub-tab structure)
Rectangle {
    id: page
    color: "#141414"

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
            font.pixelSize: 20
            font.bold: true
        }

        TabBar {
            id: subTabs
            Layout.fillWidth: true
            background: Rectangle { color: "transparent" }
            TabButton {
                text: "Games"
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: subTabs.currentIndex === 0 ? "#ED1C24" : "#8a8a8a"
                    font.bold: subTabs.currentIndex === 0
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            TabButton {
                text: "Graphics"
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: subTabs.currentIndex === 1 ? "#ED1C24" : "#8a8a8a"
                    font.bold: subTabs.currentIndex === 1
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            TabButton {
                text: "Display"
                background: Rectangle { color: "transparent" }
                contentItem: Text {
                    text: parent.text
                    color: subTabs.currentIndex === 2 ? "#ED1C24" : "#8a8a8a"
                    font.bold: subTabs.currentIndex === 2
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        StackLayout {
            id: subStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: subTabs.currentIndex

            // ---- Games ----
            GamesView {}
            // ---- Graphics ----
            GraphicsView {}
            // ---- Display ----
            DisplayPage {}
        }
    }

    // ---------- Games: app list + per-app profiles ----------
    component GamesView: Rectangle {
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

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
                background: Rectangle { color: "#1e1e1e"; radius: 6 }
            }

            RowLayout {
                Layout.fillHeight: true
                spacing: 16

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
                        color: mouse.containsMouse || list.currentIndex === index ? "#2a2a2a" : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: "#ED1C24"
                                visible: !modelData.icon
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name.charAt(0).toUpperCase()
                                    color: "white"
                                    font.bold: true
                                }
                            }
                            Image {
                                source: modelData.icon ? "file://" + modelData.icon : ""
                                width: 28; height: 28
                                visible: modelData.icon !== ""
                            }
                            Text {
                                text: modelData.name
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
                                backend.selectedApp = modelData.id
                            }
                        }
                    }
                    onModelChanged: {
                        currentIndex = -1
                        backend.selectedApp = ""
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    color: "#1e1e1e"
                    radius: 8
                    ColumnLayout {
                        id: editorCol
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
                                    editorCol.profile.perfLevel || "high"))
                            }
                        }

                        RowLayout {
                            visible: backend.selectedApp !== ""
                            Text { text: "GameMode"; color: "#aaa" }
                            Item { Layout.fillWidth: true }
                            Switch {
                                id: gmSwitch
                                checked: editorCol.profile.gamemode === true
                            }
                        }

                        ColumnLayout {
                            visible: backend.selectedApp !== ""
                            spacing: 6
                            Text { text: "Extra environment (KEY=VALUE …)"; color: "#aaa" }
                            TextField {
                                id: envField
                                Layout.fillWidth: true
                                text: editorCol.profile.env || ""
                                color: "white"
                                placeholderText: "e.g. DXVK_HUD=fps GPU_MAX_HEAP_SIZE=8192"
                                placeholderTextColor: "#666"
                                background: Rectangle { color: "#141414"; radius: 6 }
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

    // ---------- Graphics: feature matrix with Linux status ----------
    component GraphicsView: Rectangle {
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                text: "Global graphics — AMD feature → Linux equivalent"
                color: "#888"
                font.pixelSize: 12
            }

            ListModel {
                id: gfxModel
                ListElement { feature: "Radeon Super Resolution"; what: "Upscaling"; linux: "gamescope / FSR"; status: "available" }
                ListElement { feature: "Radeon Anti-Lag"; what: "Input latency reduction"; linux: "RADV option (VK_EXT_late_acquire)"; status: "partial" }
                ListElement { feature: "Radeon Boost"; what: "Dynamic res scaling"; linux: "—"; status: "missing" }
                ListElement { feature: "Radeon Chill"; what: "Power saving frame cap"; linux: "—"; status: "missing" }
                ListElement { feature: "Radeon Image Sharpening"; what: "Sharpening filter"; linux: "gamescope"; status: "available" }
                ListElement { feature: "Enhanced Sync"; what: "Anti-tearing"; linux: "compositor vsync"; status: "partial" }
                ListElement { feature: "Fluid Motion Frames"; what: "Frame generation"; linux: "—"; status: "missing" }
                ListElement { feature: "Frame Rate Target Control"; what: "Max FPS cap"; linux: "MangoHud / gamescope"; status: "available" }
                ListElement { feature: "FreeSync"; what: "Adaptive sync"; linux: "KMS VRR property"; status: "partial" }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: gfxModel
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    width: parent.width
                    height: 52
                    radius: 8
                    color: "#1e1e1e"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12
                        Text {
                            text: feature
                            color: "white"
                            font.bold: true
                            Layout.preferredWidth: 240
                        }
                        Text {
                            text: what
                            color: "#9a9a9a"
                            Layout.fillWidth: true
                        }
                        Text {
                            text: linux
                            color: "#ccc"
                            Layout.preferredWidth: 260
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            color: status === "available" ? "#6fdc8c"
                                 : (status === "partial" ? "#ffb347" : "#666")
                        }
                    }
                }
            }
        }
    }
}
