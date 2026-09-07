#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gameframework_unreal.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gameframework_unreal'
  s.version          = '0.5.0'
  s.summary          = 'Unreal Engine integration for GameFramework on macOS'
  s.description      = <<-DESC
Unreal Engine 5.x integration plugin for the GameFramework on macOS.
Provides lifecycle management, bidirectional communication, quality settings,
console commands, and level loading for Unreal Engine in Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/xraph/gameframework'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'xraph' => 'rex@xraph.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.dependency 'gameframework'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  # Vendor the framework when it is sitting right here, which is the case after
  # "game sync unreal -p macos" with no separate game plugin in between.
  # Without this nothing embeds it and the app launches with the engine missing.
  unreal_framework_path = File.join(__dir__, 'UnrealFramework.framework')
  if File.exist?(unreal_framework_path) || File.symlink?(unreal_framework_path)
    s.osx.vendored_frameworks = 'UnrealFramework.framework'
  end

  # Cooked content and the command line, shipped into the app bundle.
  #
  # Unreal reads these from beside the executable, so they cannot live inside
  # the framework. Named per entry rather than globbed, because a glob matches
  # files and CocoaPods copies each one to the bundle root, flattening any
  # directory structure.
  unreal_content_path = File.join(__dir__, 'UnrealContent')
  if File.directory?(unreal_content_path)
    s.resources = Dir.glob(File.join(unreal_content_path, '*')).map do |entry|
      File.join('UnrealContent', File.basename(entry))
    end
  end
  s.frameworks = 'Cocoa', 'Foundation', 'Metal', 'MetalKit', 'CoreGraphics', 'QuartzCore', 'CoreVideo'

  # Enable Objective-C++ compilation for bridge files
  s.xcconfig = {
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'OTHER_LDFLAGS' => '-ObjC'
  }
end
