import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: qsTr("参数配置")
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    anchors.centerIn: parent
    width: 380

    required property var controller

    property int pendingBaud: 9600
    property int pendingDataBits: 8
    property int pendingParity: 0
    property int pendingStopBits: 1

    ListModel { id: portModel }

    function reloadPorts() {
        const current = controller.portName
        portModel.clear()
        const ports = controller.availablePorts()
        let nextIndex = -1
        for (let i = 0; i < ports.length; ++i) {
            portModel.append({ name: ports[i] })
            if (ports[i] === current)
                nextIndex = i
        }
        portBox.currentIndex = nextIndex
    }

    onAboutToShow: {
        pendingBaud = controller.baudRate
        pendingDataBits = controller.dataBits
        pendingParity = controller.parity
        pendingStopBits = controller.stopBits
        baudBox.currentIndex = Math.max(0, baudBox.model.indexOf(pendingBaud))
        dataBox.currentIndex = Math.max(0, dataBox.model.indexOf(pendingDataBits))
        parityBox.currentIndex = pendingParity
        if (pendingStopBits === 3)
            stopBox.currentIndex = 1
        else if (pendingStopBits === 2)
            stopBox.currentIndex = 2
        else
            stopBox.currentIndex = 0
        reloadPorts()
    }

    onAccepted: {
        if (portBox.currentIndex >= 0)
            controller.portName = portModel.get(portBox.currentIndex).name
        controller.baudRate = pendingBaud
        controller.dataBits = pendingDataBits
        controller.parity = pendingParity
        controller.stopBits = pendingStopBits
        controller.persistSerialConfig()
    }

    GridLayout {
        anchors.fill: parent
        columns: 3
        columnSpacing: 8
        rowSpacing: 10

        Label { text: qsTr("端口") }
        ComboBox {
            id: portBox
            Layout.fillWidth: true
            model: portModel
            textRole: "name"
            enabled: !controller.connected
        }
        Button {
            text: qsTr("刷新")
            enabled: !controller.connected
            onClicked: root.reloadPorts()
        }

        Label { text: qsTr("波特率") }
        ComboBox {
            id: baudBox
            Layout.fillWidth: true
            Layout.columnSpan: 2
            enabled: !controller.connected
            model: [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200]
            onActivated: root.pendingBaud = Number(currentText)
        }

        Label { text: qsTr("数据位") }
        ComboBox {
            id: dataBox
            Layout.fillWidth: true
            Layout.columnSpan: 2
            enabled: !controller.connected
            model: [8, 7, 6, 5]
            onActivated: root.pendingDataBits = Number(currentText)
        }

        Label { text: qsTr("校验位") }
        ComboBox {
            id: parityBox
            Layout.fillWidth: true
            Layout.columnSpan: 2
            enabled: !controller.connected
            model: [qsTr("无"), qsTr("偶校验"), qsTr("奇校验"), qsTr("标记"), qsTr("空格")]
            onActivated: root.pendingParity = currentIndex
        }

        Label { text: qsTr("停止位") }
        ComboBox {
            id: stopBox
            Layout.fillWidth: true
            Layout.columnSpan: 2
            enabled: !controller.connected
            model: ["1", "1.5", "2"]
            onActivated: {
                if (currentIndex === 1)
                    root.pendingStopBits = 3
                else if (currentIndex === 2)
                    root.pendingStopBits = 2
                else
                    root.pendingStopBits = 1
            }
        }
    }
}
