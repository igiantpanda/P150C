cmake_minimum_required(VERSION 3.16)

project(P150C VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.10)

if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appP150C
    main.cpp
)

qt_add_qml_module(appP150C
    URI P150C
    QML_FILES
        Main.qml
        DualAxisChart.qml
        SerialConfigDialog.qml
        StatusLamp.qml
    SOURCES
        devicecontroller.h
        devicecontroller.cpp
        nativeserialport.h
        nativeserialport.cpp
)

set_target_properties(appP150C PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appP150C
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
)

install(TARGETS appP150C
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
