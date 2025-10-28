import 'dart:io';
import 'package:args/command_runner.dart';
import '../config/config_loader.dart';
import '../exporters/unity_exporter.dart';
import '../exporters/unreal_exporter.dart';
import '../utils/logger.dart';

/// Export game from Unity or Unreal
class ExportCommand extends Command {
  @override
  final name = 'export';

  @override
  final description = 'Export/package game from Unity or Unreal Engine';

  final logger = Logger();

  ExportCommand() {
    argParser
      ..addOption('platform', abbr: 'p', help: 'Target platform (android, ios, etc.)')
      ..addFlag('all', help: 'Export all enabled platforms', defaultsTo: false)
      ..addFlag('development', abbr: 'd', help: 'Development build', defaultsTo: false)
      ..addOption('config', abbr: 'c', help: 'Path to .game.yml');
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      logger.error('Please specify engine: unity or unreal');
      logger.info('Usage: game export <unity|unreal> --platform <platform>');
      exit(1);
    }

    final engine = argResults!.rest[0].toLowerCase();
    final platform = argResults!['platform'] as String?;
    final exportAll = argResults!['all'] as bool;
    final configPath = argResults!['config'] as String?;

    if (!exportAll && platform == null) {
      logger.error('Please specify --platform or use --all');
      exit(1);
    }

    try {
      final config = ConfigLoader.loadConfig(configPath: configPath);
      final engineConfig = config.engines[engine];

      if (engineConfig == null) {
        logger.error('Engine "$engine" not configured in .game.yml');
        exit(1);
      }

      final platforms = exportAll
          ? engineConfig.platforms.keys.where((p) => engineConfig.platforms[p]!.enabled).toList()
          : [platform!];

      for (final targetPlatform in platforms) {
        logger.info('');
        logger.info('Exporting $engine for $targetPlatform...');

        final success = await _exportForPlatform(engine, engineConfig, targetPlatform);

        if (!success) {
          logger.error('Export failed for $targetPlatform');
          exit(1);
        }
      }

      logger.success('');
      logger.success('All exports completed successfully!');
    } catch (e) {
      logger.error('Export failed: $e');
      exit(1);
    }
  }

  Future<bool> _exportForPlatform(
    String engine,
    dynamic engineConfig,
    String platform,
  ) async {
    switch (engine) {
      case 'unity':
        final exporter = UnityExporter(config: engineConfig, logger: logger);
        return await exporter.export(platform);
      case 'unreal':
        final exporter = UnrealExporter(config: engineConfig, logger: logger);
        return await exporter.export(platform);
      default:
        logger.error('Unknown engine: $engine');
        return false;
    }
  }
}
