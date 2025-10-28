import 'package:yaml/yaml.dart';

/// Configuration model for .game.yml
class GameConfig {
  final String name;
  final String? version;
  final Map<String, EngineConfig> engines;

  GameConfig({
    required this.name,
    this.version,
    required this.engines,
  });

  factory GameConfig.fromYaml(YamlMap yaml) {
    final enginesYaml = yaml['engines'] as YamlMap?;
    final engines = <String, EngineConfig>{};

    if (enginesYaml != null) {
      for (final entry in enginesYaml.entries) {
        final engineType = entry.key.toString();
        final engineData = entry.value as YamlMap;
        engines[engineType] = EngineConfig.fromYaml(engineData);
      }
    }

    return GameConfig(
      name: yaml['name']?.toString() ?? 'UnnamedGame',
      version: yaml['version']?.toString(),
      engines: engines,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'name': name,
      if (version != null) 'version': version,
      'engines': engines.map((key, value) => MapEntry(key, value.toYaml())),
    };
  }
}

/// Engine-specific configuration
class EngineConfig {
  final String projectPath;
  final String? exportPath;
  final Map<String, PlatformConfig> platforms;
  final ExportSettings? exportSettings;

  EngineConfig({
    required this.projectPath,
    this.exportPath,
    required this.platforms,
    this.exportSettings,
  });

  factory EngineConfig.fromYaml(YamlMap yaml) {
    final platformsYaml = yaml['platforms'] as YamlMap?;
    final platforms = <String, PlatformConfig>{};

    if (platformsYaml != null) {
      for (final entry in platformsYaml.entries) {
        final platform = entry.key.toString();
        final platformData = entry.value as YamlMap?;
        if (platformData != null) {
          platforms[platform] = PlatformConfig.fromYaml(platformData);
        }
      }
    }

    return EngineConfig(
      projectPath: yaml['project_path']?.toString() ?? '',
      exportPath: yaml['export_path']?.toString(),
      platforms: platforms,
      exportSettings: yaml['export_settings'] != null
          ? ExportSettings.fromYaml(yaml['export_settings'] as YamlMap)
          : null,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'project_path': projectPath,
      if (exportPath != null) 'export_path': exportPath,
      'platforms': platforms.map((key, value) => MapEntry(key, value.toYaml())),
      if (exportSettings != null) 'export_settings': exportSettings!.toYaml(),
    };
  }
}

/// Platform-specific configuration
class PlatformConfig {
  final bool enabled;
  final String? targetPath;
  final Map<String, dynamic>? buildSettings;

  PlatformConfig({
    required this.enabled,
    this.targetPath,
    this.buildSettings,
  });

  factory PlatformConfig.fromYaml(YamlMap yaml) {
    return PlatformConfig(
      enabled: yaml['enabled'] as bool? ?? true,
      targetPath: yaml['target_path']?.toString(),
      buildSettings: yaml['build_settings'] != null
          ? Map<String, dynamic>.from(yaml['build_settings'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'enabled': enabled,
      if (targetPath != null) 'target_path': targetPath,
      if (buildSettings != null) 'build_settings': buildSettings,
    };
  }
}

/// Export settings for engine builds
class ExportSettings {
  final bool development;
  final String? buildConfiguration;
  final List<String>? scenes;
  final List<String>? levels;
  final Map<String, dynamic>? customSettings;

  ExportSettings({
    this.development = false,
    this.buildConfiguration,
    this.scenes,
    this.levels,
    this.customSettings,
  });

  factory ExportSettings.fromYaml(YamlMap yaml) {
    return ExportSettings(
      development: yaml['development'] as bool? ?? false,
      buildConfiguration: yaml['build_configuration']?.toString(),
      scenes: (yaml['scenes'] as YamlList?)?.map((e) => e.toString()).toList(),
      levels: (yaml['levels'] as YamlList?)?.map((e) => e.toString()).toList(),
      customSettings: yaml['custom_settings'] != null
          ? Map<String, dynamic>.from(yaml['custom_settings'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toYaml() {
    return {
      'development': development,
      if (buildConfiguration != null) 'build_configuration': buildConfiguration,
      if (scenes != null) 'scenes': scenes,
      if (levels != null) 'levels': levels,
      if (customSettings != null) 'custom_settings': customSettings,
    };
  }
}
