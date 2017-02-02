list(APPEND qt5_extra_depends
  freetype
  fontconfig
  png)
list(APPEND qt5_extra_options
  -qt-xcb
  -system-libpng
  -fontconfig)

list(APPEND qt5_process_environment PROCESS_ENVIRONMENT PKG_CONFIG_PATH <INSTALL_DIR>/lib/pkgconfig)

include(qt5.common)
