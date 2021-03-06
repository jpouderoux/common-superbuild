cmake_minimum_required(VERSION 3.0)

project(standalone-qt)

function (superbuild_find_projects var)
  set(projects
    cxx11
    freetype
    png
    qt4
    qt5
    zlib)

  if (UNIX)
    list(APPEND projects
      libxml2)
  endif()

  if (UNIX AND NOT APPLE)
    list(APPEND projects
      fontconfig)
  endif ()

  set("${var}"
    ${projects}
    PARENT_SCOPE)
endfunction ()

function (superbuild_sanity_check)
  include(qt.functions)

  superbuild_qt_sanity_check()
endfunction ()

set(qt_install_location ""
  CACHE PATH "Location to install Qt to.")
if (NOT qt_install_location)
  message(FATAL_ERROR "qt_install_location is not set!")
endif ()
set(superbuild_install_location "${qt_install_location}")

get_filename_component(sb_dir "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
add_subdirectory("${sb_dir}" "${CMAKE_CURRENT_BINARY_DIR}/superbuild")
