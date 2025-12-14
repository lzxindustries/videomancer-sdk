cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)

if(WIN32)
    set(CMAKE_CXX_STANDARD 17)
else()
    set(CMAKE_CXX_STANDARD 20)
endif()

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

project(videomancer-sdk C CXX ASM)

  execute_process(
        COMMAND git describe --tags --abbrev=7
        OUTPUT_VARIABLE GIT_DESCRIBE
        ERROR_QUIET
    )
    string(REGEX MATCH "([^-]+)-([0-9]+)-(g[0-9a-f]+)" GIT_VERSION_DATA "${GIT_DESCRIBE}")

    if(GIT_VERSION_DATA)
        set(PROJECT_VERSION_TAG "${CMAKE_MATCH_1}")
        set(PROJECT_VERSION_COMMITS "${CMAKE_MATCH_2}")
        set(PROJECT_VERSION_HASH "${CMAKE_MATCH_3}")
    else()
        set(PROJECT_VERSION_TAG "${GIT_DESCRIBE}")
        set(PROJECT_VERSION_COMMITS "0")
        set(PROJECT_VERSION_HASH "")
    endif()

    # Extract major, minor, and bugfix from tag (expects format vMAJOR.MINOR.BUGFIX or MAJOR.MINOR.BUGFIX)
    string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ver "${PROJECT_VERSION_TAG}")
    if(_ver)
        set(PROJECT_VERSION_MAJOR "${CMAKE_MATCH_1}")
        set(PROJECT_VERSION_MINOR "${CMAKE_MATCH_2}")
        set(PROJECT_VERSION_PATCH "${CMAKE_MATCH_3}")
    else()
        set(PROJECT_VERSION_MAJOR "0")
        set(PROJECT_VERSION_MINOR "0")
        set(PROJECT_VERSION_PATCH "0")
    endif()

    # Set CMake project version
    set(PROJECT_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")
    project(videomancer-sdk VERSION ${PROJECT_VERSION} LANGUAGES C CXX ASM)
    
    message(STATUS "Project Version Tag:     ${PROJECT_VERSION_TAG}")
    message(STATUS "Project Version Commits: ${PROJECT_VERSION_COMMITS}")
    message(STATUS "Project Version Hash:    ${PROJECT_VERSION_HASH}")
    message(STATUS "Project Version Major:   ${PROJECT_VERSION_MAJOR}")
    message(STATUS "Project Version Minor:   ${PROJECT_VERSION_MINOR}")
    message(STATUS "Project Version Patch:   ${PROJECT_VERSION_PATCH}")
    message(STATUS "Project Version:         ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/scripts/videomancer_sdk_version.hpp.in ${CMAKE_CURRENT_SOURCE_DIR}/src/lzx/sdk/videomancer_sdk_version.hpp)

add_subdirectory(third_party)

add_library(videomancer-sdk INTERFACE)

target_include_directories(videomancer-sdk INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}/src
)

target_link_libraries(videomancer-sdk INTERFACE
    monocypher
)