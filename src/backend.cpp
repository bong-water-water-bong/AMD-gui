#include "backend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QScreen>
#include <QStandardPaths>
#include <QSysInfo>

#include <cmath>

Backend::Backend(QObject *parent) : QObject(parent)
{
    refreshMetrics();
    refreshOD();
    refreshApps();
    refreshScreens();
    refreshNightLight();

    connect(qApp, &QGuiApplication::screenAdded, this, &Backend::refreshScreens);
    connect(qApp, &QGuiApplication::screenRemoved, this, &Backend::refreshScreens);
    connect(qApp, &QGuiApplication::primaryScreenChanged, this, &Backend::refreshScreens);
}

QString Backend::cardDir() const
{
    // first drm card whose device dir exposes pp_od_clk_voltage
    const QStringList cards = QDir("/sys/class/drm").entryList({ "card[0-9]*" }, QDir::Dirs);
    for (const QString &c : cards) {
        const QString d = QStringLiteral("/sys/class/drm/%1/device").arg(c);
        if (QFile::exists(d + "/pp_od_clk_voltage"))
            return d;
    }
    return {};
}

QString Backend::kernelVersion() const
{
    return QSysInfo::kernelVersion();
}

QString Backend::hwmonDir() const
{
    const QStringList hwmons = QDir("/sys/class/hwmon").entryList({ "hwmon[0-9]*" }, QDir::Dirs);
    for (const QString &h : hwmons) {
        const QString d = QStringLiteral("/sys/class/hwmon/%1").arg(h);
        if (readFile(d + "/name").trimmed() == QLatin1String("amdgpu"))
            return d;
    }
    return {};
}

QString Backend::gpuName() const
{
    const QString d = cardDir();
    return d.isEmpty() ? QString() : readFile(d + "/product_name").trimmed();
}

QString Backend::readFile(const QString &path) const
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(f.readAll());
}

bool Backend::writeFile(const QString &path, const QString &data)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        emit error(QStringLiteral("Cannot write %1: %2").arg(path, f.errorString()));
        return false;
    }
    f.write(data.toUtf8());
    return true;
}

void Backend::refreshMetrics()
{
    const QString hw = hwmonDir();
    if (hw.isEmpty())
        return;
    m_temp = readFile(hw + "/temp1_input").trimmed().toDouble() / 1000.0;
    m_power = readFile(hw + "/power1_average").trimmed().toDouble() / 1e6;
    const QString card = cardDir();
    m_busy = readFile(card + "/gpu_busy_percent").trimmed().toInt();
    m_vcn = readFile(card + "/vcn_busy_percent").trimmed().toInt();
    emit metricsChanged();
}

void Backend::refreshOD()
{
    const QString d = cardDir();
    if (d.isEmpty())
        return;
    const QString od = readFile(d + "/pp_od_clk_voltage");
    int lo = 0, hi = 0;
    if (parseOD(od, &lo, &hi)) {
        m_sclkMin = lo;
        m_sclkMax = hi;
    }
    m_sclkStates = parseSclkStates(readFile(d + "/pp_dpm_sclk"));
    m_perfLevel = readFile(d + "/power_dpm_force_performance_level").trimmed();
    emit odChanged();
}

bool Backend::parseOD(const QString &text, int *minMhz, int *maxMhz)
{
    // OD_RANGE:\nSCLK:     600Mhz       2900Mhz
    static const QRegularExpression re(
        QStringLiteral("OD_RANGE:\\s*SCLK:\\s*(\\d+)Mhz\\s*(\\d+)Mhz"));
    const auto m = re.match(text);
    if (!m.hasMatch())
        return false;
    *minMhz = m.captured(1).toInt();
    *maxMhz = m.captured(2).toInt();
    return true;
}

QStringList Backend::parseSclkStates(const QString &text)
{
    // "0: 600Mhz\n1: 845Mhz *\n2: 2900Mhz" -> ["600 MHz", "845 MHz *", ...]
    QStringList out;
    static const QRegularExpression re(QStringLiteral("\\d+:\\s*(\\d+)Mhz(\\s*\\*)?"));
    auto it = re.globalMatch(text);
    while (it.hasNext()) {
        const auto m = it.next();
        out << m.captured(1) + QStringLiteral(" MHz") + (m.captured(2).isEmpty() ? QString() : QStringLiteral(" *"));
    }
    return out;
}

void Backend::setPerfLevel(const QString &level)
{
    const QString d = cardDir();
    if (d.isEmpty() || !writeFile(d + "/power_dpm_force_performance_level", level))
        return;
    refreshOD();
}

void Backend::applySclk(int minMhz, int maxMhz)
{
    const QString d = cardDir();
    if (d.isEmpty())
        return;
    // overdrive: set min, set max, commit. Needs root.
    if (!writeFile(d + "/pp_od_clk_voltage",
                   QStringLiteral("s %1\ns %2\nc\n").arg(minMhz).arg(maxMhz)))
        return;
    refreshOD();
}

void Backend::resetOverdrive()
{
    const QString d = cardDir();
    if (d.isEmpty() || !writeFile(d + "/pp_od_clk_voltage", QStringLiteral("r\n")))
        return;
    refreshOD();
}

QVariantMap Backend::parseDesktopFile(const QString &path)
{
    // minimal .desktop parser: Name/Icon/Exec from the [Desktop Entry] section
    QVariantMap out;
    out["id"] = path;
    out["exec"] = QString();
    out["icon"] = QString();
    bool haveName = false;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return out;
    bool inEntry = false;
    const QStringList lines = QString::fromUtf8(f.readAll()).split('\n');
    for (const QString &raw : lines) {
        const QString line = raw.section('#', 0, 0).trimmed();
        if (line.startsWith('[')) {
            inEntry = (line == QLatin1String("[Desktop Entry]"));
            continue;
        }
        if (!inEntry || !line.contains('='))
            continue;
        const QString key = line.section('=', 0, 0).trimmed();
        const QString val = line.section('=', 1).trimmed();
        if (key == QLatin1String("Name") && !haveName) {
            out["name"] = val;
            haveName = true;
        } else if (key == QLatin1String("Icon"))
            out["icon"] = val;
        else if (key == QLatin1String("Exec"))
            out["exec"] = val;
        else if (key == QLatin1String("NoDisplay") && val == QLatin1String("true"))
            return {};
    }
    if (!haveName)
        out["name"] = QFileInfo(path).completeBaseName();
    return out;
}

void Backend::refreshApps()
{
    m_apps.clear();
    const QStringList dirs{ QStringLiteral("/usr/share/applications"),
                            QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation) };
    QStringList seen;
    for (const QString &dir : dirs) {
        const QStringList files = QDir(dir).entryList({ "*.desktop" }, QDir::Files);
        for (const QString &file : files) {
            const QVariantMap app = parseDesktopFile(dir + '/' + file);
            if (app.isEmpty() || app["exec"].toString().isEmpty())
                continue;
            if (seen.contains(app["exec"].toString())) // user dir wins over /usr
                continue;
            seen << app["exec"].toString();
            // resolve theme icon to a loadable path when it's the common hicolor one
            QString icon = app["icon"].toString();
            if (!icon.isEmpty() && !icon.startsWith('/')) {
                const QString p = QStringLiteral("/usr/share/icons/hicolor/64x64/apps/%1.png").arg(icon);
                if (QFile::exists(p))
                    icon = p;
                else
                    icon.clear();
            }
            QVariantMap a = app;
            a["icon"] = icon;
            m_apps << a;
        }
    }
    std::sort(m_apps.begin(), m_apps.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()["name"].toString() < b.toMap()["name"].toString();
    });
    emit appsChanged();
}

void Backend::refreshScreens()
{
    m_screens.clear();
    for (QScreen *s : QGuiApplication::screens()) {
        QVariantMap m;
        m["name"] = s->name();
        m["width"] = s->geometry().width();
        m["height"] = s->geometry().height();
        m["refresh"] = QString::number(s->refreshRate(), 'f', 1);
        m["primary"] = (s == QGuiApplication::primaryScreen());
        m_screens << m;
    }
    m_connectors.clear();
    const QString card = cardDir();
    if (!card.isEmpty()) {
        const QString base = card.left(card.lastIndexOf('/')); // /sys/class/drm/cardN
        const QStringList conns = QDir(base).entryList({ "card*-*" }, QDir::Dirs);
        for (const QString &c : conns) {
            QVariantMap m;
            m["name"] = c.section('-', 1);
            m["status"] = readFile(base + '/' + c + "/status").trimmed();
            m_connectors << m;
        }
    }
    emit screensChanged();
}

void Backend::setSelectedApp(const QString &id)
{
    if (m_selectedApp == id)
        return;
    m_selectedApp = id;
    emit selectionChanged();
}

QString Backend::profilesPath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    return dir + "/profiles.json";
}

QVariantMap Backend::profiles() const
{
    QFile f(profilesPath());
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(f.readAll()).object().toVariantMap();
}

void Backend::saveProfiles(const QVariantMap &all)
{
    QDir().mkpath(QFileInfo(profilesPath()).absolutePath());
    QFile f(profilesPath());
    if (!f.open(QIODevice::WriteOnly))
        return;
    f.write(QJsonDocument(QJsonObject::fromVariantMap(all)).toJson(QJsonDocument::Indented));
}

QVariantMap Backend::appProfile(const QString &id)
{
    return profiles().value(id).toMap();
}

QString Backend::execLine(const QVariantMap &app) const
{
    QString exec = app["exec"].toString();
    exec.remove(QRegularExpression(QStringLiteral("\\s*%[fFuUdDnNickvm]")));
    return exec;
}

void Backend::launchApp(const QString &id, const QString &level, bool gamemode, const QString &env)
{
    QVariantMap app;
    for (const QVariant &a : m_apps) {
        if (a.toMap()["id"].toString() == id) {
            app = a.toMap();
            break;
        }
    }
    if (app.isEmpty()) {
        emit error(QStringLiteral("App not found: %1").arg(id));
        return;
    }
    // persist profile
    QVariantMap all = profiles();
    QVariantMap p;
    p["perfLevel"] = level;
    p["gamemode"] = gamemode;
    p["env"] = env;
    all[id] = p;
    saveProfiles(all);

    // best-effort perf level for the session; needs root unless udev rule installed
    const QString d = cardDir();
    if (!d.isEmpty())
        writeFile(d + "/power_dpm_force_performance_level", level);

    QString cmd;
    if (!env.trimmed().isEmpty())
        cmd += QStringLiteral("export %1; ").arg(env.trimmed().replace('\n', ' '));
    if (gamemode)
        cmd += QStringLiteral("gamemoderun ");
    cmd += execLine(app);
    if (!QProcess::startDetached(QStringLiteral("/bin/sh"), { "-c", cmd }))
        emit error(QStringLiteral("Failed to launch %1").arg(app["name"].toString()));
}

void Backend::refreshNightLight()
{
    auto gs = [](const QString &key) {
        QProcess p;
        p.start(QStringLiteral("gsettings"),
                { "get", QStringLiteral("org.gnome.settings-daemon.plugins.color"), key });
        p.waitForFinished(3000);
        return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
    };
    const QString tmp = gs(QStringLiteral("night-light-temperature"));
    if (!tmp.isEmpty()) {
        // "uint32 2700" -> 2700
        m_nlTemp = tmp.section(' ', -1).toInt();
        m_nlEnabled = (gs(QStringLiteral("night-light-enabled")) == QLatin1String("true"));
    }
    emit nightLightChanged();
}

void Backend::setNightLightTemp(int kelvin)
{
    const int rc = QProcess::execute(
        QStringLiteral("gsettings"),
        { "set", QStringLiteral("org.gnome.settings-daemon.plugins.color"),
          QStringLiteral("night-light-temperature"), QString::number(kelvin) });
    if (rc != 0)
        emit error(QStringLiteral("gsettings set night-light-temperature failed (rc %1)").arg(rc));
    else
        m_nlTemp = kelvin;
    emit nightLightChanged();
}

void Backend::setNightLightEnabled(bool on)
{
    const int rc = QProcess::execute(
        QStringLiteral("gsettings"),
        { "set", QStringLiteral("org.gnome.settings-daemon.plugins.color"),
          QStringLiteral("night-light-enabled"), on ? QStringLiteral("true") : QStringLiteral("false") });
    if (rc != 0)
        emit error(QStringLiteral("gsettings set night-light-enabled failed (rc %1)").arg(rc));
    else
        m_nlEnabled = on;
    emit nightLightChanged();
}
