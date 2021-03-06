if (BUILD_SHARED_LIBS)
  set(python_shared_args --enable-shared --disable-static)
else ()
  set(python_shared_args --disable-shared --enable-static)
endif ()

set(python_USE_UNICODE UCS2 CACHE STRING "Enable Unicode support for python")
set_property(CACHE python_USE_UNICODE PROPERTY STRINGS "OFF;UCS2;UCS4")
mark_as_advanced(python_USE_UNICODE)

if(python_USE_UNICODE STREQUAL "UCS2")
  set(python_unicode_args "--enable-unicode=ucs2")
elseif(python_USE_UNICODE STREQUAL "UCS4")
  set(python_unicode_args "--enable-unicode=ucs4")
else()
  set(python_unicode_args "--disable-unicode")
endif()

superbuild_add_project(python
  CAN_USE_SYSTEM
  DEPENDS bzip2 zlib png
  CONFIGURE_COMMAND
    <SOURCE_DIR>/configure
      --prefix=<INSTALL_DIR>
      ${python_USE_UNICODE}
      ${python_shared_args}
  BUILD_COMMAND
    $(MAKE)
  INSTALL_COMMAND
    make install)

if (NOT CMAKE_CROSSCOMPILING)
  # Pass the -rpath flag when building python to avoid issues running the
  # executable we built.
  superbuild_append_flags(
    ld_flags "-Wl,-rpath,${superbuild_install_location}/lib"
    PROJECT_ONLY)
endif ()

if (python_enabled)
  set(superbuild_python_executable "${superbuild_install_location}/bin/python"
    CACHE INTERNAL "")
else ()
  set(superbuild_python_executable ""
    CACHE INTERNAL "")
endif ()

superbuild_add_extra_cmake_args(
  -DVTK_PYTHON_VERSION:STRING=2.7)
