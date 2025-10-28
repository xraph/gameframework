import 'dart:io';
import 'package:args/command_runner.dart';
import '../config/config_loader.dart';
import '../exporters/unity_exporter.dart';
import '../exporters/unreal_exporter.dart';
import '../utils/logger.dart';

/// Sync exported files to Flutter project
class SyncCommand extends Command {
  @override
  final name = 'sync';

  @override
  final description = 'Copy exported game files to Flutter project';

  final logger = Logger();

  SyncCommand() {
    argParser
      ..addOption('platform', abbr: 'p', help: 'Target platform')
      ..addFlag('all', help: 'Sync all enabled platforms', defaultsTo: false)
      ..addFlag('clean', help: 'Clean target directory first', defaultsTo: false)
      ..addOption('config', abbr: 'c', help: 'Path to .game.yml');
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      logger.error('Please specify engine: unity or unreal');
      logger.info('Usage: game sync <unity|unreal> --platform <platform>');
      exit(1);
    }

    final engine = argResults!.rest[0].toLowerCase();
    final platform = argResults!['platform'] as String?;
    final syncAll = argResults!['all'] as bool;
    final configPath = argResults!['config'] as String?;

    if (!syncAll && platform == null) {
      logger.error('Please specify --platform or use --all');
      exit(1);
    }

    try {
      final config = ConfigLoader.loadConfig(configPath: configPath);
      final engineConfig = config.engines[engine];

      if (engineConfig == null) {
        logger.error('Engine "$engine" not configured');
        exit(1);
      }

      final platforms = syncAll
          ? engineConfig.platforms.keys.where((p) => engineConfig.platforms[p]!.enabled).toList()
          : [platform!];

      for (final targetPlatform in platforms) {
        logger.info('');
        logger.info('Syncing $engine files for $targetPlatform...');

        final success = await _syncForPlatform(
          engine,
          engineConfig,
          targetPlatform,
          Directory.current.path,
        );

        if (!success) {
          logger.error('Sync failed for $targetPlatform');
          exit(1);
        }
      }

      logger.success('');
      logger.success('All syncs completed successfully!');
    } catch (e) {
      logger.error('Sync failed: $e');
      exit(1);
    }
  }

  Future<bool> _syncForPlatform(
    String engine,
    dynamic engineConfig,
    String platform,
    String flutterProjectPath,
  ) async {
    switch (engine) {
      case 'unity':
        final exporter = UnityExporter(config: engineConfig, logger: logger);
        return await exporter.sync(platform, flutterProjectPath);
      case 'unreal':
        final exporter = UnrealExporter(config: engineConfig, logger: logger);
        return await exporter.sync(platform, flutterProjectPath);
      default:
        logger.error('Unknown engine: $engine');
        return false;
    }
  }
}
