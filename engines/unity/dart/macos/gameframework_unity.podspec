#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gameframework_unity.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gameframework_unity'
  s.version          = '0.4.0'
  s.summary          = 'Unity Engine integration for Flutter Game Framework on macOS'
  s.description      = <<-DESC
Unity Engine plugin for Flutter Game Framework. Provides Unity integration with
bidirectional communication, scene management, and lifecycle handling on macOS.
                       DESC
  s.homepage         = 'https://github.com/xraph/gameframework'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Xraph' => 'contact@xraph.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  # Unity framework dependencies
  s.frameworks = 'Cocoa', 'UnityFramework'
  s.vendored_frameworks = 'UnityFramework.framework'
end
