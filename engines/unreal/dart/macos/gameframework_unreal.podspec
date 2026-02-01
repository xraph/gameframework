#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gameframework_unreal.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gameframework_unreal'
  s.version          = '0.5.0'
  s.summary          = 'Unreal Engine integration for Flutter Game Framework on macOS'
  s.description      = <<-DESC
Unreal Engine 5.x integration plugin for the Flutter Game Framework on macOS.
Provides lifecycle management, bidirectional communication, quality settings,
console commands, and level loading for Unreal Engine in Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/xraph/gameframework'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'xraph' => 'rex@xraph.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  # Unreal Framework dependency
  # Note: UnrealFramework.framework must be manually added to the macOS project
  # This podspec does not directly link the framework, as it's typically
  # bundled with the game project
  s.frameworks = 'Cocoa', 'Foundation', 'Metal', 'MetalKit', 'CoreGraphics', 'QuartzCore'

  # Enable Objective-C++ compilation for bridge files
  s.xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_LDFLAGS' => '-ObjC'
  }
end
