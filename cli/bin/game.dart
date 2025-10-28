#!/usr/bin/env dart

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:game_cli/src/commands/init_command.dart';
import 'package:game_cli/src/commands/export_command.dart';
import 'package:game_cli/src/commands/sync_command.dart';
import 'package:game_cli/src/commands/build_command.dart';
import 'package:game_cli/src/commands/config_command.dart';

void main(List<String> arguments) async {
  final runner = CommandRunner(
    'game',
    'Flutter Game Framework CLI - Automate Unity and Unreal Engine integration',
  )
    ..addCommand(InitCommand())
    ..addCommand(ExportCommand())
    ..addCommand(SyncCommand())
    ..addCommand(BuildCommand())
    ..addCommand(ConfigCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    print(e);
    exit(64); // Exit code for usage error
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
