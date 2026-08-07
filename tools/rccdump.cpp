// Dump all files from a Qt .rcc binary resource using Qt's own parser.
// Usage: rccdump file.rcc outdir
#include <QResource>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QDebug>

int main(int argc, char **argv)
{
    if (argc < 3) {
        qWarning() << "usage: rccdump file.rcc outdir";
        return 1;
    }
    if (!QResource::registerResource(QString::fromLocal8Bit(argv[1]))) {
        qWarning() << "registerResource failed for" << argv[1];
        return 1;
    }
    const QString outdir = QString::fromLocal8Bit(argv[2]);
    int count = 0;
    QDirIterator it(QStringLiteral(":/"), QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);
    while (it.hasNext()) {
        const QString path = it.next();
        const QFileInfo fi(path);
        if (fi.isDir())
            continue;
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly))
            continue;
        const QByteArray data = f.readAll();
        const QString rel = path.mid(1);
        const QString dest = outdir + QLatin1Char('/') + rel;
        QDir().mkpath(QFileInfo(dest).absolutePath());
        QFile out(dest);
        if (!out.open(QIODevice::WriteOnly)) {
            qWarning() << "cannot write" << dest;
            continue;
        }
        out.write(data);
        ++count;
    }
    qInfo() << argv[1] << "->" << outdir << count << "files";
    return 0;
}
