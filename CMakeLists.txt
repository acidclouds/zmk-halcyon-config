# This repo is a Zephyr module. Only the custom display screen has sources.
if(CONFIG_ELORA_STATUS_SCREEN)
  add_subdirectory(src/display)
endif()
