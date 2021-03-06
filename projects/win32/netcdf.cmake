include("${CMAKE_CURRENT_LIST_DIR}/../netcdf.cmake")

# VS2015 support
superbuild_apply_patch(netcdf VS2015
  "Support Visual Studio 2015")

# Fix wrong name of win32 into _win32
superbuild_apply_patch(netcdf fix-_win32-name
  "Replace win32 with _win32")
