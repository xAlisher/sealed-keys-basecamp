cmake_minimum_required(VERSION 3.14)
project(SealedKeysPlugin LANGUAGES CXX)

if(DEFINED ENV{LOGOS_MODULE_BUILDER_ROOT})
    # ── Nix builder path (Basecamp module build) ─────────────────────────────
    include($ENV{LOGOS_MODULE_BUILDER_ROOT}/cmake/LogosModule.cmake)
    logos_module(
        NAME sealed_keys
        SOURCES
            src/plugin/SealedKeysPlugin.h
            src/plugin/SealedKeysPlugin.cpp
        INCLUDE_DIRS
            src
    )
else()
    # ── Local dev path (cmake -B build && cmake --build build) ────────────────
    set(CMAKE_CXX_STANDARD 17)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_INCLUDE_CURRENT_DIR ON)

    list(PREPEND CMAKE_PREFIX_PATH "$ENV{HOME}/Qt/6.9.3/gcc_64")
    find_package(Qt6 REQUIRED COMPONENTS Core Qml Network)
    qt_standard_project_setup()

    if(DEFINED ENV{LOGOS_LIBLOGOS_HEADERS})
        set(LOGOS_LIBLOGOS_HEADERS "$ENV{LOGOS_LIBLOGOS_HEADERS}")
    endif()
    if(DEFINED ENV{LOGOS_CPP_SDK_ROOT})
        set(LOGOS_CPP_SDK "$ENV{LOGOS_CPP_SDK_ROOT}")
    endif()

    add_library(sealed_keys_plugin MODULE
        src/plugin/SealedKeysPlugin.h
        src/plugin/SealedKeysPlugin.cpp
    )
    set_target_properties(sealed_keys_plugin PROPERTIES PREFIX "" OUTPUT_NAME "sealed_keys_plugin")
    target_include_directories(sealed_keys_plugin PRIVATE
        src
        "${LOGOS_LIBLOGOS_HEADERS}"
        "${LOGOS_CPP_SDK}/include"
        "${LOGOS_CPP_SDK}/include/cpp"
        "${LOGOS_CPP_SDK}/include/core"
    )
    target_link_libraries(sealed_keys_plugin PRIVATE
        Qt6::Core Qt6::Qml Qt6::Network
        "${LOGOS_CPP_SDK}/lib/liblogos_sdk.a"
        dl pthread
    )

    # ── Install into the local Basecamp data dir ─────────────────────────────
    set(LOGOS_BASECAMP_DATA "$ENV{HOME}/.local/share/Logos/LogosBasecamp")
    set(MODULE_DIR "${LOGOS_BASECAMP_DATA}/modules/sealed_keys")
    set(UI_DIR     "${LOGOS_BASECAMP_DATA}/plugins/sealed_keys_ui")

    install(TARGETS sealed_keys_plugin LIBRARY DESTINATION "${MODULE_DIR}")
    install(FILES modules/sealed_keys/manifest.json modules/sealed_keys/metadata.json DESTINATION "${MODULE_DIR}")
    install(FILES plugins/sealed_keys_ui/manifest.json plugins/sealed_keys_ui/metadata.json DESTINATION "${UI_DIR}")
    install(FILES plugins/sealed_keys_ui/qml/Main.qml DESTINATION "${UI_DIR}/qml")
endif()
