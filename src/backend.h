#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QHash>
#include <QElapsedTimer>

// sysfs/amdgpu backend for the Strix Halo-class iGPUs.
// Metrics are world-readable; tuning writes need root (surfaced as errors).
class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double gpuTemp READ gpuTemp NOTIFY metricsChanged)
    Q_PROPERTY(double junctionTemp READ junctionTemp NOTIFY metricsChanged)
    Q_PROPERTY(double memTemp READ memTemp NOTIFY metricsChanged)
    Q_PROPERTY(int fanRpm READ fanRpm NOTIFY metricsChanged)
    Q_PROPERTY(double gpuPower READ gpuPower NOTIFY metricsChanged)
    Q_PROPERTY(int gpuBusy READ gpuBusy NOTIFY metricsChanged)
    Q_PROPERTY(int vcnBusy READ vcnBusy NOTIFY metricsChanged)
    Q_PROPERTY(int memBusy READ memBusy NOTIFY metricsChanged)
    Q_PROPERTY(double vramUsedGB READ vramUsedGB NOTIFY metricsChanged)
    Q_PROPERTY(double vramPct READ vramPct NOTIFY metricsChanged)
    Q_PROPERTY(QVariantList gpuProcesses READ gpuProcesses NOTIFY gpuProcessesChanged)
    Q_PROPERTY(int powerCap READ powerCap NOTIFY metricsChanged)
    Q_PROPERTY(int powerCapMin READ powerCapMin NOTIFY metricsChanged)
    Q_PROPERTY(int powerCapMax READ powerCapMax NOTIFY metricsChanged)
    Q_PROPERTY(double vramGB READ vramGB CONSTANT)
    Q_PROPERTY(int sclkMin READ sclkMin NOTIFY odChanged)
    Q_PROPERTY(int sclkMax READ sclkMax NOTIFY odChanged)
    Q_PROPERTY(QString perfLevel READ perfLevel NOTIFY odChanged)
    Q_PROPERTY(QStringList perfLevels READ perfLevels CONSTANT)
    Q_PROPERTY(QStringList sclkStates READ sclkStates NOTIFY odChanged)
    Q_PROPERTY(QString gpuName READ gpuName CONSTANT)
    Q_PROPERTY(QString kernelVersion READ kernelVersion CONSTANT)
    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)
    Q_PROPERTY(QVariantList screens READ screens NOTIFY screensChanged)
    Q_PROPERTY(QVariantList connectors READ connectors NOTIFY connectorsChanged)
    Q_PROPERTY(QString selectedApp READ selectedApp WRITE setSelectedApp NOTIFY selectionChanged)
    Q_PROPERTY(int nightLightTemp READ nightLightTemp NOTIFY nightLightChanged)
    Q_PROPERTY(bool nightLightEnabled READ nightLightEnabled NOTIFY nightLightChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    // parse helpers, static for selftest
    static bool parseOD(const QString &text, int *minMhz, int *maxMhz);
    static QStringList parseSclkStates(const QString &text);
    static QVariantMap parseDesktopFile(const QString &path); // Name/Icon/Exec from [Desktop Entry]

    double gpuTemp() const { return m_temp; }
    double junctionTemp() const { return m_junction; }
    double memTemp() const { return m_mem; }
    int fanRpm() const { return m_fan; }
    double gpuPower() const { return m_power; }
    int gpuBusy() const { return m_busy; }
    int vcnBusy() const { return m_vcn; }
    int memBusy() const { return m_memBusy; }
    double vramUsedGB() const { return m_vramUsedBytes / (1024.0 * 1024 * 1024); }
    double vramPct() const { return m_vramGB > 0 ? m_vramUsedBytes / (m_vramGB * 1024 * 1024 * 1024) * 100.0 : 0; }
    QVariantList gpuProcesses() const { return m_gpuProcesses; }
    int powerCap() const { return m_powerCap; }
    int powerCapMin() const { return m_powerCapMin; }
    int powerCapMax() const { return m_powerCapMax; }
    double vramGB() const { return m_vramGB; }
    int sclkMin() const { return m_sclkMin; }
    int sclkMax() const { return m_sclkMax; }
    QString perfLevel() const { return m_perfLevel; }
    QStringList perfLevels() const { return { "auto", "low", "high", "manual" }; }
    QStringList sclkStates() const { return m_sclkStates; }
    QString gpuName() const;
    QString kernelVersion() const;
    QVariantList apps() const { return m_apps; }
    QVariantList screens() const { return m_screens; }
    QVariantList connectors() const { return m_connectors; }
    QString selectedApp() const { return m_selectedApp; }
    void setSelectedApp(const QString &id);
    int nightLightTemp() const { return m_nlTemp; }
    bool nightLightEnabled() const { return m_nlEnabled; }
    void setNightLightTemp(int kelvin);
    void setNightLightEnabled(bool on);

    Q_INVOKABLE void refreshMetrics();
    Q_INVOKABLE void refreshOD();
    Q_INVOKABLE void setPowerCap(int watts); // board power limit (power1_cap, µW)
    Q_INVOKABLE void setPerfLevel(const QString &level);
    Q_INVOKABLE void applySclk(int minMhz, int maxMhz); // "s min\ns max\nc"
    Q_INVOKABLE void resetOverdrive();                  // "r"
    Q_INVOKABLE void refreshApps();
    Q_INVOKABLE void refreshScreens();
    Q_INVOKABLE void refreshGpuProcesses(); // per-process fdinfo table
    static qint64 parseEngineNs(const QString &line); // "drm-engine-gfx:\t123 ns"
    Q_INVOKABLE QVariantMap appProfile(const QString &id); // from profiles.json
    Q_INVOKABLE void launchApp(const QString &id, const QString &perfLevel,
                               bool gamemode, const QString &env);

signals:
    void metricsChanged();
    void odChanged();
    void gpuProcessesChanged();
    void error(const QString &msg);
    void appsChanged();
    void screensChanged();
    void connectorsChanged();
    void selectionChanged();
    void nightLightChanged();

private:
    QString cardDir() const;   // /sys/class/drm/cardN/device with pp_od_clk_voltage
    QString hwmonDir() const;  // /sys/class/hwmon/hwmonN with name == amdgpu
    QString readFile(const QString &path) const;
    bool writeFile(const QString &path, const QString &data);
    QString profilesPath() const;
    QVariantMap profiles() const;
    void saveProfiles(const QVariantMap &all);
    QString execLine(const QVariantMap &app) const; // Exec with field codes stripped
    void refreshNightLight();

    double m_temp = 0, m_junction = 0, m_mem = 0, m_power = 0;
    int m_fan = 0, m_busy = 0, m_vcn = 0, m_memBusy = 0, m_sclkMin = 0, m_sclkMax = 0;
    int m_powerCap = 0, m_powerCapMin = 0, m_powerCapMax = 0;
    double m_vramGB = 0, m_vramUsedBytes = 0;
    QString m_perfLevel;
    QStringList m_sclkStates;
    QVariantList m_apps, m_screens, m_connectors, m_gpuProcesses;
    QHash<qint64, qint64> m_prevEngineNs; // pid -> drm-engine-gfx ns at last poll
    QElapsedTimer m_procTimer;
    QString m_selectedApp;
    int m_nlTemp = 2700;
    bool m_nlEnabled = false;
};
