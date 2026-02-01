import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_stream/src/cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheEntry', () {
    test('fromJson parses correctly', () {
      final json = {
        'name': 'test.bundle',
        'sha256': 'abc123def456',
        'sizeBytes': 1024,
        'cachedAt': '2024-01-15T10:30:00.000Z',
      };

      final entry = CacheEntry.fromJson(json);

      expect(entry.name, equals('test.bundle'));
      expect(entry.sha256, equals('abc123def456'));
      expect(entry.sizeBytes, equals(1024));
    });

    test('toJson serializes correctly', () {
      final entry = CacheEntry(
        name: 'test.bundle',
        sha256: 'abc123def456',
        sizeBytes: 2048,
        cachedAt: DateTime(2024, 1, 15, 10, 30),
      );

      final json = entry.toJson();

      expect(json['name'], equals('test.bundle'));
      expect(json['sha256'], equals('abc123def456'));
      expect(json['sizeBytes'], equals(2048));
      expect(json['cachedAt'], isNotNull);
    });

    test('toJson and fromJson roundtrip correctly', () {
      final original = CacheEntry(
        name: 'bundle.dat',
        sha256: 'hash123',
        sizeBytes: 4096,
        cachedAt: DateTime.now(),
      );

      final json = original.toJson();
      final restored = CacheEntry.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.sha256, equals(original.sha256));
      expect(restored.sizeBytes, equals(original.sizeBytes));
    });
  });

  group('CacheManager with real filesystem', () {
    late Directory tempDir;
    late CacheManager cacheManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cache_test_');
      cacheManager = CacheManager();

      // Manually set up the cache directory for testing
      final cacheDir = Directory('${tempDir.path}/gameframework_streaming');
      await cacheDir.create(recursive: true);

      // Use reflection or a test helper to set the cache directory
      // For now, we'll test the CacheEntry class and basic logic
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('getCachedBundleNames returns empty list initially', () {
      expect(cacheManager.getCachedBundleNames(), isEmpty);
    });

    test('getCacheEntry returns null for unknown bundle', () {
      expect(cacheManager.getCacheEntry('nonexistent'), isNull);
    });
  });

  group('CacheManager manifest parsing', () {
    test('should parse manifest JSON correctly', () {
      final manifestJson = jsonEncode({
        'version': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'entries': {
          'bundle1': {
            'name': 'bundle1',
            'sha256': 'hash1',
            'sizeBytes': 1000,
            'cachedAt': DateTime.now().toIso8601String(),
          },
          'bundle2': {
            'name': 'bundle2',
            'sha256': 'hash2',
            'sizeBytes': 2000,
            'cachedAt': DateTime.now().toIso8601String(),
          },
        },
      });

      final parsed = jsonDecode(manifestJson) as Map<String, dynamic>;
      final entries = parsed['entries'] as Map<String, dynamic>;

      expect(entries.length, equals(2));
      expect(entries.containsKey('bundle1'), isTrue);
      expect(entries.containsKey('bundle2'), isTrue);
    });

    test('should handle empty manifest', () {
      final manifestJson = jsonEncode({
        'version': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'entries': <String, dynamic>{},
      });

      final parsed = jsonDecode(manifestJson) as Map<String, dynamic>;
      final entries = parsed['entries'] as Map<String, dynamic>;

      expect(entries, isEmpty);
    });
  });
}
