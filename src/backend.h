#pragma once

#include <QObject>
#include <QStringList>

// sysfs/amdgpu backend for the Strix Halo-class iGPUs.
// Metrics are world-readable; tuning writes need root (surfaced as errors).
class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double gpuTemp READ gpuTemp NOTIFY metricsChanged)
    Q_PROPERTY(double gpuPower READ gpuPower NOTIFY metricsChanged)
    Q_PROPERTY(int gpuBusy READ gpuBusy NOTIFY metricsChanged)
    Q_PROPERTY(int vcnBusy READ vcnBusy NOTIFY metricsChanged)
    Q_PROPERTY(int sclkMin READ sclkMin NOTIFY odChanged)
    Q_PROPERTY(int sclkMax READ sclkMax NOTIFY odChanged)
    Q_PROPERTY(QString perfLevel READ perfLevel NOTIFY odChanged)
    Q_PROPERTY(QStringList perfLevels READ perfLevels CONSTANT)
    Q_PROPERTY(QStringList sclkStates READ sclkStates NOTIFY odChanged)
    Q_PROPERTY(QString gpuName READ gpuName CONSTANT)

public:
    explicit Backend(QObject *parent = nullptr);

    // parse helpers, static for selftest
    static bool parseOD(const QString &text, int *minMhz, int *maxMhz);
    static QStringList parseSclkStates(const QString &text);

    double gpuTemp() const { return m_temp; }
    double gpuPower() const { return m_power; }
    int gpuBusy() const { return m_busy; }
    int vcnBusy() const { return m_vcn; }
    int sclkMin() const { return m_sclkMin; }
    int sclkMax() const { return m_sclkMax; }
    QString perfLevel() const { return m_perfLevel; }
    QStringList perfLevels() const { return { "auto", "low", "high", "manual" }; }
    QStringList sclkStates() const { return m_sclkStates; }
    QString gpuName() const;

    Q_INVOKABLE void refreshMetrics();
    Q_INVOKABLE void refreshOD();
    Q_INVOKABLE void setPerfLevel(const QString &level);
    Q_INVOKABLE void applySclk(int minMhz, int maxMhz); // "s min\ns max\nc"
    Q_INVOKABLE void resetOverdrive();                  // "r"

signals:
    void metricsChanged();
    void odChanged();
    void error(const QString &msg);

private:
    QString cardDir() const;   // /sys/class/drm/cardN/device with pp_od_clk_voltage
    QString hwmonDir() const;  // /sys/class/hwmon/hwmonN with name == amdgpu
    QString readFile(const QString &path) const;
    bool writeFile(const QString &path, const QString &data);

    double m_temp = 0, m_power = 0;
    int m_busy = 0, m_vcn = 0, m_sclkMin = 0, m_sclkMax = 0;
    QString m_perfLevel;
    QStringList m_sclkStates;
};
