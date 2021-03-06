set(boost_options)
if (BUILD_SHARED_LIBS)
  list(APPEND boost_options
    link=shared)
else ()
  list(APPEND boost_options
    link=static)
endif ()

list(APPEND boost_options
  --prefix=<INSTALL_DIR>)

if (NOT boost_libraries)
  # Boost's build system is silly and builds all by default, but doesn't have a
  # flag to say "build no libraries". We add this so we get a small build, but
  # we also get an install rule for all of the headers.
  set(boost_libraries
    system)
endif ()

foreach (boost_library IN LISTS boost_libraries)
  list(APPEND boost_options
    --with-${boost_library})
endforeach ()

if (WIN32)
  set(boost_build_commands
    CONFIGURE_COMMAND
      <SOURCE_DIR>/bootstrap.bat
    BUILD_COMMAND
      <SOURCE_DIR>/b2
        ${boost_options}
        ${boost_extra_options}
        install
    INSTALL_COMMAND
      "")
else ()
  set(boost_build_commands
    CONFIGURE_COMMAND
      <SOURCE_DIR>/bootstrap.sh
    BUILD_COMMAND
      <SOURCE_DIR>/b2
        ${boost_options}
        ${boost_extra_options}
    INSTALL_COMMAND
      <SOURCE_DIR>/b2
        ${boost_options}
        ${boost_extra_options}
        install)
endif ()

superbuild_add_project(boost
  CAN_USE_SYSTEM
  BUILD_IN_SOURCE 1
  DEPENDS zlib
  DEPENDS_OPTIONAL cxx11
  "${boost_build_commands}"
  ${boost_extra_arguments})

superbuild_add_extra_cmake_args(
  -DBOOST_ROOT:PATH=<INSTALL_DIR>)
