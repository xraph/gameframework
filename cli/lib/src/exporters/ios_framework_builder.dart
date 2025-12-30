import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';
import '../utils/logger.dart';

/// Builds UnityFramework.framework from Unity iOS Xcode export
class IOSFrameworkBuilder {
  final Logger logger;
  final Shell shell;

  IOSFrameworkBuilder({required this.logger})
      : shell = Shell(verbose: false);

  /// Build UnityFramework from Unity iOS export
  Future<bool> buildFramework({
    required String unityExportPath,
    required String outputPath,
    bool isSimulator = false,
  }) async {
    logger.info('Building UnityFramework for iOS...');

    // Check if Unity-iPhone.xcodeproj exists
    final xcodeProjectPath = path.join(unityExportPath, 'Unity-iPhone.xcodeproj');
    if (!await Directory(xcodeProjectPath).exists()) {
      logger.error('Unity-iPhone.xcodeproj not found at: $xcodeProjectPath');
      return false;
    }

    logger.detail('Found Xcode project at: $xcodeProjectPath');

    try {
      // Build for device
      await _buildForDevice(unityExportPath, outputPath);

      // Optionally build for simulator and create XCFramework
      if (isSimulator) {
        await _buildForSimulator(unityExportPath, outputPath);
        await _createXCFramework(outputPath);
      }

      logger.success('UnityFramework built successfully!');
      return true;
    } catch (e) {
      logger.error('Framework build failed: $e');
      return false;
    }
  }

  /// Build UnityFramework for device (arm64)
  Future<void> _buildForDevice(String unityExportPath, String outputPath) async {
    logger.info('Building for iOS device (arm64)...');

    final archivePath = path.join(outputPath, 'ios.xcarchive');
    
    // Clean previous builds
    if (await Directory(archivePath).exists()) {
      await Directory(archivePath).delete(recursive: true);
    }

    // Create a temporary script file with the build commands
    final tempDir = await Directory.systemTemp.createTemp('unity_ios_build_');
    final scriptPath = path.join(tempDir.path, 'build.sh');
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsString('''#!/bin/bash
set -e
cd "\$1"
xcodebuild archive \\
  -project Unity-iPhone.xcodeproj \\
  -scheme UnityFramework \\
  -configuration Release \\
  -destination "generic/platform=iOS" \\
  -archivePath "\$2" \\
  IPHONEOS_DEPLOYMENT_TARGET=12.0 \\
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \\
  SKIP_INSTALL=NO
''');
    await Process.run('chmod', ['+x', scriptPath]);

    try {
      final result = await shell.run(
        'bash "$scriptPath" "$unityExportPath" "$archivePath"'
      );

      if (result.first.exitCode != 0) {
        throw Exception('Device build failed');
      }
    } finally {
      // Clean up temporary script
      await tempDir.delete(recursive: true);
    }

    // Copy the built framework from archive
    final builtFramework = path.join(
      archivePath,
      'Products/Library/Frameworks/UnityFramework.framework',
    );

    if (!await Directory(builtFramework).exists()) {
      throw Exception('Built framework not found at: $builtFramework');
    }

    final targetFramework = path.join(outputPath, 'UnityFramework.framework');
    await _copyDirectory(builtFramework, targetFramework);
    
    logger.success('Device framework built: $targetFramework');
  }

  /// Build UnityFramework for simulator (x86_64, arm64)
  Future<void> _buildForSimulator(String unityExportPath, String outputPath) async {
    logger.info('Building for iOS Simulator...');

    final archivePath = path.join(outputPath, 'simulator.xcarchive');
    
    // Clean previous builds
    if (await Directory(archivePath).exists()) {
      await Directory(archivePath).delete(recursive: true);
    }

    // Create shell with working directory set to Unity export path
    final buildShell = Shell(workingDirectory: unityExportPath);
    
    final result = await buildShell.run(
      'xcodebuild archive '
      '-project Unity-iPhone.xcodeproj '
      '-scheme UnityFramework '
      '-configuration Release '
      '-destination "generic/platform=iOS Simulator" '
      '-archivePath "$archivePath" '
      'IPHONEOS_DEPLOYMENT_TARGET=12.0 '
      'BUILD_LIBRARY_FOR_DISTRIBUTION=YES '
      'SKIP_INSTALL=NO'
    );

    if (result.first.exitCode != 0) {
      throw Exception('Simulator build failed');
    }

    logger.success('Simulator framework built');
  }

  /// Create XCFramework (universal binary for device + simulator)
  Future<void> _createXCFramework(String outputPath) async {
    logger.info('Creating XCFramework...');

    final deviceFramework = path.join(
      outputPath,
      'ios.xcarchive/Products/Library/Frameworks/UnityFramework.framework',
    );

    final simFramework = path.join(
      outputPath,
      'simulator.xcarchive/Products/Library/Frameworks/UnityFramework.framework',
    );

    final xcFrameworkPath = path.join(outputPath, 'UnityFramework.xcframework');

    // Remove existing XCFramework if it exists
    if (await Directory(xcFrameworkPath).exists()) {
      await Directory(xcFrameworkPath).delete(recursive: true);
    }

    final result = await shell.run('''
      xcodebuild -create-xcframework \
        -framework "$deviceFramework" \
        -framework "$simFramework" \
        -output "$xcFrameworkPath"
    ''');

    if (result.first.exitCode != 0) {
      throw Exception('XCFramework creation failed');
    }

    logger.success('XCFramework created: $xcFrameworkPath');
  }

  /// Copy directory recursively
  Future<void> _copyDirectory(String source, String destination) async {
    final sourceDir = Directory(source);
    final destDir = Directory(destination);

    if (await destDir.exists()) {
      await destDir.delete(recursive: true);
    }

    await destDir.create(recursive: true);

    await for (final entity in sourceDir.list(recursive: true)) {
      final relativePath = path.relative(entity.path, from: source);
      final newPath = path.join(destination, relativePath);

      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(path.dirname(newPath)).create(recursive: true);
        await entity.copy(newPath);
      }
    }
  }
}

