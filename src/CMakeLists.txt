cmake_minimum_required(VERSION 3.13)

# monocypher library
add_library(videomancer-sdk STATIC
    ${CMAKE_CURRENT_LIST_DIR}/src/monocypher.c
    ${CMAKE_CURRENT_LIST_DIR}/src/monocypher-ed25519.c
)

target_include_directories(videomancer-sdk PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/src
)

target_link_libraries(main  
    pico_runtime
    pico_stdlib
    pico_util
    pico_flash
    pico_multicore
    pico_rand
    pico_int64_ops
    pico_double
    pico_float
    pico_divider
    hardware_divider
    hardware_interp
    hardware_uart
    hardware_spi
    hardware_i2c
    hardware_adc
    hardware_flash
    hardware_gpio
    hardware_clocks
    hardware_timer
    ArduinoJson
    etl
    littlefs
    mapbox
    monocypher
    no-OS-FatFS-SD-SDIO-SPI-RPi-Pico
)