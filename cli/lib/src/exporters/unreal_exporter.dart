import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';
import '../../models/game_config.dart';
import '../utils/file_utils.dart';
import '../utils/logger.dart';

/// Unreal Engine exporter
class UnrealExporter {
  final EngineConfig config;
  final Logger logger;
  final Shell shell;

  UnrealExporter({
    required this.config,
    required this.logger,
  }) : shell = Shell(verbose: false);

  /// Export Unreal project for specified platform
  Future<bool> export(String platform) async {
    logger.info('Packaging Unreal project for $platform...');

    final platformConfig = config.platforms[platform];
    if (platformConfig == null || !platformConfig.enabled) {
      logger.warning('Platform $platform is not enabled');
      return false;
    }

    try {
      // Check Unreal installation
      final unrealPath = await _findUnrealEngine();
      if (unrealPath == null) {
        logger.error('Unreal Engine not found');
        return false;
      }

      logger.detail('Using Unreal at: $unrealPath');

      // Prepare export path
      final exportPath = config.exportPath ?? path.join(config.projectPath, 'Packaged');
      final platformExportPath = path.join(exportPath, _getPlatformExportDir(platform));

      await Directory(platformExportPath).create(recursive: true);

      // Package Unreal project
      final success = await _packageUnrealProject(
        unrealPath: unrealPath,
        projectPath: config.projectPath,
        platform: platform,
        exportPath: platformExportPath,
        development: config.exportSettings?.development ?? false,
      );

      if (!success) {
        logger.error('Unreal packaging failed');
        return false;
      }

      logger.success('Unreal packaging completed: $platformExportPath');
      return true;
    } catch (e) {
      logger.error('Export failed: $e');
      return false;
    }
  }

  /// Copy exported files to Flutter project
  Future<bool> sync(String platform, String flutterProjectPath) async {
    logger.info('Syncing Unreal files for $platform...');

    final platformConfig = config.platforms[platform];
    if (platformConfig == null || !platformConfig.enabled) {
      logger.warning('Platform $platform is not enabled');
      return false;
    }

    try {
      final exportPath = config.exportPath ?? path.join(config.projectPath, 'Packaged');
      final platformExportPath = path.join(exportPath, _getPlatformExportDir(platform));

      if (!await Directory(platformExportPath).exists()) {
        logger.error('Package directory not found: $platformExportPath');
        logger.hint('Run "game export unreal --platform $platform" first');
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

  /// Find Unreal Engine installation
  Future<String?> _findUnrealEngine() async {
    if (Platform.isMacOS) {
      // Check common locations on macOS
      final locations = [
        '/Users/Shared/Epic Games/UE_5.3/Engine/Build/BatchFiles/RunUAT.command',
        '/Users/Shared/Epic Games/UE_5.4/Engine/Build/BatchFiles/RunUAT.command',
      ];

      for (final loc in locations) {
        if (await File(loc).exists()) {
          return loc;
        }
      }

      // Check for any UE version
      final epicDir = Directory('/Users/Shared/Epic Games');
      if (await epicDir.exists()) {
        final versions = epicDir.listSync()
            .whereType<Directory>()
            .where((d) => path.basename(d.path).startsWith('UE_'))
            .map((d) => path.join(d.path, 'Engine', 'Build', 'BatchFiles', 'RunUAT.command'))
            .where((p) => File(p).existsSync());
        if (versions.isNotEmpty) {
          return versions.first;
        }
      }
    } else if (Platform.isWindows) {
      final locations = [
        r'C:\Program Files\Epic Games\UE_5.3\Engine\Build\BatchFiles\RunUAT.bat',
        r'C:\Program Files\Epic Games\UE_5.4\Engine\Build\BatchFiles\RunUAT.bat',
      ];

      for (final loc in locations) {
        if (await File(loc).exists()) {
          return loc;
        }
      }

      final epicDir = Directory(r'C:\Program Files\Epic Games');
      if (await epicDir.exists()) {
        final versions = epicDir.listSync()
            .whereType<Directory>()
            .where((d) => path.basename(d.path).startsWith('UE_'))
            .map((d) => path.join(d.path, 'Engine', 'Build', 'BatchFiles', 'RunUAT.bat'))
            .where((p) => File(p).existsSync());
        if (versions.isNotEmpty) {
          return versions.first;
        }
      }
    } else if (Platform.isLinux) {
      // Linux usually has UE in home directory
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        final ueDir = Directory(path.join(homeDir, 'UnrealEngine'));
        if (await ueDir.exists()) {
          final runUAT = path.join(ueDir.path, 'Engine', 'Build', 'BatchFiles', 'RunUAT.sh');
          if (await File(runUAT).exists()) {
            return runUAT;
          }
        }
      }
    }

    return null;
  }

  /// Package Unreal project
  Future<bool> _packageUnrealProject({
    required String unrealPath,
    required String projectPath,
    required String platform,
    required String exportPath,
    required bool development,
  }) async {
    logger.info('Packaging Unreal project...');

    // Find .uproject file
    final projectDir = Directory(projectPath);
    final uprojectFiles = projectDir.listSync()
        .whereType<File>()
        .where((f) => path.extension(f.path) == '.uproject')
        .toList();

    if (uprojectFiles.isEmpty) {
      logger.error('No .uproject file found in $projectPath');
      return false;
    }

    final uprojectPath = uprojectFiles.first.path;
    final buildConfig = development ? 'Development' : 'Shipping';
    final targetPlatform = _getUnrealPlatform(platform);

    final args = [
      'BuildCookRun',
      '-project=$uprojectPath',
      '-platform=$targetPlatform',
      '-configuration=$buildConfig',
      '-cook',
      '-stage',
      '-package',
      '-pak',
      '-archive',
      '-archivedirectory=$exportPath',
    ];

    try {
      final result = await shell.run('$unrealPath ${args.join(' ')}');
      return result.first.exitCode == 0;
    } catch (e) {
      logger.error('Packaging error: $e');
      return false;
    }
  }

  /// Sync Android files
  Future<void> _syncAndroid(String source, String target) async {
    logger.detail('Syncing Android files...');

    // Find APK
    final apkFiles = await Directory(source)
        .list(recursive: true)
        .where((e) => e is File && path.extension(e.path) == '.apk')
        .toList();

    if (apkFiles.isEmpty) {
      throw Exception('No APK found in package');
    }

    final apkPath = apkFiles.first.path;
    final tempDir = path.join(Directory.systemTemp.path, 'unreal_extract');

    try {
      // Extract APK
      await FileUtils.deleteDirectory(tempDir);
      await FileUtils.unzip(apkPath, tempDir);

      // Copy .so libraries
      final jniLibsSource = path.join(tempDir, 'lib', 'arm64-v8a');
      final jniLibsTarget = path.join(target, 'jniLibs', 'arm64-v8a');

      if (await Directory(jniLibsSource).exists()) {
        await FileUtils.copyDirectory(jniLibsSource, jniLibsTarget);
        logger.success('Copied native libraries to $jniLibsTarget');
      }

      // Copy assets
      final assetsSource = path.join(tempDir, 'assets');
      final assetsTarget = path.join(target, 'assets', 'UnrealGame');

      if (await Directory(assetsSource).exists()) {
        await FileUtils.copyDirectory(assetsSource, assetsTarget);
        logger.success('Copied game assets to $assetsTarget');
      }
    } finally {
      // Clean up temp directory
      await FileUtils.deleteDirectory(tempDir);
    }
  }

  /// Sync iOS files
  Future<void> _syncIOS(String source, String target) async {
    logger.detail('Syncing iOS files...');

    // Find IPA
    final ipaFiles = await Directory(source)
        .list(recursive: true)
        .where((e) => e is File && path.extension(e.path) == '.ipa')
        .toList();

    if (ipaFiles.isEmpty) {
      throw Exception('No IPA found in package');
    }

    final ipaPath = ipaFiles.first.path;
    final tempDir = path.join(Directory.systemTemp.path, 'unreal_extract');

    try {
      // Extract IPA
      await FileUtils.deleteDirectory(tempDir);
      await FileUtils.unzip(ipaPath, tempDir);

      // Find .app bundle
      final payloadDir = path.join(tempDir, 'Payload');
      final appDirs = await Directory(payloadDir)
          .list()
          .where((e) => e is Directory && path.extension(e.path) == '.app')
          .toList();

      if (appDirs.isEmpty) {
        throw Exception('No .app found in IPA');
      }

      final appDir = appDirs.first.path;
      final frameworkSource = path.join(appDir, 'Frameworks', 'UnrealFramework.framework');

      if (await Directory(frameworkSource).exists()) {
        await FileUtils.copyDirectory(frameworkSource, target);

        // Copy game content
        final contentSource = path.join(appDir, path.basename(appDir).replaceAll('.app', ''), 'Content');
        final contentTarget = path.join(target, 'Content');

        if (await Directory(contentSource).exists()) {
          await FileUtils.copyDirectory(contentSource, contentTarget);
        }

        logger.success('Copied UnrealFramework.framework to $target');
      } else {
        throw Exception('UnrealFramework.framework not found in IPA');
      }
    } finally {
      await FileUtils.deleteDirectory(tempDir);
    }
  }

  /// Sync macOS files
  Future<void> _syncMacOS(String source, String target) async {
    logger.detail('Syncing macOS files...');

    // Find .app bundle
    final appBundles = await Directory(source)
        .list(recursive: true)
        .where((e) => e is Directory && path.extension(e.path) == '.app')
        .toList();

    if (appBundles.isNotEmpty) {
      await FileUtils.copyDirectory(appBundles.first.path, target);
      logger.success('Copied app bundle to $target');
    } else {
      throw Exception('No .app bundle found');
    }
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
      case 'ios': return 'IOS';
      case 'macos': return 'Mac';
      case 'windows': return 'Windows';
      case 'linux': return 'Linux';
      default: return platform;
    }
  }

  String _getDefaultTargetPath(String platform) {
    switch (platform) {
      case 'android': return 'android/app/src/main';
      case 'ios': return 'ios/UnrealFramework.framework';
      case 'macos': return 'macos/UnrealFramework.framework';
      case 'windows': return 'windows/unreal_build';
      case 'linux': return 'linux/unreal_build';
      default: return platform;
    }
  }

  String _getUnrealPlatform(String platform) {
    switch (platform) {
      case 'android': return 'Android';
      case 'ios': return 'IOS';
      case 'macos': return 'Mac';
      case 'windows': return 'Win64';
      case 'linux': return 'Linux';
      default: return platform;
    }
  }
}
