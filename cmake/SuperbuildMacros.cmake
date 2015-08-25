include(SuperbuildExternalProject)
include(CMakeParseArguments)

#------------------------------------------------------------------------------
function (superbuild_add_project name)
  _superbuild_project_check_name("${name}")

  if (superbuild_build_phase)
    set(arguments)
    set(optional_depends)
    set(accumulate FALSE)

    foreach (arg IN LISTS ARGN)
      if (arg STREQUAL "DEPENDS_OPTIONAL")
        set(accumulate TRUE)
      elseif (arg MATCHES "${_ep_keywords_ExternalProject_Add}")
        set(accumulate FALSE)
      elseif (accumulate)
        list(APPEND optional_depends
          "${arg}")
      endif ()

      if (NOT accumulate)
        list(APPEND arguments
          "${arg}")
      endif ()
    endforeach ()

    foreach (op_dep IN LISTS optional_depends)
      if (${op_dep}_enabled)
        list(APPEND arguments
          DEPENDS "${op_dep}")
      endif ()
    endforeach ()
    set("${name}_arguments"
      "${arguments}"
      PARENT_SCOPE)
  else ()
    set(flags
      CAN_USE_SYSTEM)
    set(keys
      DEPENDS DEPENDS_OPTIONAL)
    cmake_parse_arguments(_args "${flags}" "${keys}" "" ${ARGN})

    option("ENABLE_${name}" "Request to build project ${name}" OFF)
    # Set the TYPE because it is overrided to INTERNAL if it is required by
    # dependencies later.
    set_property(CACHE "ENABLE_${project}" PROPERTY TYPE BOOL)
    set_property(GLOBAL APPEND
      PROPERTY
        superbuild_projects "${name}")

    if (_args_CAN_USE_SYSTEM)
      set_property(GLOBAL
        PROPERTY
          "${name}_system" TRUE)
      if (USE_SYSTEM_${name})
        set(_args_DEPENDS "")
        set(_args_DEPENDS_OPTIONAL "")
      endif ()
    endif ()

    set_property(GLOBAL
      PROPERTY
        "${name}_depends" ${_args_DEPENDS})
    set_property(GLOBAL
      PROPERTY
        "${name}_depends_optional" ${_args_DEPENDS_OPTIONAL})
  endif ()
endfunction ()

#------------------------------------------------------------------------------
# adds a dummy project to the build, which is a great way to setup a list
# of dependencies as a build option. IE dummy project that turns on all
# third party libraries
function (superbuild_add_dummy_project _name)
  superbuild_add_project(${_name} "${ARGN}")

  set_property(GLOBAL
    PROPERTY
      "${_name}_is_dummy" TRUE)
endfunction ()

function (superbuild_add_extra_cmake_args)
  if (NOT superbuild_build_phase)
    return ()
  endif ()

  _superbuild_check_current_project("add_extra_cmake_args")

  set_property(GLOBAL APPEND
    PROPERTY
      "${current_project}_cmake_args" ${ARGN})
endfunction ()

#------------------------------------------------------------------------------
function (superbuild_project_add_step name)
  if (NOT superbuild_build_phase)
    return ()
  endif ()

  _superbuild_check_current_project("add_external_project_step")

  set_property(GLOBAL APPEND
    PROPERTY
      "${current_project}_steps" "${name}")
  set_property(GLOBAL
    PROPERTY
      "${current_project}_step_${name}" ${ARGN})
endfunction ()

#------------------------------------------------------------------------------
# In case of OpenMPI on Windows, for example, we need to pass extra compiler
# flags when building projects that use MPI. This provides an experimental
# mechanism for the same.
# There are two kinds of flags, those to use to build to the project itself, or
# those to use to build any dependencies. The default is the latter. For former,
# pass in an optional argument PROJECT_ONLY.
function (superbuild_append_flags key value)
  if (NOT "x${key}" STREQUAL "xCMAKE_CXX_FLAGS" AND
      NOT "x${key}" STREQUAL "xCMAKE_C_FLAGS" AND
      NOT "x${key}" STREQUAL "xLDFLAGS")
    message(AUTHOR_WARNING
      "Currently, only CMAKE_CXX_FLAGS, CMAKE_C_FLAGS, and LDFLAGS are supported.")
  endif ()

  set(project_only FALSE)
  foreach (arg IN LISTS ARGN)
    if (arg STREQUAL "PROJECT_ONLY")
      set(project_only TRUE)
    else ()
      message(AUTHOR_WARNING "Unknown argument to append_flags(), ${arg}.")
    endif ()
  endforeach ()

  if (build-projects)
    _superbuild_check_current_project("append_flags")

    set(property "${current_project}_append_flags_${key}")
    if (project_only)
      set(property "${current_project}_append_project_only_flags_${key}")
    endif ()

    set_property(GLOBAL APPEND
      PROPERTY
        "${property}" "${value}")
  endif ()
endfunction ()

#------------------------------------------------------------------------------
# internal macro to validate project names.
function (_superbuild_project_check_name name)
  if (NOT name MATCHES "^[a-zA-Z][a-zA-Z0-9]*$")
    message(FATAL_ERROR "Invalid project name: ${_name}")
  endif ()
endfunction ()

function (_superbuild_check_current_project func)
  if (NOT current_project)
    message(AUTHOR_WARNING "${func} called an incorrect stage.")
    return ()
  endif ()
endfunction ()