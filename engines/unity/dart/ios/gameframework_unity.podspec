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
                       DESC
  s.homepage         = 'https://github.com/xraph/gameframework'
  s.license          = { :file => '../../../LICENSE' }
  s.author           = { 'Xraph' => 'contact@xraph.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'gameframework'
  s.platform = :ios, '12.0'

  # Unity Framework will be added by Unity export
  s.ios.vendored_frameworks = 'UnityFramework.framework'
  
  # Preserve Unity Data folder structure (critical for IL2CPP to work)
  # This ensures the Data folder is copied with the framework to the app bundle
  s.preserve_paths = 'UnityFramework.framework/Data'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # Unit tests for bridge functionality
  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*'
    test_spec.dependency 'Flutter'
  end
end
