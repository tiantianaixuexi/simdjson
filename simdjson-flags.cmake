if (NOT CMAKE_BUILD_TYPE)
  message(STATUS "No build type selected, default to Release")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
endif()

if(MSVC)
  option(SIMDJSON_BUILD_STATIC "Build a static library" ON) # turning it on disables the production of a dynamic library
  option(SIMDJSON_COMPETITION "Compile competitive benchmarks" OFF)
else()
  option(SIMDJSON_BUILD_STATIC "Build a static library" OFF) # turning it on disables the production of a dynamic library
  option(SIMDJSON_COMPETITION "Compile competitive benchmarks" ON)
  option(SIMDJSON_USE_LIBCPP "Use the libc++ library" OFF)
endif()
option(SIMDJSON_GOOGLE_BENCHMARKS "compile the Google Benchmark benchmarks" OFF)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/tools/cmake")

# We compile tools, tests, etc. with C++ 17. Override yourself if you need on a target.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_MACOSX_RPATH OFF)
set(CMAKE_THREAD_PREFER_PTHREAD ON)
set(THREADS_PREFER_PTHREAD_FLAG ON)

# LTO seems to create all sorts of fun problems. Let us
# disable temporarily.
#include(CheckIPOSupported)
#check_ipo_supported(RESULT ltoresult)
#if(ltoresult)
#  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
#endif()

#
# Flags used by exes and by the simdjson library (project-wide flags)
#
add_library(simdjson-flags INTERFACE)
if(MSVC)
  target_compile_options(simdjson-flags INTERFACE /nologo /D_CRT_SECURE_NO_WARNINGS)
  target_compile_options(simdjson-flags INTERFACE /W3 /sdl /arch:AVX2 /GL /Oi /fp:fast /Gv /Ob3)
else()
  target_compile_options(simdjson-flags INTERFACE -fPIC)
  if (NOT SIMDJSON_GOOGLE_BENCHMARKS) # Google Benchmark can't be compiled without warnings with -Weffc++
    target_compile_options(simdjson-flags INTERFACE -Weffc++)
  endif()
  target_compile_options(simdjson-flags INTERFACE -Werror -Wall -Wextra -Wsign-compare -Wshadow -Wwrite-strings -Wpointer-arith -Winit-self -Wconversion -Wno-sign-conversion)
endif()

# Optional flags
option(SIMDJSON_IMPLEMENTATION_HASWELL "Include the haswell implementation" ON)
if(NOT SIMDJSON_IMPLEMENTATION_HASWELL)
  target_compile_definitions(simdjson-flags INTERFACE SIMDJSON_IMPLEMENTATION_HASWELL=0)
endif()
option(SIMDJSON_IMPLEMENTATION_WESTMERE "Include the westmere implementation" ON)
if(NOT SIMDJSON_IMPLEMENTATION_WESTMERE)
  target_compile_definitions(simdjson-flags INTERFACE SIMDJSON_IMPLEMENTATION_WESTMERE=0)
endif()
option(SIMDJSON_IMPLEMENTATION_ARM64 "Include the arm64 implementation" ON)
if(NOT SIMDJSON_IMPLEMENTATION_ARM64)
  target_compile_definitions(simdjson-flags INTERFACE SIMDJSON_IMPLEMENTATION_ARM64=0)
endif()
option(SIMDJSON_IMPLEMENTATION_FALLBACK "Include the fallback implementation" ON)
if(NOT SIMDJSON_IMPLEMENTATION_FALLBACK)
  target_compile_definitions(simdjson-flags INTERFACE SIMDJSON_IMPLEMENTATION_FALLBACK=0)
endif()

option(SIMDJSON_EXCEPTIONS "Enable simdjson's exception-throwing interface" ON)
if(NOT SIMDJSON_EXCEPTIONS)
  message(STATUS "simdjson exception interface turned off. Code that does not check error codes will not compile.")
  target_compile_definitions(simdjson-flags INTERFACE SIMDJSON_EXCEPTIONS=0)
endif()

option(SIMDJSON_ENABLE_THREADS "Enable threaded operation" ON)
if(SIMDJSON_ENABLE_THREADS)
  find_package(Threads REQUIRED)
  target_link_libraries(simdjson-flags INTERFACE Threads::Threads)
endif()

option(SIMDJSON_SANITIZE "Sanitize addresses" OFF)
if(SIMDJSON_SANITIZE)
  # Not sure which 
  target_compile_options(simdjson-flags INTERFACE -fsanitize=address -fno-omit-frame-pointer -fsanitize=undefined -fno-sanitize-recover=all)
  target_link_libraries(simdjson-flags INTERFACE -fsanitize=address -fno-omit-frame-pointer -fsanitize=undefined -fno-sanitize-recover=all)

  # Ubuntu bug for GCC 5.0+ (safe for all versions)
  if (CMAKE_COMPILER_IS_GNUCC)
    target_link_libraries(simdjson-flags INTERFACE -fuse-ld=gold)
  endif()
endif()

if(SIMDJSON_USE_LIBCPP)
  target_link_libraries(simdjson-flags INTERFACE -stdlib=libc++ -lc++abi)
  # instead of the above line, we could have used
  # set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -stdlib=libc++  -lc++abi")
  # The next line is needed empirically.
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
  # we update CMAKE_SHARED_LINKER_FLAGS, this gets updated later as well
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -lc++abi")
endif(SIMDJSON_USE_LIBCPP)

# prevent shared libraries from depending on Intel provided libraries
if(${CMAKE_C_COMPILER_ID} MATCHES "Intel") # icc / icpc
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -static-intel")
endif()

# Workaround for https://gitlab.kitware.com/cmake/cmake/issues/15415#note_633938:
function(export_private_library NAME)
  install(TARGETS ${NAME}
    EXPORT ${NAME}-config
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  )
  install(EXPORT ${NAME}-config
    FILE ${NAME}-config.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/simdjson-private
  )
endfunction()

export_private_library(simdjson-flags)
