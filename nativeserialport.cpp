#include "nativeserialport.h"

NativeSerialPort::NativeSerialPort(QObject *parent)
    : QObject(parent)
{
    m_pollTimer.setInterval(20);
    connect(&m_pollTimer, &QTimer::timeout, this, &NativeSerialPort::poll);
}

NativeSerialPort::~NativeSerialPort()
{
    closePort();
}

bool NativeSerialPort::isOpen() const
{
#ifdef Q_OS_WIN
    return m_handle != INVALID_HANDLE_VALUE;
#else
    return false;
#endif
}

bool NativeSerialPort::setBaudRate(int baudRate)
{
    m_baudRate = baudRate;
    return isOpen() ? applyConfig() : true;
}

bool NativeSerialPort::setDataBits(int dataBits)
{
    if (dataBits < 5 || dataBits > 8)
        return false;
    m_dataBits = dataBits;
    return isOpen() ? applyConfig() : true;
}

bool NativeSerialPort::setParity(int parity)
{
    if (parity < 0 || parity > 4)
        return false;
    m_parity = parity;
    return isOpen() ? applyConfig() : true;
}

bool NativeSerialPort::setStopBits(int stopBits)
{
    if (stopBits != 1 && stopBits != 2 && stopBits != 3)
        return false;
    m_stopBits = stopBits;
    return isOpen() ? applyConfig() : true;
}

bool NativeSerialPort::openPort()
{
#ifdef Q_OS_WIN
    closePort();
    const QString path = m_portName.startsWith(QLatin1String("\\\\.\\"))
                             ? m_portName
                             : QStringLiteral("\\\\.\\") + m_portName;
    m_handle = CreateFileW(reinterpret_cast<LPCWSTR>(path.utf16()),
                           GENERIC_READ | GENERIC_WRITE,
                           0,
                           nullptr,
                           OPEN_EXISTING,
                           0,
                           nullptr);
    if (m_handle == INVALID_HANDLE_VALUE) {
        m_errorString = winError(GetLastError());
        return false;
    }

    COMMTIMEOUTS timeouts {};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.ReadTotalTimeoutConstant = 0;
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 500;
    SetCommTimeouts(m_handle, &timeouts);
    SetupComm(m_handle, 4096, 4096);

    if (!applyConfig()) {
        closePort();
        return false;
    }

    m_rxQueue.clear();
    m_pollTimer.start();
    return true;
#else
    m_errorString = QStringLiteral("当前平台未实现串口");
    return false;
#endif
}

void NativeSerialPort::closePort()
{
    m_pollTimer.stop();
#ifdef Q_OS_WIN
    if (m_handle != INVALID_HANDLE_VALUE) {
        CloseHandle(m_handle);
        m_handle = INVALID_HANDLE_VALUE;
    }
#endif
    m_rxQueue.clear();
}

void NativeSerialPort::clearBuffers()
{
#ifdef Q_OS_WIN
    if (m_handle != INVALID_HANDLE_VALUE)
        PurgeComm(m_handle, PURGE_RXCLEAR | PURGE_TXCLEAR);
#endif
    m_rxQueue.clear();
}

qint64 NativeSerialPort::writeData(const QByteArray &data)
{
#ifdef Q_OS_WIN
    if (m_handle == INVALID_HANDLE_VALUE)
        return -1;
    DWORD written = 0;
    if (!WriteFile(m_handle, data.constData(), static_cast<DWORD>(data.size()), &written, nullptr)) {
        m_errorString = winError(GetLastError());
        emit errorOccurred(m_errorString);
        return -1;
    }
    FlushFileBuffers(m_handle);
    return static_cast<qint64>(written);
#else
    Q_UNUSED(data)
    return -1;
#endif
}

QByteArray NativeSerialPort::readAll()
{
    const QByteArray data = m_rxQueue;
    m_rxQueue.clear();
    return data;
}

QStringList NativeSerialPort::availablePorts()
{
    QStringList names;
#ifdef Q_OS_WIN
    for (int i = 1; i <= 256; ++i) {
        const QString name = QStringLiteral("COM%1").arg(i);
        wchar_t target[256];
        if (QueryDosDeviceW(reinterpret_cast<LPCWSTR>(name.utf16()), target, 256) != 0)
            names.append(name);
    }
#endif
    return names;
}

void NativeSerialPort::poll()
{
#ifdef Q_OS_WIN
    if (m_handle == INVALID_HANDLE_VALUE)
        return;
    DWORD errors = 0;
    COMSTAT status {};
    if (!ClearCommError(m_handle, &errors, &status)) {
        m_errorString = winError(GetLastError());
        emit errorOccurred(m_errorString);
        return;
    }
    if (status.cbInQue == 0)
        return;

    QByteArray chunk(static_cast<int>(status.cbInQue), 0);
    DWORD read = 0;
    if (!ReadFile(m_handle, chunk.data(), static_cast<DWORD>(chunk.size()), &read, nullptr)) {
        m_errorString = winError(GetLastError());
        emit errorOccurred(m_errorString);
        return;
    }
    if (read == 0)
        return;
    chunk.resize(static_cast<int>(read));
    m_rxQueue.append(chunk);
    emit readyRead();
#endif
}

bool NativeSerialPort::applyConfig()
{
#ifdef Q_OS_WIN
    if (m_handle == INVALID_HANDLE_VALUE)
        return true;
    DCB dcb {};
    dcb.DCBlength = sizeof(DCB);
    if (!GetCommState(m_handle, &dcb)) {
        m_errorString = winError(GetLastError());
        return false;
    }
    dcb.BaudRate = static_cast<DWORD>(m_baudRate);
    dcb.ByteSize = static_cast<BYTE>(m_dataBits);
    dcb.fBinary = TRUE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDtrControl = DTR_CONTROL_ENABLE;
    dcb.fRtsControl = RTS_CONTROL_ENABLE;
    dcb.fOutX = FALSE;
    dcb.fInX = FALSE;

    switch (m_parity) {
    case 1:
        dcb.Parity = EVENPARITY;
        dcb.fParity = TRUE;
        break;
    case 2:
        dcb.Parity = ODDPARITY;
        dcb.fParity = TRUE;
        break;
    case 3:
        dcb.Parity = MARKPARITY;
        dcb.fParity = TRUE;
        break;
    case 4:
        dcb.Parity = SPACEPARITY;
        dcb.fParity = TRUE;
        break;
    default:
        dcb.Parity = NOPARITY;
        dcb.fParity = FALSE;
        break;
    }

    switch (m_stopBits) {
    case 2:
        dcb.StopBits = TWOSTOPBITS;
        break;
    case 3:
        dcb.StopBits = ONE5STOPBITS;
        break;
    default:
        dcb.StopBits = ONESTOPBIT;
        break;
    }

    if (!SetCommState(m_handle, &dcb)) {
        m_errorString = winError(GetLastError());
        return false;
    }
    return true;
#else
    return false;
#endif
}

QString NativeSerialPort::winError(DWORD code) const
{
#ifdef Q_OS_WIN
    wchar_t *buffer = nullptr;
    const DWORD len = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                                     nullptr, code, 0, reinterpret_cast<LPWSTR>(&buffer), 0, nullptr);
    QString text = len ? QString::fromWCharArray(buffer).trimmed() : QStringLiteral("错误码 %1").arg(code);
    if (buffer)
        LocalFree(buffer);
    return text;
#else
    Q_UNUSED(code)
    return QStringLiteral("未知错误");
#endif
}
