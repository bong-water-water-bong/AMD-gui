import QtQuick
import QtQuick.Controls

// Adrenalin-style rail button: line icon (Canvas), red active bar, tooltip
Item {
    id: root
    property string iconName: "home"   // home|gaming|tuning|performance|display|prefs
    property string tip: ""
    property bool active: false
    property color accent: "#ED1C24"
    width: 72
    height: 56

    signal clicked()

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 28
        radius: 2
        color: root.accent
        visible: root.active
    }

    Canvas {
        id: canvas
        anchors.centerIn: parent
        width: 26
        height: 26
        property color iconColor: root.active ? "#ffffff"
                                              : (hoverArea.containsMouse ? "#e6e6e6" : "#8a8a8a")
        onIconColorChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = iconColor;
            ctx.lineWidth = 1.8;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            switch (root.iconName) {
            case "home":
                ctx.moveTo(3, 12); ctx.lineTo(12, 4.5); ctx.lineTo(21, 12);
                ctx.moveTo(5.5, 10.5); ctx.lineTo(5.5, 20); ctx.lineTo(18.5, 20); ctx.lineTo(18.5, 10.5);
                break;
            case "gaming":
                ctx.moveTo(6, 6.5); ctx.lineTo(18, 6.5); ctx.lineTo(21, 9.5); ctx.lineTo(21, 15);
                ctx.lineTo(18, 18); ctx.lineTo(6, 18); ctx.lineTo(3, 15); ctx.lineTo(3, 9.5); ctx.closePath();
                ctx.moveTo(12, 10); ctx.lineTo(12, 14.5);
                ctx.moveTo(9.5, 12); ctx.lineTo(14.5, 12);
                break;
            case "tuning":
                ctx.moveTo(3, 7); ctx.lineTo(21, 7);
                ctx.moveTo(3, 12); ctx.lineTo(21, 12);
                ctx.moveTo(3, 17); ctx.lineTo(21, 17);
                break;
            case "performance":
                ctx.arc(12, 12, 8.5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 1.6);
                ctx.moveTo(12, 12); ctx.lineTo(16, 8);
                ctx.moveTo(11, 11); ctx.arc(12, 12, 1.4, 0, Math.PI * 2);
                break;
            case "display":
                ctx.moveTo(3, 4.5); ctx.lineTo(21, 4.5); ctx.lineTo(21, 16.5); ctx.lineTo(3, 16.5); ctx.closePath();
                ctx.moveTo(9.5, 20.5); ctx.lineTo(14.5, 20.5);
                ctx.moveTo(12, 16.5); ctx.lineTo(12, 20.5);
                break;
            case "prefs":
                ctx.arc(12, 12, 8, 0, Math.PI * 2);
                ctx.arc(12, 12, 3.6, 0, Math.PI * 2);
                ctx.moveTo(12, 1.5); ctx.lineTo(12, 5);
                ctx.moveTo(12, 19); ctx.lineTo(12, 22.5);
                ctx.moveTo(1.5, 12); ctx.lineTo(5, 12);
                ctx.moveTo(19, 12); ctx.lineTo(22.5, 12);
                break;
            }
            // tuning knobs drawn after lines
            if (root.iconName === "tuning") {
                ctx.moveTo(10.5, 7); ctx.arc(10, 7, 2.6, 0, Math.PI * 2);
                ctx.moveTo(15.5, 12); ctx.arc(15, 12, 2.6, 0, Math.PI * 2);
                ctx.moveTo(8.5, 17); ctx.arc(8, 17, 2.6, 0, Math.PI * 2);
            }
            ctx.stroke();
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    ToolTip {
        text: root.tip
        visible: hoverArea.containsMouse && root.tip !== ""
        delay: 400
    }
}
