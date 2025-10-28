import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:process_run/shell.dart';
import '../config/config_loader.dart';
import '../exporters/unity_exporter.dart';
import '../exporters/unreal_exporter.dart';
import '../utils/logger.dart';

/// Build Flutter app with game export and sync
class BuildCommand extends Command {
  @override
  final name = 'build';

  @override
  final description = 'Export, sync, and build Flutter app (all-in-one)';

  final logger = Logger();

  BuildCommand() {
    argParser
      ..addOption('engine', abbr: 'e', help: 'Engine (unity or unreal)', mandatory: true)
      ..addFlag('development', abbr: 'd', help: 'Development build', defaultsTo: false)
      ..addFlag('release', help: 'Release build', defaultsTo: true)
      ..addFlag('skip-export', help: 'Skip game export', defaultsTo: false)
      ..addFlag('skip-sync', help: 'Skip file sync', defaultsTo: false)
      ..addOption('config', abbr: 'c', help: 'Path to .game.yml');
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      logger.error('Please specify platform: android, ios, macos, windows, or linux');
      logger.info('Usage: game build <platform> --engine <unity|unreal>');
      exit(1);
    }

    final platform = argResults!.rest[0].toLowerCase();
    final engine = argResults!['engine'] as String;
    final skipExport = argResults!['skip-export'] as bool;
    final skipSync = argResults!['skip-sync'] as bool;
    final configPath = argResults!['config'] as String?;

    try {
      final config = ConfigLoader.loadConfig(configPath: configPath);
      final engineConfig = config.engines[engine];

      if (engineConfig == null) {
        logger.error('Engine "$engine" not configured');
        exit(1);
      }

      // Step 1: Export game
      if (!skipExport) {
        logger.info('Step 1/3: Exporting $engine for $platform...');
        final exported = await _export(engine, engineConfig, platform);
        if (!exported) {
          logger.error('Export failed');
          exit(1);
        }
      } else {
        logger.info('Step 1/3: Skipped export');
      }

      // Step 2: Sync files
      if (!skipSync) {
        logger.info('Step 2/3: Syncing files...');
        final synced = await _sync(engine, engineConfig, platform, Directory.current.path);
        if (!synced) {
          logger.error('Sync failed');
          exit(1);
        }
      } else {
        logger.info('Step 2/3: Skipped sync');
      }

      // Step 3: Build Flutter app
      logger.info('Step 3/3: Building Flutter app...');
      final built = await _buildFlutter(platform);
      if (!built) {
        logger.error('Flutter build failed');
        exit(1);
      }

      logger.success('');
      logger.success('Build completed successfully!');
    } catch (e) {
      logger.error('Build failed: $e');
      exit(1);
    }
  }

  Future<bool> _export(String engine, dynamic engineConfig, String platform) async {
    switch (engine) {
      case 'unity':
        final exporter = UnityExporter(config: engineConfig, logger: logger);
        return await exporter.export(platform);
      case 'unreal':
        final exporter = UnrealExporter(config: engineConfig, logger: logger);
        return await exporter.export(platform);
      default:
        return false;
    }
  }

  Future<bool> _sync(String engine, dynamic engineConfig, String platform, String flutterPath) async {
    switch (engine) {
      case 'unity':
        final exporter = UnityExporter(config: engineConfig, logger: logger);
        return await exporter.sync(platform, flutterPath);
      case 'unreal':
        final exporter = UnrealExporter(config: engineConfig, logger: logger);
        return await exporter.sync(platform, flutterPath);
      default:
        return false;
    }
  }

  Future<bool> _buildFlutter(String platform) async {
    final shell = Shell();
    try {
      await shell.run('flutter build $platform');
      return true;
    } catch (e) {
      logger.error('Flutter build error: $e');
      return false;
    }
  }
}
