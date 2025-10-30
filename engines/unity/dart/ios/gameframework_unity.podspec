Pod::Spec.new do |s|
  s.name             = 'gameframework_unity'
  s.version          = '0.4.0'
  s.summary          = 'Unity Engine plugin for Flutter Game Framework'
  s.description      = <<-DESC
Unity Engine plugin for Flutter Game Framework. Provides Unity integration with bidirectional communication.
                       DESC
  s.homepage         = 'https://github.com/xraph/flutter-game-framework'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Xraph' => 'hello@xraph.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
