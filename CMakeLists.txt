cmake_minimum_required(VERSION 3.25)
project(libre40 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(REXSDK_VERSION "" CACHE STRING "Override SDK version (leave empty for default)")
if(REXSDK_VERSION)
    find_package(rexglue ${REXSDK_VERSION} EXACT QUIET CONFIG)
else()
    find_package(rexglue 0.8.1.4 QUIET CONFIG)
endif()
if(NOT rexglue_FOUND)
    message(FATAL_ERROR "ReXGlue SDK not found. Build the official SDK or pass -DCMAKE_PREFIX_PATH to its install prefix.")
endif()

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/generated/default/sources.cmake")
    message(FATAL_ERROR "generated/default/sources.cmake is missing. Extract your game and generate code first: python scripts/extract_iso.py then python scripts/codegen.py (see README).")
endif()

include(generated/default/sources.cmake)

set(L40_SOURCES
    src/crash_dump.cpp
    src/l40_app.cpp
    src/main.cpp
    ${GENERATED_SOURCES}
)

if(WIN32)
    add_executable(l40 WIN32 ${L40_SOURCES})
else()
    add_executable(l40 ${L40_SOURCES})
endif()

target_include_directories(l40 PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/generated/default
)

target_link_libraries(l40 PRIVATE rex::runtime)
if(WIN32)
    target_link_libraries(l40 PRIVATE dbghelp)
    target_link_options(l40 PRIVATE "LINKER:/MAP:${CMAKE_CURRENT_BINARY_DIR}/l40.map")
endif()
rexglue_configure_target(l40)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/generated/default/dll_targets.cmake")
    include(generated/default/dll_targets.cmake)
endif()
