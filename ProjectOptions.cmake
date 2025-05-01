include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(tray_tracker_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(tray_tracker_setup_options)
  option(tray_tracker_ENABLE_HARDENING "Enable hardening" ON)
  option(tray_tracker_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    tray_tracker_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    tray_tracker_ENABLE_HARDENING
    OFF)

  tray_tracker_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR tray_tracker_PACKAGING_MAINTAINER_MODE)
    option(tray_tracker_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(tray_tracker_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(tray_tracker_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tray_tracker_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(tray_tracker_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tray_tracker_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(tray_tracker_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tray_tracker_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tray_tracker_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tray_tracker_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(tray_tracker_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(tray_tracker_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tray_tracker_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(tray_tracker_ENABLE_IPO "Enable IPO/LTO" ON)
    option(tray_tracker_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(tray_tracker_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tray_tracker_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(tray_tracker_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tray_tracker_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(tray_tracker_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tray_tracker_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tray_tracker_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tray_tracker_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(tray_tracker_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(tray_tracker_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tray_tracker_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      tray_tracker_ENABLE_IPO
      tray_tracker_WARNINGS_AS_ERRORS
      tray_tracker_ENABLE_USER_LINKER
      tray_tracker_ENABLE_SANITIZER_ADDRESS
      tray_tracker_ENABLE_SANITIZER_LEAK
      tray_tracker_ENABLE_SANITIZER_UNDEFINED
      tray_tracker_ENABLE_SANITIZER_THREAD
      tray_tracker_ENABLE_SANITIZER_MEMORY
      tray_tracker_ENABLE_UNITY_BUILD
      tray_tracker_ENABLE_CLANG_TIDY
      tray_tracker_ENABLE_CPPCHECK
      tray_tracker_ENABLE_COVERAGE
      tray_tracker_ENABLE_PCH
      tray_tracker_ENABLE_CACHE)
  endif()

  tray_tracker_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (tray_tracker_ENABLE_SANITIZER_ADDRESS OR tray_tracker_ENABLE_SANITIZER_THREAD OR tray_tracker_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(tray_tracker_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(tray_tracker_global_options)
  if(tray_tracker_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    tray_tracker_enable_ipo()
  endif()

  tray_tracker_supports_sanitizers()

  if(tray_tracker_ENABLE_HARDENING AND tray_tracker_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tray_tracker_ENABLE_SANITIZER_UNDEFINED
       OR tray_tracker_ENABLE_SANITIZER_ADDRESS
       OR tray_tracker_ENABLE_SANITIZER_THREAD
       OR tray_tracker_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${tray_tracker_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${tray_tracker_ENABLE_SANITIZER_UNDEFINED}")
    tray_tracker_enable_hardening(tray_tracker_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(tray_tracker_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(tray_tracker_warnings INTERFACE)
  add_library(tray_tracker_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  tray_tracker_set_project_warnings(
    tray_tracker_warnings
    ${tray_tracker_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(tray_tracker_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    tray_tracker_configure_linker(tray_tracker_options)
  endif()

  include(cmake/Sanitizers.cmake)
  tray_tracker_enable_sanitizers(
    tray_tracker_options
    ${tray_tracker_ENABLE_SANITIZER_ADDRESS}
    ${tray_tracker_ENABLE_SANITIZER_LEAK}
    ${tray_tracker_ENABLE_SANITIZER_UNDEFINED}
    ${tray_tracker_ENABLE_SANITIZER_THREAD}
    ${tray_tracker_ENABLE_SANITIZER_MEMORY})

  set_target_properties(tray_tracker_options PROPERTIES UNITY_BUILD ${tray_tracker_ENABLE_UNITY_BUILD})

  if(tray_tracker_ENABLE_PCH)
    target_precompile_headers(
      tray_tracker_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(tray_tracker_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    tray_tracker_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(tray_tracker_ENABLE_CLANG_TIDY)
    tray_tracker_enable_clang_tidy(tray_tracker_options ${tray_tracker_WARNINGS_AS_ERRORS})
  endif()

  if(tray_tracker_ENABLE_CPPCHECK)
    tray_tracker_enable_cppcheck(${tray_tracker_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(tray_tracker_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    tray_tracker_enable_coverage(tray_tracker_options)
  endif()

  if(tray_tracker_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(tray_tracker_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(tray_tracker_ENABLE_HARDENING AND NOT tray_tracker_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tray_tracker_ENABLE_SANITIZER_UNDEFINED
       OR tray_tracker_ENABLE_SANITIZER_ADDRESS
       OR tray_tracker_ENABLE_SANITIZER_THREAD
       OR tray_tracker_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    tray_tracker_enable_hardening(tray_tracker_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
