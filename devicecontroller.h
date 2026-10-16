#ifndef DEVICECONTROLLER_H
#define DEVICECONTROLLER_H

#include "nativeserialport.h"

#include <QByteArray>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class DeviceController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(double voltageV READ voltageV NOTIFY measurementChanged)
    Q_PROPERTY(double currentA READ currentA NOTIFY measurementChanged)
    Q_PROPERTY(double powerW READ powerW NOTIFY measurementChanged)
    Q_PROPERTY(QString logText READ logText NOTIFY logTextChanged)
    Q_PROPERTY(QVariantList sampleTimes READ sampleTimes NOTIFY chartDataChanged)
    Q_PROPERTY(QVariantList sampleVoltages READ sampleVoltages NOTIFY chartDataChanged)
    Q_PROPERTY(QVariantList sampleCurrents READ sampleCurrents NOTIFY chartDataChanged)
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY serialConfigChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY serialConfigChanged)
    Q_PROPERTY(int dataBits READ dataBits WRITE setDataBits NOTIFY serialConfigChanged)
    Q_PROPERTY(int parity READ parity WRITE setParity NOTIFY serialConfigChanged)
    Q_PROPERTY(int stopBits READ stopBits WRITE setStopBits NOTIFY serialConfigChanged)

public:
    explicit DeviceController(QObject *parent = nullptr);
    ~DeviceController() override;

    bool connected() const { return m_connected; }
    bool running() const { return m_running; }
    double voltageV() const { return m_voltageV; }
    double currentA() const { return m_currentA; }
    double powerW() const { return m_powerW; }
    QString logText() const { return m_logText; }
    QVariantList sampleTimes() const { return m_sampleTimes; }
    QVariantList sampleVoltages() const { return m_sampleVoltages; }
    QVariantList sampleCurrents() const { return m_sampleCurrents; }

    QString portName() const { return m_portName; }
    void setPortName(const QString &portName);
    int baudRate() const { return m_baudRate; }
    void setBaudRate(int baudRate);
    int dataBits() const { return m_dataBits; }
    void setDataBits(int dataBits);
    int parity() const { return m_parity; }
    void setParity(int parity);
    int stopBits() const { return m_stopBits; }
    void setStopBits(int stopBits);

    Q_INVOKABLE QStringList availablePorts() const;
    Q_INVOKABLE void toggleConnection();
    Q_INVOKABLE void toggleRunning();

signals:
    void connectedChanged();
    void runningChanged();
    void measurementChanged();
    void logTextChanged();
    void chartDataChanged();
    void serialConfigChanged();

private:
    enum class PendingRequest { None, Probe, Sample };

    void appendLog(const QString &message);
    bool applySerialSettings();
    void sendQuery(PendingRequest reason);
    void onReadyRead();
    void onSerialError(const QString &message);
    void onResponseTimeout();
    void onSampleTimer();
    bool parseMeasurement(const QByteArray &frame, double *voltageV, double *currentA) const;
    void finishPending(bool success, const QString &failReason);
    void setConnected(bool connected);
    void stopRunningInternal();
    void closePort();

    NativeSerialPort m_serial;
    QTimer m_sampleTimer;
    QTimer m_responseTimer;
    QByteArray m_rxBuffer;
    PendingRequest m_pending = PendingRequest::None;

    bool m_connected = false;
    bool m_running = false;
    bool m_suppressSerialError = false;
    double m_voltageV = 0.0;
    double m_currentA = 0.0;
    double m_powerW = 0.0;
    QString m_logText;
    QVariantList m_sampleTimes;
    QVariantList m_sampleVoltages;
    QVariantList m_sampleCurrents;
    qint64 m_runStartMs = 0;

    QString m_portName;
    int m_baudRate = 9600;
    int m_dataBits = 8;
    int m_parity = 0;
    int m_stopBits = 1;
};

#endif
