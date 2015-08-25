function (superbuild_cross_declare_variables)
  set(CROSS_BUILD_STAGE "host"
    CACHE STRING "Cross compilation stage: one of HOST (i.e., native), TOOLS, or CROSS")
  mark_as_advanced(CROSS_BUILD_STAGE)
  set_property(CACHE CROSS_BUILD_STAGE
    PROPERTY
      STRINGS "HOST" "TOOLS" "CROSS")

  if (NOT CROSS_BUILD_STAGE STREQUAL "HOST")
    set(superbuild_is_cross TRUE
      PARENT_SCOPE)
  endif ()
endfunction ()

function (superbuild_cross_determine_target)
  if (NOT superbuild_is_cross)
    return ()
  endif ()

  # Ask user to say what machine they are compiling onto so we can get the
  # right environment settings.
  _superbuild_cross_target_machine()

  if (CROSS_BUILD_STAGE STREQUAL "CROSS")
    # Configure the platform dependent settings 64bit_build, static_only, mpi
    # search path.
    _superbuild_cross_platform_settings()

    if (COMMAND superbuild_cross_prepare)
      superbuild_cross_prepare()
    endif ()
  endif ()
endfunction ()

#=============================================================================
# Ask user what the target machine is, so that we can choose the right
# right build hints and patches later on.
#
function (_superbuild_cross_target_machine)
  set(cross_target "generic"
    CACHE STRING "Platform to cross compile for, either generic|bgp_xlc|bgq_xlc|bgq_gnu|xk7_gnu")
  set_property(CACHE cross_target PROPERTY STRINGS
    "generic" "bgp_xlc" "bgq_xlc" "bgq_gnu" "xk7_gnu")

  set(CROSS_BUILD_SITE ""
    CACHE STRING "Specify Site to load appropriate configuration defaults, if available.")
endfunction ()

#=============================================================================
# Includes an optionally site-specific file from the cross-compiling directory.
function (_superbuild_cross_include_file var name)
  # Copy toolchains
  string(TOLOWER "${CROSS_BUILD_SITE}" lsite)

  set(site_file
    "crosscompile/${cross_target}/${name}.${lsite}.cmake")
  include("${site_file}" OPTIONAL
    RESULT_VARIABLE res)
  if (NOT res)
    set(site_file
      "crosscompile/${cross_target}/${name}.cmake")
    include("${site_file}" OPTIONAL
      RESULT_VARIABLE res)
    if (NOT res)
      set(site_file)
    endif ()
  endif ()

  set("${var}"
    "${site_file}"
    PARENT_SCOPE)
endfunction ()

#=============================================================================
# Configures the cmake files that describe how to cross compile paraview
# From the ${cross_target} directory into the build tree.
#
function (_superbuild_cross_platform_settings)
  # Copy toolchains
  string(TOLOWER "${CROSS_BUILD_SITE}" lsite)

  set(site_toolchain
    "${CMAKE_CURRENT_LIST_DIR}/crosscompile/${cross_target}/ToolChain.${lsite}.cmake.in")
  if (NOT EXISTS "${site_toolchain}")
    set(site_toolchain
      "${CMAKE_CURRENT_LIST_DIR}/crosscompile/${cross_target}/ToolChain.cmake.in")
  endif ()

  set(superbuild_cross_toolchain
    "${CMAKE_BINARY_DIR}/crosscompile/ToolChain.cmake"
    PARENT_SCOPE)
  set(superbuild_cross_toolchain
    "${CMAKE_BINARY_DIR}/crosscompile/ToolChain.cmake")

  configure_file(
    "${site_toolchain}"
    "${superbuild_cross_toolchain}"
    @ONLY)
endfunction ()