# bakugandotc - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(bakugandotc LANGUAGES CXX)

set(REXSDK_VERSION "0.10.0" CACHE STRING "Pinned ReXGlue SDK version")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(BAKUGANDOTC_SOURCES
    src/main.cpp
    src/hooks/music_startup_hooks.cpp
    src/discord/discord_rpc.cpp
)

# Legacy investigation hooks are local-only and are not part of source exports.
option(BAKUGAN_AUDIO_DEBUG "Enable legacy local audio investigation hooks" OFF)
if(BAKUGAN_AUDIO_DEBUG)
    list(APPEND BAKUGANDOTC_SOURCES src/hooks/audio_debug_hooks.cpp)
endif()

option(BAKUGAN_MUSIC_TRACE "Enable detailed music playback diagnostics" OFF)
if(BAKUGAN_MUSIC_TRACE)
    list(APPEND BAKUGANDOTC_SOURCES src/hooks/music_trace_hooks.cpp)
endif()

if(WIN32)
    enable_language(RC)
    list(APPEND BAKUGANDOTC_SOURCES resources/app.rc)
    add_executable(bakugandotc WIN32 ${BAKUGANDOTC_SOURCES})
    target_include_directories(bakugandotc PRIVATE resources)
else()
    add_executable(bakugandotc ${BAKUGANDOTC_SOURCES})
endif()

rexglue_setup_target(bakugandotc)

if(WIN32)
    add_subdirectory(launcher)
endif()
