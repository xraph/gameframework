#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gameframework_unreal.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gameframework_unreal'
  s.version          = '0.5.0'
  s.summary          = 'Unreal Engine integration for GameFramework'
  s.description      = <<-DESC
Unreal Engine 5.x integration plugin for the GameFramework.
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

  # The only header a host app is meant to import. It declares Unreal's
  # IOSAppDelegate so an app delegate can subclass it, which the engine requires.
  # Reach it from Runner-Bridging-Header.h as:
  #   #import <gameframework_unreal/UnrealAppDelegate.h>
  s.public_header_files = 'Classes/UnrealAppDelegate.h'

  # Cooked content, shipped into the app bundle root.
  #
  # Unreal looks for cookeddata and uecommandline.txt next to the executable, so
  # they cannot live inside the framework. A flat iOS framework must not carry a
  # Resources directory either: installd refuses the whole app when it finds
  # one. "game sync unreal -p ios" places these here.
  unreal_content_path = File.join(__dir__, 'UnrealContent')
  if File.directory?(unreal_content_path)
    # Top-level entries, not a glob. A glob matches individual files and
    # CocoaPods copies each one to the bundle root, which would flatten
    # cookeddata into loose files. Naming the directory copies it whole.
    s.resources = Dir.glob(File.join(unreal_content_path, '*')).map do |entry|
      File.join('UnrealContent', File.basename(entry))
    end
  end
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

    # Vendor it when it is sitting right here, which is the case after
    # "game sync unreal -p ios" with no separate game plugin in between. Without
    # this nothing embeds the framework, the app launches, and IOSAppDelegate is
    # missing at runtime. A consumer plugin that vendors its own build syncs
    # there instead, so this stays false for them and there is no duplicate.
    s.ios.vendored_frameworks = 'UnrealFramework.framework'
  end

  # Configure framework search paths to find UnrealFramework from sibling pods
  # This allows gameframework_unreal to import UnrealFramework that is vendored
  # by another pod (the consumer plugin)
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Find UnrealFramework wherever the consumer plugin vendors it. NOTE: Xcode
    # does NOT expand a single `*` in search paths, so "plugins/*/ios" never
    # resolves for hosted (pub.dev) installs — it only worked when `game sync`
    # planted a symlink in this pod's own dir. Use Xcode's recursive `**`
    # syntax, which searches all subdirectories under the plugins symlink dir.
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}" "${PODS_CONFIGURATION_BUILD_DIR}" "${PODS_ROOT}/../.symlinks/plugins/**"',
    # Allow weak linking to UnrealFramework
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
  s.swift_version = '5.0'

  # System frameworks required by Unreal Engine
  s.frameworks = 'UIKit', 'Foundation', 'Metal', 'MetalKit', 'CoreGraphics', 'AVFoundation', 'AudioToolbox', 'QuartzCore'
end
