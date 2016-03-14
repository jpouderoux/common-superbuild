set(netcdf_libdir)
if (UNIX AND NOT APPLE)
  set(netcdf_libdir
    -DCMAKE_INSTALL_LIBDIR:BOOL=lib)
endif ()

superbuild_add_project(netcdf
  DEPENDS hdf5 zlib

  CMAKE_ARGS
    -DBUILD_SHARED_LIBS:BOOL=${BUILD_SHARED_LIBS}
    -DBUILD_TESTING:BOOL=FALSE
    -DBUILD_UTILITIES:BOOL=FALSE
    -DUSE_SZIP:BOOL=OFF
    -DENABLE_DAP:BOOL=OFF
    ${netcdf_libdir})

superbuild_apply_patch(netcdf vtk-tag
  "Add #define to mark API as VTK-modified")
