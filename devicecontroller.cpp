#include "devicecontroller.h"

#include <QDateTime>

namespace {
const QByteArray kQueryFrame = QByteArray::fromHex("010300000008440C");
constexpr int kMinFrameSize = 21;
constexpr int kResponseTimeoutMs = 1500;
constexpr int kSampleIntervalMs = 5000;
}

DeviceController::DeviceController(QObject *parent)
    : QObject(parent)
{
    m_sampleTimer.setInterval(kSampleIntervalMs);
    m_responseTimer.setSingleShot(true);
    m_responseTimer.setInterval(kResponseTimeoutMs);

    connect(&m_serial, &NativeSerialPort::readyRead, this, &DeviceController::onReadyRead);
    connect(&m_serial, &NativeSerialPort::errorOccurred, this, &DeviceController::onSerialError);
    connect(&m_sampleTimer, &QTimer::timeout, this, &DeviceController::onSampleTimer);
    connect(&m_responseTimer, &QTimer::timeout, this, &DeviceController::onResponseTimeout);

    const QStringList ports = availablePorts();
    if (!ports.isEmpty())
        m_portName = ports.first();

    appendLog(QStringLiteral("请先配置端口号"));
}

DeviceController::~DeviceController()
{
    stopRunningInternal();
    closePort();
}

void DeviceController::setPortName(const QString &portName)
{
    if (m_portName == portName)
        return;
    m_portName = portName;
    emit serialConfigChanged();
}

void DeviceController::setBaudRate(int baudRate)
{
    if (m_baudRate == baudRate)
        return;
    m_baudRate = baudRate;
    emit serialConfigChanged();
}

void DeviceController::setDataBits(int dataBits)
{
    if (m_dataBits == dataBits)
        return;
    m_dataBits = dataBits;
    emit serialConfigChanged();
}

void DeviceController::setParity(int parity)
{
    if (m_parity == parity)
        return;
    m_parity = parity;
    emit serialConfigChanged();
}

void DeviceController::setStopBits(int stopBits)
{
    if (m_stopBits == stopBits)
        return;
    m_stopBits = stopBits;
    emit serialConfigChanged();
}

QStringList DeviceController::availablePorts() const
{
    return NativeSerialPort::availablePorts();
}

void DeviceController::toggleConnection()
{
    if (m_connected) {
        stopRunningInternal();
        closePort();
        setConnected(false);
        appendLog(QStringLiteral("断开设备成功"));
        return;
    }

    if (m_portName.isEmpty()) {
        appendLog(QStringLiteral("连接设备失败：未选择串口"));
        return;
    }

    if (m_serial.isOpen())
        closePort();

    m_serial.setPortName(m_portName);
    if (!applySerialSettings()) {
        appendLog(QStringLiteral("连接设备失败：串口参数无效"));
        return;
    }

    if (!m_serial.openPort()) {
        appendLog(QStringLiteral("连接设备失败：无法打开 %1（%2）")
                      .arg(m_portName, m_serial.errorString()));
        return;
    }

    m_serial.clearBuffers();
    m_rxBuffer.clear();
    sendQuery(PendingRequest::Probe);
}

void DeviceController::toggleRunning()
{
    if (!m_connected) {
        appendLog(QStringLiteral("请先连接设备"));
        return;
    }

    if (m_running) {
        stopRunningInternal();
        appendLog(QStringLiteral("已停止运行"));
        return;
    }

    m_sampleTimes.clear();
    m_sampleVoltages.clear();
    m_sampleCurrents.clear();
    m_runStartMs = QDateTime::currentMSecsSinceEpoch();
    m_running = true;
    emit runningChanged();
    emit chartDataChanged();
    appendLog(QStringLiteral("已启动运行，每 5 秒读取一次电压电流"));
    sendQuery(PendingRequest::Sample);
    m_sampleTimer.start();
}

void DeviceController::appendLog(const QString &message)
{
    const QString line = QStringLiteral("【%1】%2")
                             .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy/MM/dd HH:mm:ss")),
                                  message);
    if (m_logText.isEmpty())
        m_logText = line;
    else
        m_logText += QLatin1Char('\n') + line;
    emit logTextChanged();
}

bool DeviceController::applySerialSettings()
{
    if (!m_serial.setBaudRate(m_baudRate))
        return false;
    if (!m_serial.setDataBits(m_dataBits))
        return false;
    if (!m_serial.setParity(m_parity))
        return false;
    if (!m_serial.setStopBits(m_stopBits))
        return false;
    return true;
}

void DeviceController::sendQuery(PendingRequest reason)
{
    if (!m_serial.isOpen())
        return;
    if (m_pending != PendingRequest::None)
        return;

    m_rxBuffer.clear();
    m_pending = reason;
    const qint64 written = m_serial.writeData(kQueryFrame);
    if (written != kQueryFrame.size()) {
        finishPending(false, QStringLiteral("写入串口失败"));
        return;
    }
    m_responseTimer.start();
}

void DeviceController::onReadyRead()
{
    m_rxBuffer.append(m_serial.readAll());
    if (m_pending == PendingRequest::None)
        return;
    if (m_rxBuffer.size() < kMinFrameSize)
        return;

    double voltage = 0.0;
    double current = 0.0;
    if (!parseMeasurement(m_rxBuffer, &voltage, &current)) {
        finishPending(false, QStringLiteral("返回数据格式错误"));
        return;
    }

    m_voltageV = voltage;
    m_currentA = current;
    m_powerW = voltage * current;
    emit measurementChanged();

    if (m_pending == PendingRequest::Sample && m_running) {
        const double elapsedSec = (QDateTime::currentMSecsSinceEpoch() - m_runStartMs) / 1000.0;
        m_sampleTimes.append(elapsedSec);
        m_sampleVoltages.append(voltage);
        m_sampleCurrents.append(current);
        emit chartDataChanged();
    }

    finishPending(true, {});
}

void DeviceController::onSerialError(const QString &message)
{
    if (m_suppressSerialError)
        return;
    if (!m_serial.isOpen() && !m_connected)
        return;

    if (m_pending != PendingRequest::None)
        finishPending(false, message);

    if (m_connected) {
        stopRunningInternal();
        closePort();
        setConnected(false);
        appendLog(QStringLiteral("串口异常，已断开：%1").arg(message));
    }
}

void DeviceController::onResponseTimeout()
{
    if (m_pending == PendingRequest::None)
        return;
    finishPending(false, QStringLiteral("设备无应答"));
}

void DeviceController::onSampleTimer()
{
    if (!m_running || !m_connected)
        return;
    sendQuery(PendingRequest::Sample);
}

bool DeviceController::parseMeasurement(const QByteArray &frame, double *voltageV, double *currentA) const
{
    if (frame.size() < kMinFrameSize || voltageV == nullptr || currentA == nullptr)
        return false;
    if (static_cast<quint8>(frame[0]) != 0x01 || static_cast<quint8>(frame[1]) != 0x03)
        return false;

    const int byteCount = static_cast<quint8>(frame[2]);
    if (byteCount < 16)
        return false;
    if (frame.size() < 3 + byteCount)
        return false;

    const quint16 rawVoltage = (static_cast<quint8>(frame[15]) << 8)
                               | static_cast<quint8>(frame[16]);
    const quint16 rawCurrent = (static_cast<quint8>(frame[17]) << 8)
                               | static_cast<quint8>(frame[18]);
    *voltageV = (rawVoltage * 10.0) / 1000.0;
    *currentA = rawCurrent / 1000.0;
    return true;
}

void DeviceController::finishPending(bool success, const QString &failReason)
{
    const PendingRequest reason = m_pending;
    m_pending = PendingRequest::None;
    m_responseTimer.stop();
    m_rxBuffer.clear();

    if (reason == PendingRequest::Probe) {
        if (success) {
            setConnected(true);
            appendLog(QStringLiteral("连接设备成功"));
        } else {
            closePort();
            setConnected(false);
            appendLog(QStringLiteral("连接设备失败：%1").arg(failReason));
        }
        return;
    }

    if (reason == PendingRequest::Sample && !success)
        appendLog(QStringLiteral("读取数据失败：%1").arg(failReason));
}

void DeviceController::setConnected(bool connected)
{
    if (m_connected == connected)
        return;
    m_connected = connected;
    emit connectedChanged();
}

void DeviceController::stopRunningInternal()
{
    m_sampleTimer.stop();
    if (!m_running)
        return;
    m_running = false;
    emit runningChanged();
}

void DeviceController::closePort()
{
    m_pending = PendingRequest::None;
    m_responseTimer.stop();
    m_rxBuffer.clear();
    m_suppressSerialError = true;
    m_serial.closePort();
    m_suppressSerialError = false;
}
