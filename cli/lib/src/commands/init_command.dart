import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../config/config_loader.dart';
import '../utils/logger.dart';

/// Initialize .game.yml configuration
class InitCommand extends Command {
  @override
  final name = 'init';

  @override
  final description = 'Create a .game.yml configuration file';

  final logger = Logger();

  InitCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Project name',
      )
      ..addFlag(
        'unity',
        help: 'Include Unity configuration',
        defaultsTo: true,
      )
      ..addFlag(
        'unreal',
        help: 'Include Unreal configuration',
        defaultsTo: false,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing .game.yml',
        defaultsTo: false,
      );
  }

  @override
  Future<void> run() async {
    final projectName = argResults!['name'] as String? ??
        path.basename(Directory.current.path);
    final includeUnity = argResults!['unity'] as bool;
    final includeUnreal = argResults!['unreal'] as bool;
    final force = argResults!['force'] as bool;

    final configFile = File(path.join(Directory.current.path, ConfigLoader.configFileName));

    if (configFile.existsSync() && !force) {
      logger.error('.game.yml already exists. Use --force to overwrite.');
      exit(1);
    }

    logger.info('Creating .game.yml...');

    final config = ConfigLoader.createDefaultConfig(
      projectName: projectName,
      includeUnity: includeUnity,
      includeUnreal: includeUnreal,
    );

    await configFile.writeAsString(config);

    logger.success('.game.yml created successfully!');
    logger.info('');
    logger.info('Next steps:');
    logger.info('1. Edit .game.yml and configure your engine project paths');
    logger.info('2. Run "game export <engine> --platform <platform>" to export your game');
    logger.info('3. Run "game sync <engine> --platform <platform>" to copy files to Flutter project');
  }
}
