set(png_libtype_args)
if (BUILD_SHARED_LIBS)
  set(png_libtype_args -DPNG_SHARED:BOOL=ON -DPNG_STATIC:BOOL=OFF)
else ()
  set(png_libtype_args -DPNG_STATIC:BOOL=ON -DPNG_SHARED:BOOL=OFF)
endif ()

superbuild_add_project(png
  CAN_USE_SYSTEM
  DEPENDS zlib

  CMAKE_ARGS
    ${png_libtype_args}
    -DPNG_TESTS:BOOL=OFF
    # VTK uses API that gets hidden when PNG_NO_STDIO is TRUE (default).
    -DPNG_NO_STDIO:BOOL=OFF)
