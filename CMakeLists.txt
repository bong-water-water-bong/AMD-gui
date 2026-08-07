cmake_minimum_required(VERSION 3.16)
project(amd-gui VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)
qt_policy(SET QTP0001 NEW) # embed QML module into the binary resources
qt_policy(SET QTP0004 NEW)
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
        qml/IconButton.qml
        qml/HomePage.qml
        qml/GamingPage.qml
        qml/TuningPage.qml
        qml/PerformancePage.qml
        qml/DisplayPage.qml
        qml/SystemPage.qml
)

target_link_libraries(amd-gui PRIVATE Qt6::Quick)

install(TARGETS amd-gui RUNTIME DESTINATION bin)
install(FILES packaging/amd-gui.desktop DESTINATION share/applications)
install(FILES packaging/amd-gui.svg DESTINATION share/icons/hicolor/scalable/apps)
install(FILES scripts/install-permissions.sh
        DESTINATION share/amd-gui
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
