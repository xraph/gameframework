#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gameframework_unreal.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gameframework_unreal'
  s.version          = '0.5.0'
  s.summary          = 'Unreal Engine integration for Flutter Game Framework'
  s.description      = <<-DESC
Unreal Engine 5.x integration plugin for the Flutter Game Framework.
Provides lifecycle management, bidirectional communication, quality settings,
console commands, and level loading for Unreal Engine in Flutter apps.

IMPORTANT: This plugin requires UnrealFramework.framework to be vendored by the
consuming plugin (your game plugin). The framework is NOT included in this package
because each game has its own Unreal build. Use 'game sync unreal --platform ios'
to sync your Unreal export to your plugin's ios/ directory.
                       DESC
  s.homepage         = 'https://github.com/xraph/gameframework'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'xraph' => 'rex@xraph.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'gameframework'
  s.platform = :ios, '15.0'

  # UnrealFramework is provided by the consuming plugin (e.g., your game plugin)
  # NOT vendored here because each game has its own Unreal build.
  # The consumer plugin MUST vendor UnrealFramework.framework in their podspec.
  
  # Preserve the framework if it exists locally (symlink or actual)
  # This is needed for the Swift compiler to find the module
  unreal_framework_path = File.join(__dir__, 'UnrealFramework.framework')
  if File.exist?(unreal_framework_path) || File.symlink?(unreal_framework_path)
    s.preserve_paths = 'UnrealFramework.framework', 'UnrealFramework.framework/Resources'
    # Don't vendor - let the consumer plugin vendor it to avoid conflicts
    # s.ios.vendored_frameworks = 'UnrealFramework.framework'
  end

  # Configure framework search paths to find UnrealFramework from sibling pods
  # This allows gameframework_unreal to import UnrealFramework that is vendored
  # by another pod (the consumer plugin)
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Search for frameworks in the local directory (symlink), Pods build directory, and sibling plugins
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}" "${PODS_CONFIGURATION_BUILD_DIR}" "${PODS_ROOT}/../.symlinks/plugins/*/ios"',
    # Allow weak linking to UnrealFramework
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
  s.swift_version = '5.0'

  # System frameworks required by Unreal Engine
  s.frameworks = 'UIKit', 'Foundation', 'Metal', 'MetalKit', 'CoreGraphics', 'AVFoundation', 'AudioToolbox'
end
