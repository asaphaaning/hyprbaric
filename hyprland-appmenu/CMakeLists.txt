# Companion Hyprland plugin for the global-menu proof.
cmake_minimum_required(VERSION 3.22)

project(hyprbaric_appmenu LANGUAGES C CXX)

find_package(PkgConfig REQUIRED)
pkg_check_modules(HYPRLAND REQUIRED IMPORTED_TARGET hyprland)
find_program(WAYLAND_SCANNER NAMES wayland-scanner REQUIRED)

option(HYPRBARIC_APPMENU_BUILD_PROBES
    "Build the standalone AppMenu protocol probes"
    ON
)

set(APPMENU_PROTOCOL ${CMAKE_CURRENT_SOURCE_DIR}/protocols/appmenu.xml)
set(GTK_SHELL_PROTOCOL ${CMAKE_CURRENT_SOURCE_DIR}/protocols/gtk-shell.xml)
set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
set(APPMENU_SERVER_HEADER ${GENERATED_DIR}/appmenu-server-protocol.h)
set(APPMENU_CLIENT_HEADER ${GENERATED_DIR}/appmenu-client-protocol.h)
set(APPMENU_CODE ${GENERATED_DIR}/appmenu-protocol.c)
set(GTK_SHELL_SERVER_HEADER ${GENERATED_DIR}/gtk-shell-server-protocol.h)
set(GTK_SHELL_CODE ${GENERATED_DIR}/gtk-shell-protocol.c)

add_custom_command(
    OUTPUT ${APPMENU_SERVER_HEADER} ${APPMENU_CLIENT_HEADER} ${APPMENU_CODE}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${GENERATED_DIR}
    COMMAND ${WAYLAND_SCANNER} server-header ${APPMENU_PROTOCOL} ${APPMENU_SERVER_HEADER}
    COMMAND ${WAYLAND_SCANNER} client-header ${APPMENU_PROTOCOL} ${APPMENU_CLIENT_HEADER}
    COMMAND ${WAYLAND_SCANNER} private-code ${APPMENU_PROTOCOL} ${APPMENU_CODE}
    DEPENDS ${APPMENU_PROTOCOL}
    VERBATIM
)

add_custom_command(
    OUTPUT ${GTK_SHELL_SERVER_HEADER} ${GTK_SHELL_CODE}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${GENERATED_DIR}
    COMMAND ${WAYLAND_SCANNER} server-header ${GTK_SHELL_PROTOCOL} ${GTK_SHELL_SERVER_HEADER}
    COMMAND ${WAYLAND_SCANNER} private-code ${GTK_SHELL_PROTOCOL} ${GTK_SHELL_CODE}
    DEPENDS ${GTK_SHELL_PROTOCOL}
    VERBATIM
)

add_custom_target(appmenu-protocol
    DEPENDS ${APPMENU_SERVER_HEADER} ${APPMENU_CLIENT_HEADER} ${APPMENU_CODE}
            ${GTK_SHELL_SERVER_HEADER} ${GTK_SHELL_CODE}
)

set_source_files_properties(${APPMENU_CODE} ${GTK_SHELL_CODE} PROPERTIES GENERATED TRUE)

add_library(hyprbaric-appmenu SHARED
    src/main.cpp
    ${APPMENU_CODE}
    ${GTK_SHELL_CODE}
)

target_compile_features(hyprbaric-appmenu PRIVATE cxx_std_23)
target_compile_options(hyprbaric-appmenu PRIVATE -Wall -Wextra -Wpedantic)
target_include_directories(hyprbaric-appmenu PRIVATE ${GENERATED_DIR})
target_link_libraries(hyprbaric-appmenu PRIVATE PkgConfig::HYPRLAND)
add_dependencies(hyprbaric-appmenu appmenu-protocol)

set_target_properties(hyprbaric-appmenu PROPERTIES
    PREFIX ""
    OUTPUT_NAME "hyprbaric-appmenu"
)

if(HYPRBARIC_APPMENU_BUILD_PROBES)
    pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
    pkg_check_modules(GIO REQUIRED IMPORTED_TARGET gio-2.0)
    pkg_check_modules(GTK4 REQUIRED IMPORTED_TARGET gtk4)

    add_executable(hyprbaric-appmenu-probe
        tests/probe.c
        ${APPMENU_CODE}
    )

    target_include_directories(hyprbaric-appmenu-probe PRIVATE ${GENERATED_DIR})
    target_link_libraries(hyprbaric-appmenu-probe PRIVATE PkgConfig::WAYLAND_CLIENT)
    add_dependencies(hyprbaric-appmenu-probe appmenu-protocol)

    add_executable(hyprbaric-kappmenuview-probe
        tests/kappmenuview.c
    )

    target_link_libraries(hyprbaric-kappmenuview-probe PRIVATE PkgConfig::GIO)

    add_executable(hyprbaric-gtk-menu-probe
        tests/gtk_menu.c
    )
    target_link_libraries(hyprbaric-gtk-menu-probe PRIVATE PkgConfig::GTK4)
endif()
