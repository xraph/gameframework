import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';
import '../../models/game_config.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';

/// Unity engine exporter
class UnityExporter {
  final EngineConfig config;
  final Logger logger;
  final Shell shell;

  UnityExporter({
    required this.config,
    required this.logger,
  }) : shell = Shell(verbose: false);

  /// Export Unity project for specified platform
  Future<bool> export(String platform) async {
    logger.info('Exporting Unity project for $platform...');

    final platformConfig = config.platforms[platform];
    if (platformConfig == null || !platformConfig.enabled) {
      logger.warning('Platform $platform is not enabled');
      return false;
    }

    try {
      // Check Unity installation
      final unityPath = await _findUnityEditor();
      if (unityPath == null) {
        logger.error('Unity Editor not found');
        return false;
      }

      logger.detail('Using Unity at: $unityPath');

      // Prepare export path
      final exportPath = config.exportPath ?? path.join(config.projectPath, 'Exports');
      final platformExportPath = path.join(exportPath, _getPlatformExportDir(platform));

      await Directory(platformExportPath).create(recursive: true);

      // Build Unity project
      final success = await _buildUnityProject(
        unityPath: unityPath,
        projectPath: config.projectPath,
        platform: platform,
        exportPath: platformExportPath,
        development: config.exportSettings?.development ?? false,
      );

      if (!success) {
        logger.error('Unity build failed');
        return false;
      }

      logger.success('Unity export completed: $platformExportPath');
      return true;
    } catch (e) {
      logger.error('Export failed: $e');
      return false;
    }
  }

  /// Copy exported files to Flutter project
  Future<bool> sync(String platform, String flutterProjectPath) async {
    logger.info('Syncing Unity files for $platform...');

    final platformConfig = config.platforms[platform];
    if (platformConfig == null || !platformConfig.enabled) {
      logger.warning('Platform $platform is not enabled');
      return false;
    }

    try {
      final exportPath = config.exportPath ?? path.join(config.projectPath, 'Exports');
      final platformExportPath = path.join(exportPath, _getPlatformExportDir(platform));

      if (!await Directory(platformExportPath).exists()) {
        logger.error('Export directory not found: $platformExportPath');
        logger.hint('Run "game export unity --platform $platform" first');
        return false;
      }

      final targetPath = platformConfig.targetPath ?? _getDefaultTargetPath(platform);
      final fullTargetPath = path.join(flutterProjectPath, targetPath);

      logger.detail('Source: $platformExportPath');
      logger.detail('Target: $fullTargetPath');

      // Platform-specific sync
      switch (platform) {
        case 'android':
          await _syncAndroid(platformExportPath, fullTargetPath);
          break;
        case 'ios':
          await _syncIOS(platformExportPath, fullTargetPath);
          break;
        case 'macos':
          await _syncMacOS(platformExportPath, fullTargetPath);
          break;
        case 'windows':
          await _syncWindows(platformExportPath, fullTargetPath);
          break;
        case 'linux':
          await _syncLinux(platformExportPath, fullTargetPath);
          break;
        default:
          logger.error('Unsupported platform: $platform');
          return false;
      }

      logger.success('Sync completed successfully');
      return true;
    } catch (e) {
      logger.error('Sync failed: $e');
      return false;
    }
  }

  /// Find Unity Editor executable
  Future<String?> _findUnityEditor() async {
    if (Platform.isMacOS) {
      // Check common locations on macOS
      final locations = [
        '/Applications/Unity/Hub/Editor',
        '/Applications/Unity/Unity.app/Contents/MacOS/Unity',
      ];

      for (final loc in locations) {
        if (await File(loc).exists()) {
          return loc;
        }
        // Check Hub editor versions
        final hubDir = Directory(loc);
        if (await hubDir.exists()) {
          final versions = hubDir.listSync()
              .whereType<Directory>()
              .map((d) => path.join(d.path, 'Unity.app', 'Contents', 'MacOS', 'Unity'))
              .where((p) => File(p).existsSync());
          if (versions.isNotEmpty) {
            return versions.first;
          }
        }
      }
    } else if (Platform.isWindows) {
      // Check common locations on Windows
      final locations = [
        r'C:\Program Files\Unity\Hub\Editor',
        r'C:\Program Files\Unity\Editor\Unity.exe',
      ];

      for (final loc in locations) {
        if (await File(loc).exists()) {
          return loc;
        }
        final hubDir = Directory(loc);
        if (await hubDir.exists()) {
          final versions = hubDir.listSync()
              .whereType<Directory>()
              .map((d) => path.join(d.path, 'Editor', 'Unity.exe'))
              .where((p) => File(p).existsSync());
          if (versions.isNotEmpty) {
            return versions.first;
          }
        }
      }
    } else if (Platform.isLinux) {
      // Try to find Unity in PATH
      try {
        final result = await shell.run('which unity-editor');
        if (result.first.exitCode == 0) {
          return result.first.stdout.toString().trim();
        }
      } catch (_) {}
    }

    return null;
  }

  /// Build Unity project
  Future<bool> _buildUnityProject({
    required String unityPath,
    required String projectPath,
    required String platform,
    required String exportPath,
    required bool development,
  }) async {
    logger.info('Building Unity project...');

    // Remove lock file if it exists (prevents "another instance running" error)
    final lockFile = File(path.join(projectPath, 'Temp', 'UnityLockfile'));
    if (await lockFile.exists()) {
      logger.detail('Removing Unity lock file...');
      await lockFile.delete();
    }

    final buildMethod = _getBuildMethod(platform);
    final buildTarget = _getBuildTarget(platform);

    final args = [
      '-quit',
      '-batchmode',
      '-projectPath', projectPath,
      '-executeMethod', buildMethod,
      '-buildTarget', buildTarget,
      '-buildPath', exportPath,
      '-logFile', '-', // Log to stdout
    ];

    if (development) {
      args.add('-development');
    }

    // Pass scenes from config if specified
    if (config.exportSettings?.scenes != null && config.exportSettings!.scenes!.isNotEmpty) {
      final scenesArg = config.exportSettings!.scenes!.join(',');
      args.addAll(['-buildScenes', scenesArg]);
      logger.detail('Building with scenes: $scenesArg');
    }

    // Pass build configuration if specified
    if (config.exportSettings?.buildConfiguration != null) {
      args.addAll(['-buildConfiguration', config.exportSettings!.buildConfiguration!]);
      logger.detail('Build configuration: ${config.exportSettings!.buildConfiguration}');
    }

    logger.detail('Unity command: $unityPath ${args.join(' ')}');

    try {
      final result = await shell.run('$unityPath ${args.join(' ')}');
      final exitCode = result.first.exitCode;

      if (exitCode == 0) {
        logger.success('Unity build completed successfully');
        return true;
      } else {
        logger.error('Unity build failed with exit code: $exitCode');

        // Provide helpful error messages based on exit code
        if (exitCode == -6) {
          logger.error('Unity crashed during build. Check Unity log for details.');
          logger.hint('Unity log location: ~/Library/Logs/Unity/Editor.log (macOS)');
        }

        return false;
      }
    } catch (e) {
      logger.error('Build error: $e');
      return false;
    }
  }

  /// Sync Android files
  Future<void> _syncAndroid(String source, String target) async {
    logger.detail('Syncing Android files...');

    // Copy unityLibrary folder
    final unityLibrary = path.join(source, 'unityLibrary');
    if (await Directory(unityLibrary).exists()) {
      await FileUtils.copyDirectory(unityLibrary, target);
      logger.success('Copied unityLibrary to $target');
    } else {
      throw Exception('unityLibrary not found in export');
    }

    // Fix unityLibrary build.gradle for modern AGP
    await _fixUnityLibraryBuildGradle(target);

    // Create missing strings.xml file (required for Unity initialization)
    await _createUnityStringsXml(target);

    // Convert Unity export from application to library
    await _convertUnityToLibrary(target);

    // Auto-configure Gradle settings
    await _configureAndroidGradle(target);
  }

  /// Convert Unity export from application to library
  /// This removes activity declarations that would make Unity launch as standalone
  Future<void> _convertUnityToLibrary(String unityLibraryPath) async {
    logger.detail('Converting Unity export to library format...');

    // Modify AndroidManifest.xml to remove activities
    await _stripActivitiesFromManifest(unityLibraryPath);

    // Ensure build.gradle is set as library (should already be done, but verify)
    await _ensureLibraryPlugin(unityLibraryPath);
  }

  /// Remove activity declarations from AndroidManifest.xml
  Future<void> _stripActivitiesFromManifest(String unityLibraryPath) async {
    // Try nested structure first
    var manifestPath = path.join(
      unityLibraryPath,
      'unityLibrary',
      'src',
      'main',
      'AndroidManifest.xml',
    );

    var manifestFile = File(manifestPath);

    if (!await manifestFile.exists()) {
      // Try root level structure
      manifestPath = path.join(
        unityLibraryPath,
        'src',
        'main',
        'AndroidManifest.xml',
      );
      manifestFile = File(manifestPath);
    }

    if (!await manifestFile.exists()) {
      logger.warning('AndroidManifest.xml not found at $manifestPath');
      return;
    }

    String content = await manifestFile.readAsString();

    // Check if there are any activities
    if (!content.contains('<activity')) {
      logger.detail('No activities found in AndroidManifest.xml');
      return;
    }

    logger.detail('Removing activity declarations from AndroidManifest.xml...');

    // Remove the application tag attributes (but keep the tag itself)
    content = content.replaceFirstMapped(
      RegExp(r'<application[^>]*>'),
      (match) => '<application>',
    );

    // Remove all activity tags and their content
    content = content.replaceAll(
      RegExp(r'<activity[^>]*>[\s\S]*?</activity>', multiLine: true),
      '',
    );

    await manifestFile.writeAsString(content);
    logger.success('Stripped activities from AndroidManifest.xml');
  }

  /// Ensure build.gradle uses library plugin
  Future<void> _ensureLibraryPlugin(String unityLibraryPath) async {
    // Try nested structure first
    var buildGradlePath = path.join(unityLibraryPath, 'unityLibrary', 'build.gradle');
    var buildFile = File(buildGradlePath);

    if (!await buildFile.exists()) {
      // Try root level
      buildGradlePath = path.join(unityLibraryPath, 'build.gradle');
      buildFile = File(buildGradlePath);
    }

    if (!await buildFile.exists()) {
      return;
    }

    String content = await buildFile.readAsString();

    // Replace application plugin with library plugin
    if (content.contains("'com.android.application'")) {
      logger.detail('Converting from application to library plugin...');
      content = content.replaceAll("'com.android.application'", "'com.android.library'");
      await buildFile.writeAsString(content);
      logger.success('Converted to library plugin');
    } else if (content.contains('"com.android.application"')) {
      content = content.replaceAll('"com.android.application"', '"com.android.library"');
      await buildFile.writeAsString(content);
      logger.success('Converted to library plugin');
    }

    // Remove applicationId if present (libraries don't have applicationId)
    content = await buildFile.readAsString();
    if (content.contains('applicationId')) {
      logger.detail('Removing applicationId from library...');
      content = content.replaceAll(RegExp(r'\s*applicationId\s+["\'][^"\']+["\']\s*\n?'), '');
      await buildFile.writeAsString(content);
      logger.success('Removed applicationId');
    }
  }

  /// Create Unity strings.xml file if missing
  /// This file is required for Unity initialization to prevent Resources$NotFoundException
  Future<void> _createUnityStringsXml(String unityLibraryPath) async {
    logger.detail('Checking Unity strings.xml...');

    // Try nested structure first
    var stringsXmlPath = path.join(
      unityLibraryPath,
      'unityLibrary',
      'src',
      'main',
      'res',
      'values',
      'strings.xml',
    );

    var stringsXmlFile = File(stringsXmlPath);

    // If nested doesn't exist, try root level
    if (!await stringsXmlFile.parent.exists()) {
      stringsXmlPath = path.join(
        unityLibraryPath,
        'src',
        'main',
        'res',
        'values',
        'strings.xml',
      );
      stringsXmlFile = File(stringsXmlPath);
    }

    if (await stringsXmlFile.exists()) {
      logger.detail('strings.xml already exists');
      return;
    }

    // Create the strings.xml file
    logger.detail('Creating strings.xml...');

    // Ensure the directory exists
    await stringsXmlFile.parent.create(recursive: true);

    // Write the strings.xml content
    const stringsXmlContent = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Unity</string>
    <string name="game_view_content_description">Game View</string>
</resources>
''';

    await stringsXmlFile.writeAsString(stringsXmlContent);
    logger.success('Created Unity strings.xml');
  }

  /// Fix unityLibrary build.gradle for modern AGP compatibility
  Future<void> _fixUnityLibraryBuildGradle(String unityLibraryPath) async {
    logger.detail('Fixing unityLibrary build.gradle for AGP 8+...');

    // Try both possible locations (nested or root level)
    var unityBuildGradlePath = path.join(unityLibraryPath, 'unityLibrary', 'build.gradle');
    var buildGradleFile = File(unityBuildGradlePath);

    if (!await buildGradleFile.exists()) {
      // Try root level
      unityBuildGradlePath = path.join(unityLibraryPath, 'build.gradle');
      buildGradleFile = File(unityBuildGradlePath);
    }

    if (!await buildGradleFile.exists()) {
      logger.warning('unityLibrary/build.gradle not found');
      return;
    }

    String content = await buildGradleFile.readAsString();

    // Check if namespace already exists
    if (content.contains('namespace ')) {
      logger.detail('Namespace already configured in unityLibrary');
      return;
    }

    // Add namespace right after 'android {' line
    final androidBlockMatch = RegExp(r'android\s*\{').firstMatch(content);
    if (androidBlockMatch != null) {
      final insertPos = androidBlockMatch.end;
      final before = content.substring(0, insertPos);
      final after = content.substring(insertPos);

      content = '$before\n    namespace \'com.unity3d.player\'$after';
      await buildGradleFile.writeAsString(content);
      logger.success('Added namespace to unityLibrary build.gradle');
    }

    // Update compileSdkVersion and buildToolsVersion to match modern versions
    content = await buildGradleFile.readAsString();
    content = content.replaceFirst(RegExp(r'compileSdkVersion\s+\d+'), 'compileSdkVersion 34');
    content = content.replaceFirst(RegExp(r"buildToolsVersion\s+'[^']+\'"), "buildToolsVersion '34.0.0'");

    // Comment out hardcoded NDK path (use system NDK instead)
    content = content.replaceFirst(
      RegExp(r'(\s+)ndkPath\s+"[^"]+"'),
      r'$1// Use system NDK instead of Unity bundled NDK\n$1// ndkPath "/path/to/unity/ndk"'
    );

    await buildGradleFile.writeAsString(content);
    logger.success('Updated unityLibrary SDK versions and NDK configuration');
  }

  /// Configure Android Gradle integration
  Future<void> _configureAndroidGradle(String unityLibraryPath) async {
    logger.info('Configuring Android Gradle integration...');

    // Get the android directory (parent of target path)
    final androidDir = Directory(unityLibraryPath).parent.path;
    final settingsGradlePath = path.join(androidDir, 'settings.gradle');

    if (!await File(settingsGradlePath).exists()) {
      logger.warning('settings.gradle not found at $settingsGradlePath');
      return;
    }

    // Read settings.gradle
    final settingsFile = File(settingsGradlePath);
    String content = await settingsFile.readAsString();

    // Check if unityLibrary is already included
    final unityLibraryIncluded = content.contains('include ":unityLibrary"') ||
        content.contains("include ':unityLibrary'");

    if (!unityLibraryIncluded) {
      logger.detail('Adding unityLibrary to settings.gradle...');

      // Detect Unity library structure (nested or root level)
      final nestedExists = await Directory(path.join(unityLibraryPath, 'unityLibrary')).exists();
      final projectDirValue = nestedExists ? 'unityLibrary/unityLibrary' : 'unityLibrary';

      // Find a good place to add the include statement
      // Add it after the last include statement or at the end
      final lines = content.split('\n');
      final insertIndex = _findInsertIndexForInclude(lines);

      lines.insert(insertIndex, 'include ":unityLibrary"');
      lines.insert(insertIndex + 1, 'project(\':unityLibrary\').projectDir = file(\'$projectDirValue\')');

      content = lines.join('\n');
      await settingsFile.writeAsString(content);
      logger.success('Added unityLibrary to settings.gradle (structure: $projectDirValue)');
    } else {
      logger.detail('unityLibrary already included in settings.gradle');

      // Verify the projectDir is correct for the current structure
      final nestedExists = await Directory(path.join(unityLibraryPath, 'unityLibrary')).exists();
      final expectedPath = nestedExists ? 'unityLibrary/unityLibrary' : 'unityLibrary';

      if (content.contains('unityLibrary/unityLibrary') && !nestedExists) {
        logger.detail('Fixing unityLibrary projectDir path...');
        content = content.replaceAll(
          "project(':unityLibrary').projectDir = file('unityLibrary/unityLibrary')",
          "project(':unityLibrary').projectDir = file('unityLibrary')",
        );
        await settingsFile.writeAsString(content);
        logger.success('Updated unityLibrary projectDir to match structure');
      } else if (!content.contains('unityLibrary/unityLibrary') && nestedExists) {
        logger.detail('Fixing unityLibrary projectDir path...');
        content = content.replaceAll(
          "project(':unityLibrary').projectDir = file('unityLibrary')",
          "project(':unityLibrary').projectDir = file('unityLibrary/unityLibrary')",
        );
        await settingsFile.writeAsString(content);
        logger.success('Updated unityLibrary projectDir to match structure');
      }
    }

    // Configure app/build.gradle
    await _configureAppBuildGradle(androidDir);
  }

  /// Find appropriate index to insert include statement
  int _findInsertIndexForInclude(List<String> lines) {
    // Find the last line with 'include' statement
    int lastIncludeIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('include ')) {
        lastIncludeIndex = i;
      }
    }

    // Insert after the last include, or at the end
    return lastIncludeIndex >= 0 ? lastIncludeIndex + 1 : lines.length;
  }

  /// Configure app/build.gradle to depend on unityLibrary
  Future<void> _configureAppBuildGradle(String androidDir) async {
    final appBuildGradlePath = path.join(androidDir, 'app', 'build.gradle');

    if (!await File(appBuildGradlePath).exists()) {
      logger.warning('app/build.gradle not found');
      return;
    }

    final buildFile = File(appBuildGradlePath);
    String content = await buildFile.readAsString();

    // Check if unityLibrary dependency already exists
    final hasDependency = content.contains('implementation project(":unityLibrary")') ||
        content.contains("implementation project(':unityLibrary')");

    if (!hasDependency) {
      logger.detail('Adding unityLibrary dependency to app/build.gradle...');

      // Try to find existing dependencies block first
      var dependenciesMatch = RegExp(r'dependencies\s*\{').firstMatch(content);

      if (dependenciesMatch != null) {
        // Add to existing dependencies block
        final insertPos = dependenciesMatch.end;
        final before = content.substring(0, insertPos);
        final after = content.substring(insertPos);

        content = '$before\n    // Unity integration\n    implementation project(":unityLibrary")$after';
        await buildFile.writeAsString(content);
        logger.success('Added unityLibrary dependency to app/build.gradle');
      } else {
        // No dependencies block found, add one after flutter block
        final flutterBlockMatch = RegExp(r'flutter\s*\{[^}]*\}', multiLine: true).firstMatch(content);

        if (flutterBlockMatch != null) {
          final insertPos = flutterBlockMatch.end;
          final before = content.substring(0, insertPos);
          final after = content.substring(insertPos);

          final dependenciesBlock = '''

dependencies {
    // Unity integration
    implementation project(':unityLibrary')
}''';

          content = '$before$dependenciesBlock$after';
          await buildFile.writeAsString(content);
          logger.success('Added unityLibrary dependency to app/build.gradle');
        } else {
          logger.warning('Could not find dependencies or flutter block in app/build.gradle');
          logger.info('Please manually add: implementation project(\':unityLibrary\')');
        }
      }
    } else {
      logger.detail('unityLibrary dependency already in app/build.gradle');
    }

    // Re-read content after potential modifications
    content = await buildFile.readAsString();

    // Configure minSdk for Unity
    await _configureMinSdk(buildFile, content);

    // Re-read again after minSdk changes
    content = await buildFile.readAsString();

    // Check ndk abiFilters configuration
    await _configureNdkAbiFilters(buildFile, content);
  }

  /// Configure minSdk for Unity compatibility
  Future<void> _configureMinSdk(File buildFile, String content) async {
    // Unity requires minSdk 22
    if (content.contains('minSdk = 22') || content.contains('minSdk 22') || content.contains('minSdkVersion 22')) {
      logger.detail('minSdk already set to 22');
      return;
    }

    // Check if we need to update minSdk
    final minSdkMatch = RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion').firstMatch(content);
    if (minSdkMatch != null) {
      logger.detail('Updating minSdk to 22 for Unity compatibility...');

      content = content.replaceFirst(
        RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'),
        'minSdk = 22  // Required by Unity'
      );

      await buildFile.writeAsString(content);
      logger.success('Updated minSdk to 22');
    }
  }

  /// Configure NDK abiFilters for Unity
  Future<void> _configureNdkAbiFilters(File buildFile, String content) async {
    // Unity typically needs armeabi-v7a and arm64-v8a
    final hasNdkConfig = content.contains('abiFilters');

    if (!hasNdkConfig) {
      logger.detail('Checking NDK configuration...');

      // Find defaultConfig block
      final defaultConfigMatch = RegExp(r'defaultConfig\s*\{').firstMatch(content);
      if (defaultConfigMatch != null) {
        // Check if there's already an ndk block
        final ndkBlockMatch = RegExp(r'ndk\s*\{').firstMatch(content);
        if (ndkBlockMatch == null) {
          logger.detail('Adding NDK abiFilters configuration...');

          // Find the closing brace of defaultConfig
          int braceCount = 0;
          int insertPos = defaultConfigMatch.end;
          bool foundDefaultConfigEnd = false;

          for (int i = defaultConfigMatch.end; i < content.length; i++) {
            if (content[i] == '{') braceCount++;
            if (content[i] == '}') {
              if (braceCount == 0) {
                insertPos = i;
                foundDefaultConfigEnd = true;
                break;
              }
              braceCount--;
            }
          }

          if (foundDefaultConfigEnd) {
            final before = content.substring(0, insertPos);
            final after = content.substring(insertPos);

            final ndkConfig = '''
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a'
        }
''';

            content = '$before$ndkConfig    $after';
            await buildFile.writeAsString(content);
            logger.success('Added NDK abiFilters configuration');
          }
        }
      }
    } else {
      logger.detail('NDK configuration already present');
    }
  }

  /// Sync iOS files
  Future<void> _syncIOS(String source, String target) async {
    logger.detail('Syncing iOS files...');

    // Copy UnityFramework.framework
    final framework = path.join(source, 'UnityFramework.framework');
    if (await Directory(framework).exists()) {
      await FileUtils.copyDirectory(framework, target);
      logger.success('Copied UnityFramework.framework to $target');
    } else {
      throw Exception('UnityFramework.framework not found in export');
    }

    // Auto-configure iOS integration
    await _configureIOSIntegration(target);
  }

  /// Configure iOS Xcode integration
  Future<void> _configureIOSIntegration(String frameworkPath) async {
    logger.info('Configuring iOS integration...');

    // Get the ios directory (parent of target path)
    final iosDir = Directory(frameworkPath).parent.path;

    // Configure Podfile
    await _configurePodfile(iosDir);

    // Configure Info.plist
    await _configureInfoPlist(iosDir);

    logger.success('iOS integration configuration complete');
    logger.info('');
    logger.info('Next steps:');
    logger.info('1. Run: cd ios && pod install');
    logger.info('2. Open Runner.xcworkspace in Xcode');
    logger.info('3. Select Runner target > General tab');
    logger.info('4. Add UnityFramework.framework to "Frameworks, Libraries, and Embedded Content"');
    logger.info('5. Set "Embed & Sign" for UnityFramework.framework');
  }

  /// Configure Podfile for Unity
  Future<void> _configurePodfile(String iosDir) async {
    final podfilePath = path.join(iosDir, 'Podfile');

    if (!await File(podfilePath).exists()) {
      logger.warning('Podfile not found at $podfilePath');
      return;
    }

    final podfile = File(podfilePath);
    String content = await podfile.readAsString();

    // Check if Unity configuration already exists
    if (content.contains('UnityFramework')) {
      logger.detail('UnityFramework already configured in Podfile');
      return;
    }

    logger.detail('Adding UnityFramework configuration to Podfile...');

    // Find the target 'Runner' do block
    final targetMatch = RegExp("target\\s+['\"]Runner['\"]").firstMatch(content);
    if (targetMatch != null) {
      // Find the end of the target block
      int braceCount = 0;
      int insertPos = targetMatch.end;
      bool foundTargetEnd = false;

      // Skip to the opening brace
      for (int i = targetMatch.end; i < content.length; i++) {
        if (content[i] == '{' || (i + 3 < content.length && content.substring(i, i + 3) == ' do')) {
          insertPos = i + (content[i] == '{' ? 1 : 3);
          break;
        }
      }

      final before = content.substring(0, insertPos);
      final after = content.substring(insertPos);

      final unityConfig = '''

  # Unity Framework integration
  pod 'UnityFramework', :path => 'UnityFramework.framework'
''';

      content = '$before$unityConfig$after';
      await podfile.writeAsString(content);
      logger.success('Added UnityFramework to Podfile');
    } else {
      logger.warning('Could not find Runner target in Podfile');
    }
  }

  /// Configure Info.plist for Unity
  Future<void> _configureInfoPlist(String iosDir) async {
    final infoPlistPath = path.join(iosDir, 'Runner', 'Info.plist');

    if (!await File(infoPlistPath).exists()) {
      logger.warning('Info.plist not found at $infoPlistPath');
      return;
    }

    final infoPlist = File(infoPlistPath);
    String content = await infoPlist.readAsString();

    // Check if Unity configuration already exists
    if (content.contains('UnityFramework') || content.contains('io.flutter.embedded_views_preview')) {
      logger.detail('Unity configuration already in Info.plist');
      return;
    }

    logger.detail('Adding Unity configuration to Info.plist...');

    // Add io.flutter.embedded_views_preview key (required for platform views)
    if (!content.contains('io.flutter.embedded_views_preview')) {
      // Find the last </dict> before </plist>
      final dictEndMatch = RegExp(r'</dict>\s*</plist>').firstMatch(content);
      if (dictEndMatch != null) {
        final insertPos = dictEndMatch.start;
        final before = content.substring(0, insertPos);
        final after = content.substring(insertPos);

        final platformViewConfig = '''	<key>io.flutter.embedded_views_preview</key>
	<true/>
''';

        content = '$before$platformViewConfig$after';
        await infoPlist.writeAsString(content);
        logger.success('Added platform views configuration to Info.plist');
      }
    }
  }

  /// Sync macOS files
  Future<void> _syncMacOS(String source, String target) async {
    logger.detail('Syncing macOS files...');

    // Similar to iOS
    await _syncIOS(source, target);
  }

  /// Sync Windows files
  Future<void> _syncWindows(String source, String target) async {
    logger.detail('Syncing Windows files...');

    await FileUtils.copyDirectory(source, target);
    logger.success('Copied Windows build to $target');
  }

  /// Sync Linux files
  Future<void> _syncLinux(String source, String target) async {
    logger.detail('Syncing Linux files...');

    await FileUtils.copyDirectory(source, target);
    logger.success('Copied Linux build to $target');
  }

  String _getPlatformExportDir(String platform) {
    switch (platform) {
      case 'android': return 'Android';
      case 'ios': return 'iOS';
      case 'macos': return 'macOS';
      case 'windows': return 'Windows';
      case 'linux': return 'Linux';
      default: return platform;
    }
  }

  String _getDefaultTargetPath(String platform) {
    switch (platform) {
      case 'android': return 'android/unityLibrary';
      case 'ios': return 'ios/UnityFramework.framework';
      case 'macos': return 'macos/UnityFramework.framework';
      case 'windows': return 'windows/unity_build';
      case 'linux': return 'linux/unity_build';
      default: return platform;
    }
  }

  String _getBuildMethod(String platform) {
    // Unity build method (requires custom Unity Editor script)
    // Must include full namespace path
    return 'Xraph.GameFramework.Unity.Editor.FlutterBuildScript.Build${_capitalize(platform)}';
  }

  String _getBuildTarget(String platform) {
    switch (platform) {
      case 'android': return 'Android';
      case 'ios': return 'iOS';
      case 'macos': return 'StandaloneOSX';
      case 'windows': return 'StandaloneWindows64';
      case 'linux': return 'StandaloneLinux64';
      default: return platform;
    }
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
