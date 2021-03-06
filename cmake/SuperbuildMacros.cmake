include(SuperbuildExternalProject)
include(CMakeParseArguments)

# The external projects list separator string should be set ASAP so that
# anything else can use it that needs it.
set(_superbuild_list_separator "-+-")

# Describe a project to be built as part of the superbuild.
#
# Usage:
#
#   superbuild_add_project(<name> [ARGS...])
#
# All ExternalProject keywords are valid here as well as the following
# extensions:
#
#   ``CAN_USE_SYSTEM``
#     Marks that the project may be provided by the system. In this case, the
#     ``${name}.system.cmake`` file will be used during the second phase if the
#     system version is selected.
#   ``MUST_USE_SYSTEM``
#     Where a project can be provided by the system, this flag may be specified
#     to indicate that this platform *must* use the system's version rather
#     than a custom built one. Usually only used in platform-specific files.
#   ``DEFAULT_ON``
#     If present, the project will default to be built.
#   ``DEVELOPER_MODE``
#     If present, the project will offer an option to build it in "developer"
#     mode. Developer mode enables and builds all dependent projects, but skips
#     the project itself. Instead, a file named
#     ``${name}-developer-config.cmake`` is written to the build directory
#     which may be passed to a standalone instance of the project using the
#     ``-C`` option of CMake to initialize the cache to use the dependencies
#     built as part of the superbuild.
#   ``DEBUGGABLE``
#     If present, an option to change the build type for the project will be
#     exposed.
#   ``SELECTABLE``
#     If present, this project's ``ENABLE_`` option will be visible (and all
#     non-selectable projects will be hidden). May be set externally with the
#     ``_superbuild_${name}_selectable`` flag.
#   ``HELP_STRING``
#     Set the description string for the option to enable the project.
#   ``DEPENDS_OPTIONAL <project>...``
#     Projects which this one can use if it is enabled, but is not required for
#     use.
#   ``PROCESS_ENVIRONMENT <var> <value>...``
#     Sets environment variables for the configure, build, and install steps.
#     Some are "magic" and are prepended to the current value (namely ``PATH``,
#     ``LD_LIBRARY_PATH`` (Linux), and ``DYLD_LIBRARY_PATH`` (OS X).
#
# Projects which are depended on may declare that they have CMake variables and
# flags which must be set in dependent projects (e.g., a Python project would
# set ``PYTHON_EXECUTABLE`` to the location of its installed Python).
function (superbuild_add_project name)
  _superbuild_project_check_name("${name}")

  set(can_use_system FALSE)
  set(must_use_system FALSE)
  set(default "${_superbuild_default_${name}}")
  set(allow_developer_mode FALSE)
  set(debuggable FALSE)
  set(selectable FALSE)
  set(help_string)
  set(depends)
  set(optional_depends)

  if (DEFINED "_superbuild_${name}_selectable")
    set(selectable "${_superbuild_${name}_selectable}")
  endif ()

  set(ep_arguments)
  set(grab)

  foreach (arg IN LISTS ARGN)
    if (arg STREQUAL "CAN_USE_SYSTEM")
      set(can_use_system TRUE)
      set(grab)
    elseif (arg STREQUAL "MUST_USE_SYSTEM")
      set(must_use_system TRUE)
      set(grab)
    elseif (arg STREQUAL "DEFAULT_ON")
      set(default ON)
      set(grab)
    elseif (arg STREQUAL "DEVELOPER_MODE")
      set(allow_developer_mode TRUE)
      set(grab)
    elseif (arg STREQUAL "DEBUGGABLE")
      set(debuggable TRUE)
      set(grab)
    elseif (arg STREQUAL "SELECTABLE")
      set(selectable TRUE)
      set(grab)
    elseif (arg STREQUAL "HELP_STRING")
      set(grab help_string)
    elseif (arg STREQUAL "DEPENDS")
      set(grab depends)
    elseif (arg STREQUAL "DEPENDS_OPTIONAL")
      set(grab optional_depends)
    elseif (arg MATCHES "${_ep_keywords__superbuild_ExternalProject_add}")
      set(grab ep_arguments)
      list(APPEND ep_arguments
        "${arg}")
    elseif (grab)
      list(APPEND "${grab}"
        "${arg}")
    endif ()
  endforeach ()

  # Allow projects to override the help string specified in the project file.
  if (DEFINED "superbuild_help_string_${name}")
    set(help_string "${superbuild_help_string_${name}}")
  endif ()

  if (NOT help_string)
    set(help_string "Request to build project ${name}")
  endif ()

  if (superbuild_build_phase)
    foreach (op_dep IN LISTS optional_depends)
      if (${op_dep}_enabled)
        list(APPEND ep_arguments
          DEPENDS "${op_dep}")
      endif ()
    endforeach ()

    get_property(all_projects GLOBAL
      PROPERTY superbuild_projects)
    set(missing_deps)
    set(missing_deps_optional)
    foreach (dep IN LISTS depends)
      list(FIND all_projects "${dep}" idx)
      if (idx EQUAL -1)
        list(APPEND missing_deps
          "${dep}")
      endif ()
    endforeach ()
    foreach (dep IN LISTS optional_depends)
      list(FIND all_projects "${dep}" idx)
      if (idx EQUAL -1)
        list(APPEND missing_deps_optional
          "${dep}")
      endif ()
    endforeach ()

    if (missing_deps_optional)
      string(REPLACE ";" ", " missing_deps_optional "${missing_deps_optional}")
      message(AUTHOR_WARNING "Optional dependencies for ${name} not found: ${missing_deps_optional}")
    endif ()
    if (missing_deps)
      string(REPLACE ";" ", " missing_deps "${missing_deps}")
      message(FATAL_ERROR "Dependencies for ${name} not found: ${missing_deps}")
    endif ()

    list(APPEND ep_arguments DEPENDS ${depends})
    set("${name}_arguments"
      "${ep_arguments}"
      PARENT_SCOPE)
  else ()
    option("ENABLE_${name}" "${help_string}" "${default}")
    # Set the TYPE because it is overrided to INTERNAL if it is required by
    # dependencies later.
    set_property(CACHE "ENABLE_${name}" PROPERTY TYPE BOOL)
    set_property(GLOBAL APPEND
      PROPERTY
        superbuild_projects "${name}")

    if (can_use_system)
      set_property(GLOBAL
        PROPERTY
          "${name}_system" TRUE)
      if (USE_SYSTEM_${name})
        set(depends)
        set(depends_optional)
      endif ()
    endif ()

    if (must_use_system)
      set_property(GLOBAL
        PROPERTY
          "${name}_system_force" TRUE)
      set(depends)
      set(depends_optional)
    endif ()

    if (allow_developer_mode)
      set_property(GLOBAL
        PROPERTY
          "${name}_developer_mode" TRUE)
    endif ()

    if (debuggable)
      set_property(GLOBAL
        PROPERTY
          "${name}_debuggable" TRUE)
    endif ()

    if (selectable)
      set_property(GLOBAL
        PROPERTY
          "superbuild_has_selectable" TRUE)
      set_property(GLOBAL
        PROPERTY
          "${project}_selectable" TRUE)
    endif ()

    set_property(GLOBAL
      PROPERTY
        "${name}_depends" ${depends})
    set_property(GLOBAL
      PROPERTY
        "${name}_depends_optional" ${optional_depends})
  endif ()
endfunction ()

# Adds a project to the list, but with a no-op build step. Useful for "feature"
# projects to set flags.
#
# Usage:
#
#   superbuild_add_dummy_project(<name> [ARGS...])
#
# The only keyword arguments which do anything for dummy projects are the
# ``DEPENDS`` and ``DEPENDS_OPTIONAL`` keywords which are used to enforce build
# order.
function (superbuild_add_dummy_project _name)
  superbuild_add_project(${_name} "${ARGN}")

  set_property(GLOBAL
    PROPERTY
      "${_name}_is_dummy" TRUE)
endfunction ()

# Apply a patch to a project.
#
# Usage:
#
#   superbuild_apply_patch(<name> <patch-name> <description>)
#
# Applies a patch to the project during the build. The patch is assumed live at
# the following path:
#
#   ${CMAKE_CURRENT_LIST_DIR}/patches/${name}-${patch-name}.patch
#
# Patches should not be applied to projects which are sourced from Git
# repositories due to bugs in ``git apply``. Use of this function on such
# projects will cause patches to, in all probability, be ignored or fail to
# apply. For those projects, create a fork, create commits, and point the
# repository to the fork instead.
#
# This function does check if the build tree lives under a git repository and
# errors out if so since then *all* patch applications will fail.
#
# Please send relevant patches upstream.
function (superbuild_apply_patch _name _patch _comment)
  find_package(Git QUIET)
  if (NOT GIT_FOUND)
    mark_as_advanced(CLEAR GIT_EXECUTABLE)
    message(FATAL_ERROR "Could not find git executable.  Please set GIT_EXECUTABLE.")
  endif ()

  execute_process(
    COMMAND "${GIT_EXECUTABLE}"
            rev-parse
            --is-inside-work-tree
    RESULT_VARIABLE res
    OUTPUT_VARIABLE out
    ERROR_VARIABLE  err
    WORKING_DIRECTORY "${CMAKE_BINARY_DIRECTORY}"
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if (res AND NOT res EQUAL 128)
    message(FATAL_ERROR "Failed to determine if the build tree is inside of a git repository.")
  endif ()
  if (out STREQUAL "true")
    execute_process(
      COMMAND "${GIT_EXECUTABLE}"
              rev-parse
              --show-toplevel
      RESULT_VARIABLE res
      OUTPUT_VARIABLE out
      ERROR_VARIABLE  err
      WORKING_DIRECTORY "${CMAKE_BINARY_DIRECTORY}"
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if (res)
      message(WARNING
        "Failed to detect the top-level of the git repository: ${err}.")
      set(out "<unknown>")
    endif ()
    message(FATAL_ERROR
      "The build tree appears to be inside of the git repository located at "
      "${out}. This interferes with the way the superbuild applies patches to "
      "projects and is not supported. Please relocate the build tree to a "
      "directory which is not under a git repository.")
  endif ()

  superbuild_project_add_step("${_name}-patch-${_patch}"
    COMMAND   "${GIT_EXECUTABLE}"
              apply
              # Necessary for applying patches to windows-newline files.
              --whitespace=fix
              -p1
              "${CMAKE_CURRENT_LIST_DIR}/patches/${_name}-${_patch}.patch"
    DEPENDEES patch
    DEPENDERS configure
    COMMENT   "${_comment}"
    WORKING_DIRECTORY <SOURCE_DIR>)
endfunction ()

# Add CMake arguments to projects using this one.
#
# Usage:
#
#   superbuild_add_extra_cmake_args([-DREQUIRED_VARIABLE:TYPE=VALUE]...)
#
# The ``-D`` and ``TYPE`` are required (due to the way ExternalProject does
# things internally).
function (superbuild_add_extra_cmake_args)
  if (NOT superbuild_build_phase)
    return ()
  endif ()

  _superbuild_check_current_project("superbuild_add_extra_cmake_args")

  set_property(GLOBAL APPEND
    PROPERTY
      "${current_project}_cmake_args" ${ARGN})
endfunction ()

# Add a custom step to the project.
#
# Usage:
#
#   superbuild_project_add_step(myproject <step-arguments>...)
#
# See the documentation for ``ExternalProject_add_step`` for the arguments to
# this.
function (superbuild_project_add_step name)
  if (NOT superbuild_build_phase)
    return ()
  endif ()

  _superbuild_check_current_project("superbuild_project_add_step")

  set_property(GLOBAL APPEND
    PROPERTY
      "${current_project}_steps" "${name}")
  set_property(GLOBAL
    PROPERTY
      "${current_project}_step_${name}" ${ARGN})
endfunction ()

# Add flags to projects using this one.
#
# Usage:
#
#   superbuild_append_flags(<key> <value> [PROJECT_ONLY])
#
# Adds flags to the build of this and, if ``PROJECT_ONLY`` is not specified,
# dependent projects.
#
# Valid values for ``<key>`` are:
#
#   cxx_flags: add flags for C++ compilation.
#   c_flags: add flags for C compilation.
#   cpp_flags: add flags C and C++ preprocessors.
#   ld_flags: add flags for linkers.
function (superbuild_append_flags key value)
  if (NOT superbuild_build_phase)
    return ()
  endif ()

  _superbuild_check_current_project("superbuild_append_flags")

  if (NOT "x${key}" STREQUAL "xcxx_flags" AND
      NOT "x${key}" STREQUAL "xc_flags" AND
      NOT "x${key}" STREQUAL "xcpp_flags" AND
      NOT "x${key}" STREQUAL "xld_flags")
    message(AUTHOR_WARNING
      "Currently, only cxx_flags, c_flags, cpp_flags, and ld_flags are supported.")
    return ()
  endif ()

  set(project_only FALSE)
  foreach (arg IN LISTS ARGN)
    if (arg STREQUAL "PROJECT_ONLY")
      set(project_only TRUE)
    else ()
      message(AUTHOR_WARNING "Unknown argument to superbuild_append_flags(), ${arg}.")
    endif ()
  endforeach ()

  set(property "${current_project}_append_flags_cmake_${key}")
  if (project_only)
    set(property "${current_project}_append_project_only_flags_cmake_${key}")
  endif ()

  set_property(GLOBAL APPEND_STRING
    PROPERTY
      "${property}" " ${value}")
endfunction ()

# Add directories to PATH for projects using this one.
#
# Usage:
#
#   superbuild_add_path(<path>...)
#
# Adds the arguments to the ``PATH`` environment for projects which use this
# one.
function (superbuild_add_path)
  if (NOT superbuild_build_phase)
    return ()
  endif ()

  _superbuild_check_current_project("superbuild_add_path")

  set_property(GLOBAL APPEND
    PROPERTY
      "${current_project}_path" ${ARGN})
endfunction ()

# INTERNAL
# Get a list of the dependencies this project has.
#
# Usage:
#
#   _superbuild_get_project_depends(<name> <prefix>)
#
# Returns a list of projects depended on by ``<name>`` in the
# ``${prefix}_depends`` variable.
function (_superbuild_get_project_depends name prefix)
  if (NOT superbuild_build_phase)
    message(AUTHOR_WARNING "get_project_depends can only be used in build pass")
  endif ()

  if (${prefix}_${_name}_done)
    return ()
  endif ()
  set(${prefix}_${_name}_done TRUE)

  # Get regular dependencies.
  foreach (dep IN LISTS "${name}_depends")
    if (NOT ${prefix}_${dep}_done)
      list(APPEND "${prefix}_depends"
        "${dep}")
      _superbuild_get_project_depends("${dep}" "${prefix}")
    endif ()
  endforeach ()

  # Get enabled optional dependencies.
  foreach (dep IN LISTS "${name}_depends_optional")
    if (${dep}_enabled AND NOT ${prefix}_${dep}_done)
      list(APPEND "${prefix}_depends"
        "${dep}")
      _superbuild_get_project_depends("${dep}" "${prefix}")
    endif ()
  endforeach ()

  if (${prefix}_depends)
    list(REMOVE_DUPLICATES "${prefix}_depends")
  endif ()
  set("${prefix}_depends"
    "${${prefix}_depends}"
    PARENT_SCOPE)
endfunction ()

# Include all projects.
#
# Usage:
#
#   _superbuild_discover_projects(<projects...>)
#
# This runs the first pass which gathers the required dependency information
# from projects which may be enabled.
function (_superbuild_discover_projects)
  foreach (project IN LISTS ARGN)
    include("${project}")
  endforeach ()
endfunction ()

# Entry point of the build logic.
#
# Usage:
#
#   superbuild_process_dependencies()
#
# Parses all of the relevant variables created by the inclusion of all of the
# project files. It uses this information to create the build recipes for all
# of the projects with the flags propagated and dependencies sorted properly.
function (superbuild_process_dependencies)
  set(enabled_projects)

  get_property(has_selectable GLOBAL
    PROPERTY superbuild_has_selectable)

  # Gather all of the project names.
  get_property(all_projects GLOBAL
    PROPERTY superbuild_projects)
  foreach(project IN LISTS all_projects)
    get_property("${project}_depends" GLOBAL
      PROPERTY "${project}_depends")
    get_property("${project}_depends_optional" GLOBAL
      PROPERTY "${project}_depends_optional")
    get_property(selectable GLOBAL
      PROPERTY "${project}_selectable")
    set("${project}_depends_all"
      ${${project}_depends}
      ${${project}_depends_optional})

    if (has_selectable AND NOT selectable)
      set(advanced TRUE)
    else ()
      set(advanced FALSE)
    endif ()
    set_property(CACHE "ENABLE_${project}"
      PROPERTY ADVANCED "${advanced}")

    if (ENABLE_${project})
      list(APPEND enabled_projects "${project}")
    endif ()

    set("${project}_needed_by" "")
  endforeach ()
  if (NOT enabled_projects)
    message(FATAL_ERROR "No projects enabled!")
  endif ()
  list(SORT enabled_projects) # Deterministic order.

  # Order list to satisfy dependencies.
  # First only use the non-optional dependencies.
  include(TopologicalSort)
  topological_sort(enabled_projects "" _depends)

  # Now generate a project order using both, optional and non-optional
  # dependencies.
  set(ordered_projects "${enabled_projects}")
  topological_sort(ordered_projects "" _depends_all)

  # Update enabled_projects to be in the correct order taking into
  # consideration optional dependencies.
  set(new_order)
  foreach (project IN LISTS ordered_projects)
    list(FIND enabled_projects "${project}" found)
    if (found GREATER -1)
      list(APPEND new_order "${project}")
    endif ()
  endforeach ()
  set(enabled_projects ${new_order})

  # Enable enabled projects.
  foreach (project IN LISTS enabled_projects)
    _superbuild_enable_project("${project}" "")
    # Also enable dependent projects.
    foreach (dep IN LISTS "${project}_depends")
      _superbuild_enable_project("${dep}" "${project}")
    endforeach ()
  endforeach ()

  # Log all of the enabled projects and why they are enabled.
  foreach (project IN LISTS enabled_projects)
    list(SORT "${project}_needed_by")
    list(REMOVE_DUPLICATES "${project}_needed_by")

    if (ENABLE_${project})
      message(STATUS "Enabling ${project} as requested.")
    else ()
      string(REPLACE ";" ", " required_by "${${project}_needed_by}")
      message(STATUS "Enabling ${project} for: ${required_by}")
      set_property(CACHE "ENABLE_${project}" PROPERTY TYPE INTERNAL)
    endif ()
  endforeach ()

  # Log all of the projects which will be built (in build order).
  string(REPLACE ";" ", " enabled "${enabled_projects}")
  message(STATUS "Building projects: ${enabled}")

  set(system_projects)

  # Start the second phase of the build.
  set(superbuild_build_phase TRUE)
  foreach (project IN LISTS enabled_projects)
    get_property(can_use_system GLOBAL
      PROPERTY "${project}_system" SET)
    get_property(must_use_system GLOBAL
      PROPERTY "${project}_system_force" SET)
    if (must_use_system)
      set(can_use_system TRUE)
      set("USE_SYSTEM_${project}" TRUE)
    elseif (can_use_system)
      # For every enabled project that can use system, expose the option to the
      # user.
      cmake_dependent_option("USE_SYSTEM_${project}" "" OFF
        "${project}_enabled" OFF)
    endif ()

    set("${project}_built_by_superbuild" TRUE)
    if (USE_SYSTEM_${project})
      set("${project}_built_by_superbuild" FALSE)
    endif ()

    get_property(allow_developer_mode GLOBAL
      PROPERTY "${project}_developer_mode" SET)
    if (allow_developer_mode)
      # For every enabled project that can be used in developer mode, expose
      # the option to the user.
      # TODO: Make DEVELOPER_MODE a single option with the *value* being the
      # project to build as a developer mode.
      cmake_dependent_option("DEVELOPER_MODE_${project}" "" OFF
        "${project}_enabled" OFF)
    endif ()

    get_property(debuggable GLOBAL
      PROPERTY "${project}_debuggable" SET)
    if (WIN32 AND CMAKE_BUILD_TYPE STREQUAL "Debug")
      # Release and RelWithDebInfo is not mixable with Debug builds, so just
      # don't support it.
      set(debuggable FALSE)
    endif ()
    if (debuggable)
      set("CMAKE_BUILD_TYPE_${project}" "<same>"
        CACHE STRING "The build type for the ${project} project.")
      set_property(CACHE "CMAKE_BUILD_TYPE_${project}"
        PROPERTY
          STRINGS "<same>;Release;RelWithDebInfo")
      if (NOT WIN32)
        set_property(CACHE "CMAKE_BUILD_TYPE_${project}" APPEND
          PROPERTY
            STRINGS "Debug")
      endif ()
    endif ()

    set(current_project "${project}")

    get_property(is_dummy GLOBAL
      PROPERTY "${project}_is_dummy")
    if (can_use_system AND USE_SYSTEM_${project})
      list(APPEND system_projects
        "${project}")
      _superbuild_add_dummy_project_internal("${project}")
      include("${project}.system")
    elseif (allow_developer_mode AND DEVELOPER_MODE_${project})
      set(requiring_packages)
      foreach (dep IN LISTS ${project}_needed_by)
        # Verify all dependencies are in DEVELOPER_MODE.
        if (NOT DEVELOPER_MODE_${dep})
          list(APPEND requiring_packages "${dep}")
        endif ()
      endforeach ()

      if (requiring_packages)
        string(REPLACE ";" ", " requiring_packages "${requiring_packages}")
        message(FATAL_ERROR "${project} is in developer mode, but is required by: ${requiring_packages}.")
      endif ()

      include("${project}")
      _superbuild_write_developer_mode_cache("${project}" "${${project}_arguments}")
    elseif (is_dummy)
      # This project isn't built, just used as a graph node to represent a
      # group of dependencies.
      include("${project}")
      _superbuild_add_dummy_project_internal("${project}")
    else ()
      include("${project}")
      _superbuild_add_project_internal("${project}" "${${project}_arguments}")
    endif ()
  endforeach ()

  foreach (project IN LISTS all_projects)
    set("${project}_enabled"
      "${${project}_enabled}"
      PARENT_SCOPE)
  endforeach ()
  set(enabled_projects
    "${enabled_projects}"
    PARENT_SCOPE)
  set(system_projects
    "${system_projects}"
    PARENT_SCOPE)
endfunction ()

# INTERNAL
# Sets properties properly when enabling a project.
function (_superbuild_enable_project name needed_by)
  set("${name}_enabled" TRUE
    PARENT_SCOPE)

  if (needed_by)
    list(APPEND "${name}_needed_by"
      "${needed_by}")
    set("${name}_needed_by"
      "${${name}_needed_by}"
      PARENT_SCOPE)
  endif ()
endfunction ()

# INTERNAL
# Implementation of building a dummy project.
function (_superbuild_add_dummy_project_internal name)
  _superbuild_get_project_depends("${name}" arg)

  ExternalProject_add("${name}"
    DEPENDS           ${arg_depends}
    INSTALL_DIR       "${superbuild_install_location}"
    DOWNLOAD_COMMAND  ""
    SOURCE_DIR        ""
    UPDATE_COMMAND    ""
    CONFIGURE_COMMAND ""
    BUILD_COMMAND     ""
    INSTALL_COMMAND   "")
endfunction ()

# INTERNAL
# Implementation of building an actual project.
function (_superbuild_add_project_internal name)
  set(cmake_params)
  # Pass down C and CXX flags from this project.
  foreach (flag IN ITEMS
      CMAKE_C_FLAGS_DEBUG
      CMAKE_C_FLAGS_MINSIZEREL
      CMAKE_C_FLAGS_RELEASE
      CMAKE_C_FLAGS_RELWITHDEBINFO
      CMAKE_CXX_FLAGS_DEBUG
      CMAKE_CXX_FLAGS_MINSIZEREL
      CMAKE_CXX_FLAGS_RELEASE
      CMAKE_CXX_FLAGS_RELWITHDEBINFO)
    if (${flag})
      list(APPEND cmake_params "-D${flag}:STRING=${${flag}}")
    endif ()
  endforeach ()

  # Handle the DEBUGGABLE flag setting.
  if (debuggable AND NOT CMAKE_BUILD_TYPE_${name} STREQUAL "<same>")
    list(APPEND cmake_params "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE_${name}}")
    string(TOUPPER "${CMAKE_BUILD_TYPE_${name}}" project_build_type)
  else ()
    list(APPEND cmake_params "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}")
    string(TOUPPER "${CMAKE_BUILD_TYPE}" project_build_type)
  endif ()
  set(project_c_flags_buildtype "${CMAKE_C_FLAGS_${project_build_type}}")
  set(project_cxx_flags_buildtype "${CMAKE_CXX_FLAGS_${project_build_type}}")

  # Set SDK and target version flags.
  superbuild_osx_pass_version_flags(apple_flags)

  # Get the flags from dependent projects.
  _superbuild_fetch_cmake_args("${name}" cmake_dep_args)
  list(APPEND cmake_params
    ${apple_flags}
    ${cmake_dep_args})

  # Get extra flags added using superbuild_append_flags(), if any.
  set(extra_vars
    c_flags
    cxx_flags
    cpp_flags
    ld_flags)
  foreach (extra_var IN LISTS extra_vars)
    set("extra_${extra_var}")
  endforeach ()
  set(extra_paths)

  _superbuild_get_project_depends("${name}" arg)

  # Scan for project flags.
  foreach (var IN LISTS extra_vars)
    get_property(extra_flags GLOBAL
      PROPERTY "${name}_append_project_only_flags_cmake_${var}")

    set("extra_${var}"
      "${extra_${var}} ${extra_flags}")
  endforeach ()

  # Scan for dependency flags.
  _superbuild_get_project_depends("${name}" arg)
  foreach (dep IN LISTS arg_depends)
    foreach (var IN LISTS extra_vars)
      get_property(extra_flags GLOBAL
        PROPERTY "${dep}_append_flags_cmake_${var}")

      set("extra_${var}"
        "${extra_${var}} ${extra_flags}")
    endforeach ()

    get_property(dep_paths GLOBAL
      PROPERTY "${dep}_path")
    if (dep_paths)
      list(APPEND extra_paths
        "${dep_paths}")
    endif ()
  endforeach ()

  foreach (var IN LISTS extra_vars)
    set("project_${var}" "${superbuild_${var}}")
    if (extra_${var})
      set("project_${var}" "${project_${var}} ${extra_${var}}")
    endif ()
  endforeach ()

  # Get the information about where this project comes from.
  get_property("${name}_revision" GLOBAL
    PROPERTY "${name}_revision")
  if (NOT ${name}_revision)
    message(FATAL_ERROR "Missing revision information for ${name}.")
  endif ()

  set(build_env)
  if (NOT MSVC)
    list(APPEND build_env
      LDFLAGS "${project_ld_flags}"
      CPPFLAGS "${project_cpp_flags} ${project_cxx_flags_buildtype}"
      CXXFLAGS "${project_cxx_flags} ${project_cxx_flags_buildtype}"
      CFLAGS "${project_c_flags} ${project_c_flags_buildtype}")
  endif ()

  if (APPLE)
    # disabling this since it fails when building numpy.
    #list(APPEND build_env
    #  MACOSX_DEPLOYMENT_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}")
  endif ()

  list(INSERT extra_paths 0
    "${superbuild_install_location}/bin")
  list(REMOVE_DUPLICATES extra_paths)

  if (WIN32)
    string(REPLACE ";" "${_superbuild_list_separator}" extra_paths "${extra_paths}")
  else ()
    string(REPLACE ";" ":" extra_paths "${extra_paths}")
  endif ()
  list(APPEND build_env
    PATH "${extra_paths}")

  if (WIN32)
    # No special environment to set.
  elseif (APPLE)
    # No special environment to set.
  elseif (UNIX)
    set(ld_library_path_argument)
    superbuild_unix_ld_library_path_hack(ld_library_path_argument)

    list(APPEND build_env
      ${ld_library_path_argument})
  endif ()
  list(APPEND build_env PKG_CONFIG_PATH "${superbuild_pkg_config_path}")

  set(binary_dir BINARY_DIR "${name}/build")
  list(FIND ARGN "BUILD_IN_SOURCE" in_source)
  if (in_source GREATER -1)
    set(binary_dir)
  endif ()

  set(source_dir SOURCE_DIR "${name}/src")
  list(FIND "${name}_revision" "SOURCE_DIR" ext_source)
  if (ext_source GREATER -1)
    set(source_dir)
  endif ()

  # ARGN needs to be quoted so that empty list items aren't removed if that
  # happens options like INSTALL_COMMAND "" won't work.
  _superbuild_ExternalProject_add(${name} "${ARGN}"
    PREFIX        "${name}"
    DOWNLOAD_DIR  "${superbuild_download_location}"
    STAMP_DIR     "${name}/stamp"
    ${source_dir}
    ${binary_dir}
    INSTALL_DIR   "${superbuild_install_location}"

    # Add source information specified in versions functions.
    ${${name}_revision}

    PROCESS_ENVIRONMENT
      "${build_env}"
      CMAKE_PREFIX_PATH "${superbuild_prefix_path}"
    CMAKE_ARGS
      --no-warn-unused-cli
      -DCMAKE_INSTALL_PREFIX:PATH=${superbuild_prefix_path}
      -DCMAKE_PREFIX_PATH:PATH=${superbuild_prefix_path}
      -DCMAKE_C_FLAGS:STRING=${project_c_flags}
      -DCMAKE_CXX_FLAGS:STRING=${project_cxx_flags}
      -DCMAKE_SHARED_LINKER_FLAGS:STRING=${project_ld_flags}
      ${cmake_params}

    LIST_SEPARATOR "${_superbuild_list_separator}")

  # Declare additional steps.
  get_property(additional_steps GLOBAL
    PROPERTY "${name}_steps")
  if (additional_steps)
    foreach (step IN LISTS additional_steps)
      get_property(step_arguments GLOBAL
        PROPERTY "${name}_step_${step}")
      ExternalProject_add_step("${name}" "${step}"
        "${step_arguments}")
    endforeach ()
  endif ()
endfunction ()

# INTERNAL
# Wrapper around ExternalProject's internal calls to gather the CMake flags
# that would be passed to a project if it were enabled.
function (_superbuild_write_developer_mode_cache name)
  set(cmake_args
    "-DCMAKE_PREFIX_PATH:PATH=${superbuild_prefix_path}")
  if (debuggable AND NOT CMAKE_BUILD_TYPE_${name} STREQUAL "<same>")
    list(APPEND cmake_args
      "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE_${name}}")
  else ()
    list(APPEND cmake_args
      "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}")
  endif ()

  list(APPEND cmake_args
    "-DSUPERBUILD_DEVELOPER_MODE_ROOT:PATH=${superbuild_prefix_path}")

  superbuild_osx_pass_version_flags(apple_args)
  _superbuild_fetch_cmake_args("${name}" cmake_dep_args)
  list(APPEND cmake_args
    ${apple_args}
    ${cmake_dep_args})

  set(skip TRUE)
  foreach (arg IN LISTS ARGN)
    if (arg STREQUAL "CMAKE_ARGS")
      set(skip FALSE)
    elseif (arg STREQUAL "DEPENDS")
      set(skip TRUE)
    elseif (arg MATCHES _ep_keywords__superbuild_ExternalProject_add)
      set(skip TRUE)
    elseif (NOT skip)
      list(APPEND cmake_args
        "${arg}")
    endif ()
  endforeach ()

  # Create the target.
  _superbuild_add_dummy_project_internal("${name}")

  set(cache_file "${CMAKE_BINARY_DIR}/${name}-developer-config.cmake")
  if (COMMAND _ep_command_line_to_initial_cache)
    # Upstream ExternalProject changed its argument parsing. Since these are
    # internal functions, go with the flow.
    _ep_command_line_to_initial_cache(cmake_args "${cmake_args}" 0)
  endif ()
  _ep_write_initial_cache(${name} "${cache_file}" "${cmake_args}")
endfunction ()

# INTERNAL
# Queries dependencies for their CMake flags they declare.
function (_superbuild_fetch_cmake_args name var)
  # Get extra cmake args from every dependent project, if any.
  _superbuild_get_project_depends("${name}" arg)
  set(cmake_params)
  foreach (dep IN LISTS arg_depends)
    get_property(cmake_args GLOBAL
      PROPERTY "${dep}_cmake_args")
    list(APPEND cmake_params
      ${cmake_args})
  endforeach ()

  set("${var}"
    ${cmake_params}
    PARENT_SCOPE)
endfunction ()

# Readies an argument which may contain ';' for use in ExternalProject_add.
#
# Usually you shouldn't need this, but in case you do.
function (superbuild_sanitize_lists_in_string out_var_prefix var)
  string(REPLACE ";" "${_superbuild_list_separator}" command "${${var}}")
  set("${out_var_prefix}${var}" "${command}"
    PARENT_SCOPE)
endfunction ()

# INTERNAL
# Checks that a project name is valid.
#
# Currently "valid" means alphanumeric with a non-numeric prefix.
function (_superbuild_project_check_name name)
  if (NOT name MATCHES "^[a-zA-Z][a-zA-Z0-9]*$")
    message(FATAL_ERROR "Invalid project name: ${_name}. "
                        "Only alphanumerics are allowed.")
  endif ()
endfunction ()

# INTERNAL
# Checkpoint function to ensure that the phases are well-separated.
function (_superbuild_check_current_project func)
  if (NOT current_project)
    message(AUTHOR_WARNING "${func} called at an incorrect stage.")
    return ()
  endif ()
endfunction ()

# Add a project to be built via Python's setup.py routine.
#
# Usage:
#
#   superbuild_add_project_python(<name> <args>...)
#
# Same as ``superbuild_add_project``, but sets the ``PYTHONPATH`` and build
# commands to work properly out of the box. See ``superbuild_add_project`` its
# argument documentation.
macro (superbuild_add_project_python _name)
  if (WIN32)
    set(_superbuild_python_path <INSTALL_DIR>/bin/Lib/site-packages)
    set(_superbuild_python_args
      "--prefix=bin")
  else ()
    set(_superbuild_python_path <INSTALL_DIR>/lib/python2.7/site-packages)
    set(_superbuild_python_args
      "--single-version-externally-managed"
      "--prefix=")
  endif ()

  superbuild_add_project("${_name}"
    BUILD_IN_SOURCE 1
    DEPENDS python ${ARGN}
    CONFIGURE_COMMAND
      ""
    BUILD_COMMAND
      "${superbuild_python_executable}"
        setup.py
        build
    INSTALL_COMMAND
      "${superbuild_python_executable}"
        setup.py
        install
        --skip-build
        --root=<INSTALL_DIR>
        ${_superbuild_python_args}
    PROCESS_ENVIRONMENT
      PYTHONPATH ${_superbuild_python_path})
endmacro ()
