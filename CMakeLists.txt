cmake_minimum_required(VERSION 3.23)

project(par2cmdline VERSION 0.9.0 LANGUAGES CXX)

# Optionally enable CUDA
option(ENABLE_CUDA "Enable CUDA" OFF)

if (ENABLE_CUDA)
    # Check if CUDA is available
    include(CheckLanguage)
    check_language(CUDA)
    if (CMAKE_CUDA_COMPILER)
        enable_language(CUDA)
        find_package(CUDA REQUIRED)
        include_directories("${CUDA_INCLUDE_DIRS}")
    else ()
        message(STATUS "No CUDA compiler found")
    endif ()
endif (ENABLE_CUDA)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CUDA_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_CUDA_STANDARD_REQUIRED True)

if(NOT (CMAKE_BUILD_TYPE OR DEFINED ENV{CMAKE_BUILD_TYPE}))
  set(CMAKE_BUILD_TYPE Release)
endif(NOT (CMAKE_BUILD_TYPE OR DEFINED ENV{CMAKE_BUILD_TYPE}))
message(STATUS ${CMAKE_BUILD_TYPE})

# Check existing headers and generate config.h
# for multi-platform support
include(CheckIncludeFiles)
include(CheckSymbolExists)
include(CheckFunctionExists)

check_include_files(dirent.h HAVE_DIRENT_H)
check_include_files(endian.h HAVE_ENDIAN_H)
check_include_files(getopt.h HAVE_GETOPT_H)
check_include_files(inttypes.h HAVE_INTTYPES_H)
check_include_files(limits.h HAVE_LIMITS_H)
check_include_files(ndir.h HAVE_NDIR_H)
check_include_files(stdbool.h HAVE_STDBOOL_H)
check_include_files(stdint.h HAVE_STDINT_H)
check_include_files(stdio.h HAVE_STDIO_H)
check_include_files(stdlib.h HAVE_STDLIB_H)
check_include_files(strings.h HAVE_STRINGS_H)
check_include_files(string.h HAVE_STRING_H)
check_include_files(sys/dir.h HAVE_SYS_DIR_H)
check_include_files(sys/ndir.h HAVE_SYS_NDIR_H)
check_include_files(sys/stat.h HAVE_SYS_STAT_H)
check_include_files(sys/types.h HAVE_SYS_TYPES_H)
check_include_files(unistd.h HAVE_UNISTD_H)

check_include_files("stdlib.h;stdarg.h;string.h;float.h" StandardHeadersExist)
if(StandardHeadersExist)

    check_function_exists(memchr memchrExists)
    if(memchrExists)

        check_symbol_exists(free stdlib.h freeExists)
        if(freeExists)

            message(STATUS "ANSI C header files - found")
            set(STDC_HEADERS 1 CACHE INTERNAL "System has ANSI C header files")

        endif(freeExists)
	endif(memchrExists)
endif(StandardHeadersExist)

check_function_exists(fseeko HAVE_FSEEKO)
check_function_exists(getopt HAVE_GETOPT)
check_function_exists(getopt_long HAVE_GETOPT_LONG)
check_function_exists(memcpy HAVE_MEMCPY)
check_function_exists(strcasecmp HAVE_STRCASECMP)
check_function_exists(strchr HAVE_STRCHR)
check_function_exists(stricmp HAVE_STRICMP)

# replacement for AC_C_BIGENDIAN
include (TestBigEndian)
test_big_endian(WORDS_BIGENDIAN)

# generate config.h
configure_file(CMakeConfig.h.in ${PROJECT_BINARY_DIR}/config.h)

add_compile_options(
    -Wall -pipe -fstack-protector-strong
    # $<$<CONFIG:RELEASE>:-O3>
    # $<$<CONFIG:DEBUG>:-O0>
    # $<$<CONFIG:DEBUG>:-g>
)

# compile targets
set(CMAKE_STATIC_LIBRARY_PREFIX "")
set(LIBPAR2SRC 
    src/crc.cpp
    src/creatorpacket.cpp
    src/criticalpacket.cpp
    src/datablock.cpp
    src/descriptionpacket.cpp
    src/diskfile.cpp
    src/filechecksummer.cpp
    src/galois.cpp
    src/mainpacket.cpp
    src/md5.cpp
    src/par1fileformat.cpp
    src/par1repairer.cpp
    src/par1repairersourcefile.cpp
    src/par2creator.cpp
    src/par2creatorsourcefile.cpp
    src/par2fileformat.cpp
    src/par2repairer.cpp
    src/par2repairersourcefile.cpp
    src/recoverypacket.cpp
    src/reedsolomon.cpp
    src/verificationhashtable.cpp
    src/verificationpacket.cpp
    src/libpar2.cpp
)

set(PAR2SRC
    src/par2cmdline.cpp
    src/commandline.cpp
)

# add cuda source files if enabled cuda
if (ENABLE_CUDA AND NOT "${CMAKE_CUDA_COMPILER}" STREQUAL "")
    set(LIBPAR2SRC
        ${LIBPAR2SRC}
        src/galois_cu.cu
        src/par2creator.cu
        src/reedsolomon.cu
    )
    # set_source_files_properties(${PAR2SRC} PROPERTIES LANGUAGE CUDA)
    # message(STATUS "${LIBPAR2SRC}")

endif (ENABLE_CUDA AND NOT "${CMAKE_CUDA_COMPILER}" STREQUAL "")

# build libpar2
add_library(libpar2 STATIC ${LIBPAR2SRC})

# build par2
add_executable(par2 ${PAR2SRC})

add_compile_definitions(HAVE_CONFIG_H)

include_directories(${CMAKE_BINARY_DIR})

target_link_libraries(par2 PRIVATE libpar2)

# If OpenMP is installed, link against openmp
find_package(OpenMP)
if (OPENMP_CXX_FOUND)
    target_compile_options(libpar2 PRIVATE ${OpenMP_CXX_FLAGS})
    target_link_libraries(par2 PRIVATE OpenMP::OpenMP_CXX)
    target_link_libraries(libpar2 PRIVATE OpenMP::OpenMP_CXX)
endif()

if (ENABLE_CUDA AND NOT "${CMAKE_CUDA_COMPILER}" STREQUAL "")
    set_target_properties(libpar2 PROPERTIES CUDA_ARCHITECTURES "all-major")
endif (ENABLE_CUDA AND NOT "${CMAKE_CUDA_COMPILER}" STREQUAL "")

# ===========================
# Testing
enable_testing()

# Build unit tests
add_executable(letype_test src/letype_test.cpp)
add_executable(crc_test src/crc_test.cpp src/crc.cpp)
add_executable(md5_test src/md5_test.cpp src/md5.cpp)
add_executable(diskfile_test src/diskfile_test.cpp src/diskfile.cpp)
add_executable(libpar2_test src/libpar2_test.cpp)
target_link_libraries(libpar2_test PRIVATE libpar2)

add_executable(commandline_test src/commandline_test.cpp src/commandline.cpp)
target_link_libraries(commandline_test PRIVATE libpar2)

add_executable(descriptionpacket_test src/descriptionpacket_test.cpp src/descriptionpacket.cpp)
target_link_libraries(descriptionpacket_test PRIVATE libpar2)

add_executable(criticalpacket_test src/criticalpacket_test.cpp src/criticalpacket.cpp)
target_link_libraries(criticalpacket_test PRIVATE libpar2)

add_executable(reedsolomon_test src/reedsolomon_test.cpp src/reedsolomon.cpp)
add_executable(galois_test src/galois_test.cpp src/galois.cpp)

set(TEST_OUTPUT_DIR ${CMAKE_BINARY_DIR}/tests)
set_target_properties(
    letype_test
    crc_test
    md5_test
    diskfile_test
    libpar2_test
    commandline_test
    descriptionpacket_test
    criticalpacket_test
    reedsolomon_test
    galois_test
    PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${TEST_OUTPUT_DIR}
)

# Run tests
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/tests DESTINATION ${CMAKE_BINARY_DIR})
find_program (BASH_PROGRAM bash)
if (BASH_PROGRAM)

    add_test(NAME test1 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test1)
    add_test(NAME test2 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test2)
    add_test(NAME test3 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test3)
    add_test(NAME test4 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test4)
    add_test(NAME test5 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test5)
    add_test(NAME test6 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test6)
    add_test(NAME test7 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test7)
    add_test(NAME test8 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test8)
    add_test(NAME test9 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test9)
    add_test(NAME test10 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test10)
    add_test(NAME test11 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test11)
    add_test(NAME test12 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test12)
    add_test(NAME test13 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test13)
    add_test(NAME test14 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test14)
    add_test(NAME test15 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test15)
    add_test(NAME test16 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test16)
    add_test(NAME test17 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test17)
    add_test(NAME test18 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test18)
    add_test(NAME test19 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test19)
    add_test(NAME test20 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test20)
    add_test(NAME test21 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test21)
    add_test(NAME test22 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test22)
    add_test(NAME test23 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test23)
    add_test(NAME test24 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test24)
    add_test(NAME test25 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test25)
    add_test(NAME test26 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test26)
    add_test(NAME test27 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test27)
    add_test(NAME test28 COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/test28)
    add_test(NAME unit_tests COMMAND ${BASH_PROGRAM} ${CMAKE_BINARY_DIR}/tests/unit_tests)

endif (BASH_PROGRAM)

# ==========================
# install
message(STATUS "Install prefix: ${CMAKE_INSTALL_PREFIX}")
install(TARGETS par2
        DESTINATION bin)

add_custom_command(
    TARGET par2
    POST_BUILD
    COMMAND ln;-sf;par2${CMAKE_EXECUTABLE_SUFFIX};par2create${CMAKE_EXECUTABLE_SUFFIX}
    COMMAND ln;-sf;par2${CMAKE_EXECUTABLE_SUFFIX};par2verify${CMAKE_EXECUTABLE_SUFFIX}
    COMMAND ln;-sf;par2${CMAKE_EXECUTABLE_SUFFIX};par2repair${CMAKE_EXECUTABLE_SUFFIX}
)

install(
  FILES
    ${CMAKE_CURRENT_BINARY_DIR}/par2create${CMAKE_EXECUTABLE_SUFFIX}
    ${CMAKE_CURRENT_BINARY_DIR}/par2verify${CMAKE_EXECUTABLE_SUFFIX}
    ${CMAKE_CURRENT_BINARY_DIR}/par2repair${CMAKE_EXECUTABLE_SUFFIX}
  DESTINATION bin
)