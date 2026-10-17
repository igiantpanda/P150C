cmake_minimum_required(VERSION 3.16)

project(P150C VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.10)

if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

set(APP_MAIN_SOURCES
    main.cpp
)

if (WIN32)
    set(APP_ICON_ABSOLUTE "${CMAKE_CURRENT_SOURCE_DIR}/assets/app.ico")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/app.rc.in"
        "${CMAKE_CURRENT_BINARY_DIR}/app.rc"
        @ONLY
    )
    list(APPEND APP_MAIN_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/app.rc")
endif()

qt_add_executable(appP150C
    ${APP_MAIN_SOURCES}
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

qt_add_resources(appP150C "app_images"
    PREFIX "/images"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/assets"
    FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon.png"
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
