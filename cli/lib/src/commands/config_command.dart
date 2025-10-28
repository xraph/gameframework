import 'dart:io';
import 'package:args/command_runner.dart';
import '../config/config_loader.dart';
import '../utils/logger.dart';

/// Config management command
class ConfigCommand extends Command {
  @override
  final name = 'config';

  @override
  final description = 'View or validate configuration';

  final logger = Logger();

  ConfigCommand() {
    addSubcommand(ConfigShowCommand());
    addSubcommand(ConfigValidateCommand());
    addSubcommand(ConfigEditCommand());
  }
}

class ConfigShowCommand extends Command {
  @override
  final name = 'show';

  @override
  final description = 'Display current configuration';

  final logger = Logger();

  @override
  Future<void> run() async {
    try {
      final config = ConfigLoader.loadConfig();
      logger.info('Configuration:');
      logger.info('  Name: ${config.name}');
      if (config.version != null) {
        logger.info('  Version: ${config.version}');
      }
      logger.info('  Engines: ${config.engines.keys.join(', ')}');

      for (final entry in config.engines.entries) {
        logger.info('');
        logger.info('${entry.key}:');
        logger.info('  Project: ${entry.value.projectPath}');
        logger.info('  Platforms: ${entry.value.platforms.keys.join(', ')}');
      }
    } catch (e) {
      logger.error('Failed to load config: $e');
      exit(1);
    }
  }
}

class ConfigValidateCommand extends Command {
  @override
  final name = 'validate';

  @override
  final description = 'Validate configuration';

  final logger = Logger();

  @override
  Future<void> run() async {
    try {
      final config = ConfigLoader.loadConfig();
      final errors = ConfigLoader.validateConfig(config);

      if (errors.isEmpty) {
        logger.success('Configuration is valid!');
      } else {
        logger.error('Configuration has errors:');
        for (final error in errors) {
          logger.error('  - $error');
        }
        exit(1);
      }
    } catch (e) {
      logger.error('Failed to validate config: $e');
      exit(1);
    }
  }
}

class ConfigEditCommand extends Command {
  @override
  final name = 'edit';

  @override
  final description = 'Open configuration file in editor';

  final logger = Logger();

  @override
  Future<void> run() async {
    try {
      final configFile = ConfigLoader.findConfigFile();
      if (configFile == null) {
        logger.error('No .game.yml found');
        exit(1);
      }

      // Open in default editor
      if (Platform.isMacOS || Platform.isLinux) {
        await Process.run('open', [configFile.path]);
      } else if (Platform.isWindows) {
        await Process.run('start', [configFile.path]);
      }

      logger.success('Opened ${configFile.path}');
    } catch (e) {
      logger.error('Failed to open editor: $e');
      exit(1);
    }
  }
}
