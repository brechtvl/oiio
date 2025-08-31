# Copyright Contributors to the OpenImageIO project.
# SPDX-License-Identifier: Apache-2.0
# https://github.com/AcademySoftwareFoundation/OpenImageIO/

include (CTest)

# Make a build/platform/testsuite directory, and copy the master runtest.py
# there. The rest is up to the tests themselves.
file (MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/testsuite")
file (COPY "${CMAKE_CURRENT_SOURCE_DIR}/testsuite/common"
      DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/testsuite")
add_custom_command (OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/testsuite/runtest.py"
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${CMAKE_CURRENT_SOURCE_DIR}/testsuite/runtest.py"
                        "${CMAKE_CURRENT_BINARY_DIR}/testsuite/runtest.py"
                    MAIN_DEPENDENCY "${CMAKE_CURRENT_SOURCE_DIR}/testsuite/runtest.py")
add_custom_target ( CopyFiles ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/testsuite/runtest.py" )

# set(OIIO_TESTSUITE_IMAGEDIR "${PROJECT_SOURCE_DIR}/.." CACHE PATH
set(OIIO_TESTSUITE_IMAGEDIR "${PROJECT_BINARY_DIR}/testsuite" CACHE PATH
    "Location of oiio-images, openexr-images, libtiffpic, etc.." )



# oiio_add_tests() - add a set of test cases.
#
# Usage:
#   oiio_add_tests ( test1 [ test2 ... ]
#                    [ IMAGEDIR name_of_reference_image_directory ]
#                    [ URL http://find.reference.cases.here.com ]
#                    [ FOUNDVAR variable_name ... ]
#                    [ ENABLEVAR variable_name ... ]
#                    [ SUFFIX suffix ]
#                    [ ENVIRONMENT "VAR=value" ... ]
#                  )
#
# The optional argument IMAGEDIR is used to check whether external test images
# (not supplied with OIIO) are present, and to disable the test cases if
# they're not.  If IMAGEDIR is present, URL should also be included to tell
# the user where to find such tests.
#
# The optional FOUNDVAR introduces variables (typically Foo_FOUND) that if
# not existing and true, will skip the test.
#
# The optional ENABLEVAR introduces variables (typically ENABLE_Foo) that
# if existing and yet false, will skip the test.
#
# The optional SUFFIX is appended to the test name.
#
# The optinonal ENVIRONMENT is a list of environment variables to set for the
# test.
#
macro (oiio_add_tests)
    cmake_parse_arguments (_ats "" "SUFFIX;TESTNAME" "URL;IMAGEDIR;LABEL;FOUNDVAR;ENABLEVAR;ENVIRONMENT" ${ARGN})
       # Arguments: <prefix> <options> <one_value_keywords> <multi_value_keywords> args...
    set (_ats_testdir "${OIIO_TESTSUITE_IMAGEDIR}/${_ats_IMAGEDIR}")
    # If there was a FOUNDVAR param specified and that variable name is
    # not defined, mark the test as broken.
    foreach (_var ${_ats_FOUNDVAR})
        if (NOT ${_var})
            set (_ats_LABEL "broken")
        endif ()
    endforeach ()
    set (_test_disabled 0)
    foreach (_var ${_ats_ENABLEVAR})
        if ((NOT "${${_var}}" STREQUAL "" AND NOT "${${_var}}") OR
            (NOT "$ENV{${_var}}" STREQUAL "" AND NOT "$ENV{${_var}}"))
            set (_ats_LABEL "broken")
            set (_test_disabled 1)
        endif ()
    endforeach ()
    # For OCIO 2.2+, have the testsuite use the default built-in config
    list (APPEND _ats_ENVIRONMENT "OCIO=ocio://default"
                                  "OIIO_TESTSUITE_OCIOCONFIG=ocio://default")
    if (_test_disabled)
        message (STATUS "Skipping test(s) ${_ats_UNPARSED_ARGUMENTS} because of disabled ${_ats_ENABLEVAR}")
    elseif (_ats_IMAGEDIR AND NOT EXISTS ${_ats_testdir})
        # If the directory containing reference data (images) for the test
        # isn't found, point the user at the URL.
        message (STATUS "\n\nDid not find ${_ats_testdir}")
        message (STATUS "  -> Will not run tests ${_ats_UNPARSED_ARGUMENTS}")
        message (STATUS "  -> You can find it at ${_ats_URL}\n")
    else ()
        # Add the tests if all is well.
        set (_has_generator_expr TRUE)
        set (_testsuite "${CMAKE_SOURCE_DIR}/testsuite")
        foreach (_testname ${_ats_UNPARSED_ARGUMENTS})
            set (_testsrcdir "${_testsuite}/${_testname}")
            set (_testdir "${CMAKE_BINARY_DIR}/testsuite/${_testname}${_ats_SUFFIX}")
            if (_ats_TESTNAME)
                set (_testname "${_ats_TESTNAME}")
            endif ()
            if (_ats_SUFFIX)
                set (_testname "${_testname}${_ats_SUFFIX}")
            endif ()
            if (_ats_LABEL MATCHES "broken")
                set (_testname "${_testname}-broken")
            endif ()

            set (_runtest ${Python3_EXECUTABLE} "${CMAKE_SOURCE_DIR}/testsuite/runtest.py" ${_testdir})
            if (MSVC_IDE)
                set (_runtest ${_runtest} --devenv-config $<CONFIGURATION>
                                          --solution-path "${CMAKE_BINARY_DIR}" )
            endif ()

            file (MAKE_DIRECTORY "${_testdir}")

            add_test ( NAME ${_testname} COMMAND ${_runtest} )
            set_property(TEST ${_testname} APPEND PROPERTY ENVIRONMENT
                             "OIIO_TESTSUITE_ROOT=${_testsuite}"
                             "OIIO_TESTSUITE_SRC=${_testsrcdir}"
                             "OIIO_TESTSUITE_CUR=${_testdir}"
                             ${_ats_ENVIRONMENT})
            if (NOT ${_ats_testdir} STREQUAL "")
                set_property(TEST ${_testname} APPEND PROPERTY ENVIRONMENT
                             "OIIO_TESTSUITE_IMAGEDIR=${_ats_testdir}")
            endif()

        endforeach ()
        message (VERBOSE "TESTS: ${_ats_UNPARSED_ARGUMENTS}")
    endif ()
endmacro ()



# The tests are organized into a macro so it can be called after all the
# directories with plugins are included.
#
macro (oiio_add_all_tests)


    oiio_add_tests (png png-damaged
                    ENABLEVAR ENABLE_PNG
                    IMAGEDIR oiio-images/png)
endmacro()


set (OIIO_LOCAL_TESTDATA_ROOT "${CMAKE_SOURCE_DIR}/.." CACHE PATH
     "Directory to check for local copies of testsuite data")
option (OIIO_DOWNLOAD_MISSING_TESTDATA "Try to download any missing test data" OFF)

function (oiio_get_test_data name)
    cmake_parse_arguments (_ogtd "" "REPO;BRANCH" "" ${ARGN})
       # Arguments: <prefix> <options> <one_value_keywords> <multi_value_keywords> args...
    if (IS_DIRECTORY "${OIIO_LOCAL_TESTDATA_ROOT}/${name}"
        AND NOT EXISTS "${CMAKE_BINARY_DIR}/testsuite/${name}")
        set (_ogtd_LINK_RESULT "")
        message (STATUS "Linking ${name} from ${OIIO_LOCAL_TESTDATA_ROOT}/${name}")
        file (CREATE_LINK "${OIIO_LOCAL_TESTDATA_ROOT}/${name}"
                          "${CMAKE_BINARY_DIR}/testsuite/${name}"
                          SYMBOLIC RESULT _ogtd_LINK_RESULT)
        # Note: Using 'COPY_ON_ERROR' in the above command should have prevented the need to
        # have the manual fall-back below. However, there's been at least one case where a user
        # noticed that copying did not happen if creating the link failed (CMake 3.24). We can
        # adjust this in the future if CMake behavior improves.
        message (VERBOSE "Link result ${_ogtd_LINK_RESULT}")
        if (NOT _ogtd_LINK_RESULT EQUAL 0)
            # Older cmake or failure to link -- copy
            message (STATUS "Copying ${name} from ${OIIO_LOCAL_TESTDATA_ROOT}/${name}")
            file (COPY "${OIIO_LOCAL_TESTDATA_ROOT}/${name}"
                  DESTINATION "${CMAKE_BINARY_DIR}/testsuite")
        endif ()
    elseif (IS_DIRECTORY "${CMAKE_BINARY_DIR}/testsuite/${name}")
        message (STATUS "Test data for ${name} already present in testsuite")
    elseif (OIIO_DOWNLOAD_MISSING_TESTDATA AND _ogtd_REPO)
        # Test data directory didn't exist -- fetch it
        message (STATUS "Cloning ${name} from ${_ogtd_REPO}")
        if (NOT _ogtd_BRANCH)
            set (_ogtd_BRANCH main)
        endif ()
        find_package (Git)
        if (Git_FOUND AND GIT_EXECUTABLE)
            execute_process(COMMAND ${GIT_EXECUTABLE} clone --depth 1
                                    ${_ogtd_REPO} -b ${_ogtd_BRANCH}
                                    ${CMAKE_BINARY_DIR}/testsuite/${name})
        else ()
            message (WARNING "${ColorRed}Could not find Git executable, could not download test data from ${_ogtd_REPO}${ColorReset}")
        endif ()
    else ()
        message (STATUS "${ColorRed}Missing test data ${name}${ColorReset}")
    endif ()
endfunction()

function (oiio_setup_test_data)
    oiio_get_test_data (oiio-images
                        REPO https://github.com/AcademySoftwareFoundation/OpenImageIO-images.git
                        BRANCH dev-${OpenImageIO_VERSION_MAJOR}.${OpenImageIO_VERSION_MINOR})
    oiio_get_test_data (openexr-images
                        REPO https://github.com/AcademySoftwareFoundation/openexr-images.git
                        BRANCH main)
    oiio_get_test_data (fits-images)
    oiio_get_test_data (j2kp4files_v1_5)
endfunction ()
