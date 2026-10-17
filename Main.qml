import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 1280
    height: 760
    minimumWidth: 980
    minimumHeight: 620
    visible: true
    title: qsTr("P150C电子负载仪")
    color: "#f0f0f0"

    DeviceController {
        id: device
    }

    SerialConfigDialog {
        id: configDialog
        parent: Overlay.overlay
        controller: device
    }

    Dialog {
        id: aboutDialog
        title: qsTr("关于软件")
        modal: true
        standardButtons: Dialog.Ok
        anchors.centerIn: parent
        width: 440

        ColumnLayout {
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Image {
                    source: "qrc:/images/icon.png"
                    sourceSize: Qt.size(64, 64)
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                }

                ColumnLayout {
                    spacing: 6
                    Label {
                        text: qsTr("软件名称：P150C电子负载仪")
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Label {
                        text: qsTr("软件版本号：V1.0")
                        font.pixelSize: 14
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    text: qsTr("项目网址：")
                    font.pixelSize: 14
                }
                Label {
                    text: '<a href="https://github.com/igiantpanda/P150C">https://github.com/igiantpanda/P150C</a>'
                    textFormat: Text.RichText
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            GroupBox {
                title: qsTr("绘图显示")
                Layout.fillWidth: true
                Layout.fillHeight: true
                DualAxisChart {
                    anchors.fill: parent
                    times: device.sampleTimes
                    voltages: device.sampleVoltages
                    currents: device.sampleCurrents
                }
            }

            GroupBox {
                title: qsTr("数值显示")
                Layout.preferredWidth: 300
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        color: "#111111"
                        border.color: "#333333"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            Label {
                                text: qsTr("实时电压")
                                color: "#facc15"
                                font.pixelSize: 16
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: device.voltageV.toFixed(3) + " V"
                                color: "#facc15"
                                font.pixelSize: 28
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        color: "#111111"
                        border.color: "#333333"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            Label {
                                text: qsTr("实时电流")
                                color: "#22d3ee"
                                font.pixelSize: 16
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: device.currentA.toFixed(3) + " A"
                                color: "#22d3ee"
                                font.pixelSize: 28
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        color: "#111111"
                        border.color: "#333333"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            Label {
                                text: qsTr("实时功率")
                                color: "#e879f9"
                                font.pixelSize: 16
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: device.powerW.toFixed(4) + " W"
                                color: "#e879f9"
                                font.pixelSize: 28
                                font.bold: true
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 210
            spacing: 8

            GroupBox {
                title: qsTr("信息")
                Layout.fillWidth: true
                Layout.fillHeight: true
                ScrollView {
                    anchors.fill: parent
                    TextArea {
                        id: logArea
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        text: device.logText
                        selectByMouse: true
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: "#c0c0c0"
                        }
                        onTextChanged: cursorPosition = length
                    }
                }
            }

            GroupBox {
                title: qsTr("控制")
                Layout.preferredWidth: 520
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Button {
                            text: qsTr("参数配置")
                            onClicked: configDialog.open()
                        }

                        Item { Layout.fillWidth: true }

                        GroupBox {
                            title: qsTr("状态指示")
                            RowLayout {
                                spacing: 20
                                StatusLamp {
                                    label: qsTr("通讯状态指示")
                                    active: device.connected
                                }
                                StatusLamp {
                                    label: qsTr("运行状态指示")
                                    active: device.running
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Button {
                            text: qsTr("关于软件")
                            onClicked: aboutDialog.open()
                        }

                        Button {
                            text: qsTr("重置")
                            enabled: !device.running
                            onClicked: device.resetData()
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: device.connected ? qsTr("断开设备") : qsTr("连接设备")
                            onClicked: device.toggleConnection()
                        }

                        Button {
                            text: device.running ? qsTr("停止运行") : qsTr("启动运行")
                            enabled: device.connected
                            onClicked: device.toggleRunning()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
