# The Flutter tooling requires that developers have CMake 3.14 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "gameframework_unreal")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "unreal_engine_plugin")

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "unreal_engine_plugin.cpp"
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(gameframework_unreal_bundled_libraries
  ""
  PARENT_SCOPE
)

# === Unreal Engine Integration ===
# Uncomment and configure the following when integrating with Unreal Engine:
#
# Find and link Unreal Engine libraries
# set(UNREAL_ENGINE_DIR "C:/Program Files/Epic Games/UE_5.3")
# target_include_directories(${PLUGIN_NAME} PRIVATE
#   "${UNREAL_ENGINE_DIR}/Engine/Source/Runtime/Core/Public"
#   "${UNREAL_ENGINE_DIR}/Engine/Source/Runtime/Engine/Public"
# )
#
# Link Unreal Engine libraries
# target_link_libraries(${PLUGIN_NAME} PRIVATE
#   "${UNREAL_ENGINE_DIR}/Engine/Binaries/Win64/UnrealEngine.lib"
# )
