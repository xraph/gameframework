#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'gameframework_unity'
  s.version          = '2022.3.0'
  s.summary          = 'Unity Engine plugin for Flutter Game Framework'
  s.description      = <<-DESC
Unity Engine integration plugin for the Flutter Game Framework.
Provides Unity 2022.3.x support for embedding Unity games in Flutter applications.

IMPORTANT: This plugin requires UnityFramework.framework to be vendored by the
consuming plugin (your game plugin). The framework is NOT included in this package
because each game has its own Unity build. Use 'game sync unity --platform ios'
to sync your Unity export to your plugin's ios/ directory.
                       DESC
  s.homepage         = 'https://github.com/xraph/gameframework'
  s.license          = { :file => '../../../LICENSE' }
  s.author           = { 'Xraph' => 'contact@xraph.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'gameframework'
  s.platform = :ios, '12.0'

  # UnityFramework is provided by the consuming plugin (e.g., your game plugin)
  # NOT vendored here because each game has its own Unity build.
  # The consumer plugin MUST vendor UnityFramework.framework in their podspec.
  
  # Preserve the framework if it exists locally (symlink or actual)
  # This is needed for the Swift compiler to find the module
  unity_framework_path = File.join(__dir__, 'UnityFramework.framework')
  if File.exist?(unity_framework_path) || File.symlink?(unity_framework_path)
    s.preserve_paths = 'UnityFramework.framework', 'UnityFramework.framework/Data'
    # Don't vendor - let the consumer plugin vendor it to avoid conflicts
    # s.ios.vendored_frameworks = 'UnityFramework.framework'
  end

  # Configure framework search paths to find UnityFramework from sibling pods
  # This allows gameframework_unity to import UnityFramework that is vendored
  # by another pod (the consumer plugin like 'green')
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Search for frameworks in the local directory (symlink), Pods build directory, and sibling plugins
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}" "${PODS_CONFIGURATION_BUILD_DIR}" "${PODS_ROOT}/../.symlinks/plugins/*/ios"',
    # Allow weak linking to UnityFramework
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
  s.swift_version = '5.0'
  
  # Unit tests for bridge functionality
  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*'
    test_spec.dependency 'Flutter'
  end
end
