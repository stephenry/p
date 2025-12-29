##========================================================================== //
## Copyright (c) 2025, Stephen Henry
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
## * Redistributions of source code must retain the above copyright notice, this
##   list of conditions and the following disclaimer.
##
## * Redistributions in binary form must reproduce the above copyright notice,
##   this list of conditions and the following disclaimer in the documentation
##   and/or other materials provided with the distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
## LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##========================================================================== //

set(P_PROJECT_LIBS "")

macro (generate_project)

    set(options )
    set(one_value_args NAME)
    set(multi_value_args YAML_IN CC_SRCS)

    # Parse arguments
    cmake_parse_arguments(arg 
        "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    # Declare library target
    add_library(${arg_NAME} STATIC ${arg_CC_SRCS})
    set_target_properties(${arg_NAME} PROPERTIES
      CXX_STANDARD 20
      CXX_STANDARD_REQUIRED YES
      CXX_EXTENSIONS NO
    )
    # Append to global project list
    message(STATUS "Adding project library: ${arg_NAME}")
    set(P_PROJECT_LIBS "${arg_NAME};${P_PROJECT_LIBS}" PARENT_SCOPE)
    message(STATUS "Current project libs: ${P_PROJECT_LIBS}")

    set (v_libraries "")
    foreach (YAML_IN ${arg_YAML_IN})

        # 'instance' name is a single invocation of verilator
        get_filename_component(v_instance ${YAML_IN} NAME_WE)

        set(project_fn ${CMAKE_CURRENT_BINARY_DIR}/${v_instance}.yaml)

        configure_file(${YAML_IN} ${project_fn})

        set(generated_root ${CMAKE_CURRENT_BINARY_DIR}/${v_instance})
        target_include_directories(${arg_NAME} PRIVATE ${generated_root})

        # RTL rendering will generate these directories, but CMAKE requires that they be
        # present at configuration-time.
        set(rtl_dir ${generated_root}/rtl)
        file(MAKE_DIRECTORY ${rtl_dir})

        set(vout_dir ${generated_root}/v)
        file(MAKE_DIRECTORY ${vout_dir})

        # RTL rendering target
        add_custom_target(render_${v_instance}
            COMMAND ${P_PYTHON3}
                ${CMAKE_BINARY_DIR}/py/compile.py
                    --project ${project_fn}
                    --rtl-dir ${rtl_dir}
                    --vout-dir ${vout_dir}
                    --compile_rtl
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            DEPENDS ${CMAKE_SOURCE_DIR}/py/rtl.py
            COMMENT "Rendering RTL for target: ${v_instance}")

        # Construct imported library corresponding to the verilated output.
        add_library(v${v_instance} IMPORTED STATIC GLOBAL)
        set_target_properties(v${v_instance} PROPERTIES
            IMPORTED_LOCATION
            ${vout_dir}/V${v_instance}__ALL.a
            INTERFACE_INCLUDE_DIRECTORIES
            ${vout_dir}
            INTERFACE_LINK_LIBRARIES
            vlib)

        # Link verilated library to testbench
        add_dependencies(v${v_instance} render_${v_instance})
        list(APPEND v_libraries v${v_instance})

    endforeach ()

    target_link_libraries(${arg_NAME} tb vlib ${v_libraries})
    message(STATUS "Project ${arg_NAME} linked to verilated libraries: ${v_libraries}")

endmacro ()


add_subdirectory(common)
add_subdirectory(conv)
add_subdirectory(seqgen)

set(PROJECT_SRCS
    ${CMAKE_CURRENT_SOURCE_DIR}/projects.cc
)

add_library(projects STATIC ${PROJECT_SRCS})
message(STATUS "Project libraries: ${P_PROJECT_LIBS}")
target_link_libraries(projects ${P_PROJECT_LIBS})
target_include_directories(projects
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)
set_target_properties(projects PROPERTIES
  CXX_STANDARD 20
  CXX_STANDARD_REQUIRED YES
  CXX_EXTENSIONS NO
)
