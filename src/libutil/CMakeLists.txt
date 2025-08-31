# Copyright Contributors to the OpenImageIO project.
# SPDX-License-Identifier: Apache-2.0
# https://github.com/AcademySoftwareFoundation/OpenImageIO

set (libOpenImageIO_Util_srcs argparse.cpp benchmark.cpp
                  errorhandler.cpp farmhash.cpp filesystem.cpp
                  fmath.cpp filter.cpp hashes.cpp paramlist.cpp
                  plugin.cpp SHA1.cpp
                  strutil.cpp sysutil.cpp thread.cpp timer.cpp
                  typedesc.cpp ustring.cpp xxhash.cpp)

if (CMAKE_COMPILER_IS_GNUCC AND NOT ${GCC_VERSION} VERSION_LESS 9.0)
    set_property (SOURCE SHA1.cpp
                  APPEND PROPERTY COMPILE_OPTIONS -Wno-stringop-truncation)
endif ()

if (CMAKE_UNITY_BUILD)
    # If unity builds are occurring, fmath.cpp MUST be compiled alone. But the
    # rest can be built together if in group mode.
    set_property (SOURCE fmath.cpp APPEND PROPERTY SKIP_UNITY_BUILD_INCLUSION TRUE)
    set_source_files_properties (${libOpenImageIO_Util_srcs}
                                 PROPERTIES UNITY_GROUP utilsrc)
endif ()


set (OpenImageIO_Util_LINK_FLAGS "${VISIBILITY_MAP_COMMAND} ${EXTRA_DSO_LINK_ARGS}")
if (UNIX AND NOT APPLE)
    # Hide symbols from any static dependent libraries embedded here.
    set (OpenImageIO_Util_LINK_FLAGS "${OpenImageIO_Util_LINK_FLAGS} -Wl,--exclude-libs,ALL")
endif ()


function (setup_oiio_util_library targetname)
    if (BUILD_SHARED_LIBS AND NOT targetname MATCHES "static")
        set (libtype SHARED)
    else ()
        set (libtype STATIC)
    endif ()
    
    if (WIN32)
        configure_file(../build-scripts/version_win32.rc.in "${CMAKE_CURRENT_BINARY_DIR}/version_win32.rc" @ONLY)
        add_library (${targetname} ${libtype} ${libOpenImageIO_Util_srcs} ${CMAKE_CURRENT_BINARY_DIR}/version_win32.rc)
    else ()
        add_library (${targetname} ${libtype} ${libOpenImageIO_Util_srcs})
    endif ()

    target_compile_definitions(${targetname} PRIVATE
                               ${${PROJECT_NAME}_compile_definitions})
    target_compile_options(${targetname} PRIVATE
                               ${${PROJECT_NAME}_compile_options})
    target_link_options(${targetname} PRIVATE
                               ${${PROJECT_NAME}_link_options})

    target_include_directories (${targetname}
            PUBLIC
                $<BUILD_INTERFACE:${OpenImageIO_LOCAL_DEPS_ROOT}/include>
                $<INSTALL_INTERFACE:include>
            PRIVATE
                ${ROBINMAP_INCLUDES}
            )
    target_link_libraries (${targetname}
            PUBLIC
                $<TARGET_NAME_IF_EXISTS:Threads::Threads>
                ${GCC_ATOMIC_LIBRARIES}
                ${OPENIMAGEIO_IMATH_DEPENDENCY_VISIBILITY}
                ${OPENIMAGEIO_IMATH_TARGETS}
            PRIVATE
                $<TARGET_NAME_IF_EXISTS:TBB::tbb>
                ${CMAKE_DL_LIBS}
            )

    if (GCC_VERSION VERSION_GREATER_EQUAL 12.0
          AND GCC_VERSION VERSION_LESS 14.0
          AND CMAKE_CXX_STANDARD VERSION_GREATER_EQUAL 23)
        target_link_libraries (${targetname} PRIVATE stdc++_libbacktrace)
    elseif (GCC_VERSION VERSION_GREATER_EQUAL 14.0
            AND CMAKE_CXX_STANDARD VERSION_GREATER_EQUAL 23)
        target_link_libraries (${targetname} PRIVATE stdc++exp)
    endif ()

    if (OIIO_INTERNALIZE_FMT OR fmt_LOCAL_BUILD)
        add_dependencies(${targetname} fmt_internal_target)
    else ()
        target_link_libraries (${targetname}
                               PUBLIC fmt::fmt-header-only)
    endif ()

    if (WIN32)
        target_compile_definitions(${targetname} PRIVATE
                                   WIN32_LEAN_AND_MEAN NOMINMAX
                                   NOGDI VC_EXTRALEAN)
        target_link_libraries (${targetname} PRIVATE psapi)
    endif()

    target_compile_definitions (${targetname} PRIVATE OpenImageIO_EXPORTS)


    if (NOT BUILD_SHARED_LIBS OR targetname MATCHES "static")
        target_compile_definitions (${targetname} PUBLIC OIIO_STATIC_DEFINE=1)
    endif ()

    # Propagate C++ minimum to downstream consumers
    target_compile_features (${targetname}
                             INTERFACE cxx_std_${DOWNSTREAM_CXX_STANDARD})

    set_target_properties(${targetname}
                          PROPERTIES
                             VERSION     ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}
                             SOVERSION   ${SOVERSION}
                             OUTPUT_NAME ${targetname}${OIIO_LIBNAME_SUFFIX}
                             POSITION_INDEPENDENT_CODE ON
                         )

    set_target_properties (${targetname} PROPERTIES
                           LINK_FLAGS ${OpenImageIO_Util_LINK_FLAGS})
    
    if (SKBUILD)
        set (PYTHON_SITE_DIR .)
        install_targets (NAMELINK_SKIP ${targetname})
    else ()
        install_targets (${targetname})
    endif ()

endfunction()


setup_oiio_util_library (OpenImageIO_Util)

option (OpenImageIO_BUILD_STATIC_UTIL_LIBRARY
        "Build additional static OpenImageIO_Util_static library" OFF)
if (OpenImageIO_BUILD_STATIC_UTIL_LIBRARY)
    setup_oiio_util_library (OpenImageIO_Util_static)
endif ()


if (OIIO_BUILD_TESTS AND BUILD_TESTING)
endif ()
