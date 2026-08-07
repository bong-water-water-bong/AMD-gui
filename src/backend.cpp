#include "backend.h"

#include <QDir>
#include <QFile>
#include <QRegularExpression>

#include <cmath>

Backend::Backend(QObject *parent) : QObject(parent)
{
    refreshMetrics();
    refreshOD();
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
