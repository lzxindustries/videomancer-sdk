cmake_minimum_required(VERSION 3.13)

# monocypher library
add_library(monocypher STATIC
    ${CMAKE_CURRENT_LIST_DIR}/src/monocypher.c
    ${CMAKE_CURRENT_LIST_DIR}/src/monocypher-ed25519.c
)

target_include_directories(monocypher PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/src
)