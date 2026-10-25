cmake_minimum_required(VERSION 3.15)
# Static CRT: the launcher must run without DLLs alongside the root executable.
add_executable(index_launcher WIN32
  main.cpp
  ../runner/Runner.rc
  ../runner/runner.exe.manifest
)
target_compile_features(index_launcher PRIVATE cxx_std_17)
target_compile_options(index_launcher PRIVATE /W4 /WX /utf-8)
target_include_directories(index_launcher PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../runner")
target_link_libraries(index_launcher PRIVATE user32)
set_target_properties(index_launcher PROPERTIES
  OUTPUT_NAME "IndeX"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/launcher"
  MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
)
target_compile_definitions(index_launcher PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
foreach(part MAJOR MINOR PATCH BUILD)
  target_compile_definitions(index_launcher PRIVATE "FLUTTER_VERSION_${part}=${FLUTTER_VERSION_${part}}")
endforeach()
