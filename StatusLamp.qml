import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    id: root
    spacing: 8

    property string label: ""
    property bool active: false

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: root.active ? "#22c55e" : "#ef4444"
        border.color: "#333333"
        Layout.alignment: Qt.AlignVCenter
    }

    Label {
        text: root.label
        color: "#222222"
        Layout.alignment: Qt.AlignVCenter
    }
}
