#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "backend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // selftest: OD parsing logic against a fixture (runnable without GPU)
    if (app.arguments().contains("--selftest")) {
        int lo = 0, hi = 0;
        bool ok1 = Backend::parseOD(
            QStringLiteral("OD_SCLK:\n0: 600Mhz\n1: 2900Mhz\nOD_RANGE:\nSCLK: 600Mhz 2900Mhz"),
            &lo, &hi);
        bool ok2 = Backend::parseOD(QStringLiteral("garbage"), &lo, &hi);
        bool ok3 = Backend::parseSclkStates(QStringLiteral("0: 600Mhz\n1: 845Mhz *\n2: 2900Mhz"))
                   == QStringList{ "600 MHz", "845 MHz *", "2900 MHz" };
        if (!(ok1 && lo == 600 && hi == 2900 && !ok2 && ok3))
            return 2;
        return 0;
    }

    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.loadFromModule("AmdGui", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
