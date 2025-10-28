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

    final buildMethod = _getBuildMethod(platform);
    final buildTarget = _getBuildTarget(platform);

    final args = [
      '-quit',
      '-batchmode',
      '-projectPath', projectPath,
      '-executeMethod', buildMethod,
      '-buildTarget', buildTarget,
      '-buildPath', exportPath,
    ];

    if (development) {
      args.add('-development');
    }

    try {
      final result = await shell.run('$unityPath ${args.join(' ')}');
      return result.first.exitCode == 0;
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
    return 'FlutterBuildScript.Build${_capitalize(platform)}';
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
