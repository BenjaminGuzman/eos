# cmake/format.cmake
# Optional clang-format integration

option(EOS_ENABLE_CLANG_FORMAT "Enable clang-format target" OFF)

if(EOS_ENABLE_CLANG_FORMAT)
    find_program(CLANG_FORMAT_EXECUTABLE clang-format)
    if(CLANG_FORMAT_EXECUTABLE)
        file(GLOB_RECURSE ALL_C_FILES "${EoS_SOURCE_DIR}/*.c" "${EoS_SOURCE_DIR}/*.h")
        list(FILTER ALL_C_FILES EXCLUDE REGEX "${EoS_SOURCE_DIR}/(build.*|\\.venv|\\.git)/")
        
        add_custom_target(format
            COMMAND ${CLANG_FORMAT_EXECUTABLE} -i ${ALL_C_FILES}
            WORKING_DIRECTORY ${EoS_SOURCE_DIR}
            COMMENT "Formatting C/C++ code with clang-format"
        )
    else()
        add_custom_target(format
            COMMAND ${CMAKE_COMMAND} -E echo "Warning: clang-format not found. Skipping formatting."
        )
        message(WARNING "clang-format not found — skipping formatting")
    endif()
endif()
