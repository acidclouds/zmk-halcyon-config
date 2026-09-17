zephyr_library()
# ZMK headers (zmk/display.h, zmk/battery.h, ...) live in zmk/app/include.
# CMAKE_SOURCE_DIR is zmk/app when built with `west build -s zmk/app`.
zephyr_library_include_directories(${CMAKE_SOURCE_DIR}/include)
zephyr_library_sources(
  status_screen.c
  widgets/status.c
  widgets/util.c
  widgets/bolt.c
  widgets/art.c
)
