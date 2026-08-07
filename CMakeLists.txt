cmake_minimum_required(VERSION 3.16)
project(amd-gui VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)
qt_standard_project_setup()

qt_add_executable(amd-gui
    src/main.cpp
    src/backend.cpp
)

qt_add_qml_module(amd-gui
    URI AmdGui
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/GamingPage.qml
        qml/TuningPage.qml
        qml/PerformancePage.qml
        qml/DisplayPage.qml
        qml/SystemPage.qml
)

target_link_libraries(amd-gui PRIVATE Qt6::Quick)
