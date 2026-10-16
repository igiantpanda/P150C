#ifndef NATIVESERIALPORT_H
#define NATIVESERIALPORT_H

#include <QByteArray>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>

#ifdef Q_OS_WIN
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

class NativeSerialPort : public QObject
{
    Q_OBJECT

public:
    explicit NativeSerialPort(QObject *parent = nullptr);
    ~NativeSerialPort() override;

    bool isOpen() const;
    QString errorString() const { return m_errorString; }

    void setPortName(const QString &name) { m_portName = name; }
    bool setBaudRate(int baudRate);
    bool setDataBits(int dataBits);
    bool setParity(int parity); // 0 none, 1 even, 2 odd, 3 mark, 4 space
    bool setStopBits(int stopBits); // 1, 2, 3=1.5

    bool openPort();
    void closePort();
    void clearBuffers();
    qint64 writeData(const QByteArray &data);
    QByteArray readAll();

    static QStringList availablePorts();

signals:
    void readyRead();
    void errorOccurred(const QString &message);

private:
    void poll();
    bool applyConfig();
    QString winError(DWORD code) const;

    QString m_portName;
    QString m_errorString;
    int m_baudRate = 9600;
    int m_dataBits = 8;
    int m_parity = 0;
    int m_stopBits = 1;
    QByteArray m_rxQueue;
    QTimer m_pollTimer;
#ifdef Q_OS_WIN
    HANDLE m_handle = INVALID_HANDLE_VALUE;
#endif
};

#endif
