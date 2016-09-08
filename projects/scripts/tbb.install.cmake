# Install headers
file(INSTALL
  "${source_location}/include/"
  DESTINATION "${install_location}/include"
  PATTERN "index.html" EXCLUDE)

# Install libraries
file(INSTALL
  "${source_location}/${libdir}/"
  DESTINATION "${install_location}/lib"
  FILES_MATCHING
    PATTERN "${libprefix}tbb${libsuffix}"
    PATTERN "${libprefix}tbb_debug${libsuffix}"
    PATTERN "${libprefix}tbbmalloc${libsuffix}"
    PATTERN "${libprefix}tbbmalloc_debug${libsuffix}")

if (WIN32)
  # Install DLLs
  string(REPLACE "lib" "bin" bindir "${libdir}")
  file(INSTALL
    "${source_location}/${bindir}/${libprefix}tbb${libsuffixshared}"
    "${source_location}/${bindir}/${libprefix}tbb_debug${libsuffixshared}"
    "${source_location}/${bindir}/${libprefix}tbbmalloc${libsuffixshared}"
    "${source_location}/${bindir}/${libprefix}tbbmalloc_debug${libsuffixshared}"
    DESTINATION "${install_location}/bin")
endif ()

# Remove rpath junk
if (APPLE)
  file(GLOB libraries "${install_location}/lib/${libprefix}tbb*.dylib")
  foreach (library IN LISTS libraries)
    execute_process(
      COMMAND install_name_tool
              -id "${library}"
              "${library}")
  endforeach ()
endif ()
