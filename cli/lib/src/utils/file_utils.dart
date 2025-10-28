import 'dart:io';
import 'package:path/path.dart' as path;

/// File utility functions
class FileUtils {
  /// Copy directory recursively
  static Future<void> copyDirectory(String source, String target) async {
    final sourceDir = Directory(source);
    final targetDir = Directory(target);

    if (!await sourceDir.exists()) {
      throw Exception('Source directory does not exist: $source');
    }

    // Create target directory
    await targetDir.create(recursive: true);

    // Copy all files and subdirectories
    await for (final entity in sourceDir.list(recursive: false)) {
      final targetPath = path.join(target, path.basename(entity.path));

      if (entity is Directory) {
        await copyDirectory(entity.path, targetPath);
      } else if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Link) {
        final linkTarget = await entity.target();
        await Link(targetPath).create(linkTarget);
      }
    }
  }

  /// Delete directory if exists
  static Future<void> deleteDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Check if path is inside zip/archive
  static bool isArchive(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.zip' || ext == '.apk' || ext == '.ipa';
  }

  /// Unzip file
  static Future<void> unzip(String zipPath, String targetPath) async {
    final result = await Process.run(
      'unzip',
      ['-q', '-o', zipPath, '-d', targetPath],
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to unzip: ${result.stderr}');
    }
  }
}
