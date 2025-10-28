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
                       DESC
  s.homepage         = 'https://github.com/xraph/flutter-game-framework'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'xraph' => 'rex@xraph.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Unreal Framework dependency
  # Note: UnrealFramework.framework must be manually added to the iOS project
  # This podspec does not directly link the framework, as it's typically
  # bundled with the game project
  s.frameworks = 'UIKit', 'Foundation', 'Metal', 'MetalKit', 'CoreGraphics'

  # Enable Objective-C++ compilation for bridge files
  s.xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_LDFLAGS' => '-ObjC'
  }
end
