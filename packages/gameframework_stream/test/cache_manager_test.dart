import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_stream/src/cache_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class MockPathProviderPlatform extends PathProviderPlatform {
  final Directory tempDir;
  
  MockPathProviderPlatform(this.tempDir);
  
  @override
  Future<String?> getApplicationCachePath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late Directory tempDir;
  late CacheManager cacheManager;
  
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cache_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
    cacheManager = CacheManager();
  });
  
  tearDown(() async {
    await tempDir.delete(recursive: true);
  });
  
  group('CacheManager', () {
    test('initialize creates cache directory', () async {
      await cacheManager.initialize();
      final cachePath = await cacheManager.getCachePath();
      
      expect(await Directory(cachePath).exists(), isTrue);
    });
    
    test('isCached returns false for uncached bundle', () async {
      await cacheManager.initialize();
      
      final result = await cacheManager.isCached('nonexistent.bundle');
      
      expect(result, isFalse);
    });
    
    test('cacheBundle stores data and updates manifest', () async {
      await cacheManager.initialize();
      final testData = [1, 2, 3, 4, 5];
      const bundleName = 'test.bundle';
      
      await cacheManager.cacheBundle(bundleName, testData);
      
      expect(await cacheManager.isCached(bundleName), isTrue);
    });
    
    test('getCachedBundlePath returns path for cached bundle', () async {
      await cacheManager.initialize();
      final testData = [1, 2, 3, 4, 5];
      const bundleName = 'test.bundle';
      
      await cacheManager.cacheBundle(bundleName, testData);
      final path = await cacheManager.getCachedBundlePath(bundleName);
      
      expect(path, isNotNull);
      expect(await File(path!).exists(), isTrue);
    });
    
    test('getCachedBundlePath returns null for uncached bundle', () async {
      await cacheManager.initialize();
      
      final path = await cacheManager.getCachedBundlePath('nonexistent.bundle');
      
      expect(path, isNull);
    });
    
    test('removeBundle deletes cached bundle', () async {
      await cacheManager.initialize();
      final testData = [1, 2, 3, 4, 5];
      const bundleName = 'test.bundle';
      
      await cacheManager.cacheBundle(bundleName, testData);
      expect(await cacheManager.isCached(bundleName), isTrue);
      
      await cacheManager.removeBundle(bundleName);
      expect(await cacheManager.isCached(bundleName), isFalse);
    });
    
    test('clearCache removes all bundles', () async {
      await cacheManager.initialize();
      
      await cacheManager.cacheBundle('bundle1', [1, 2, 3]);
      await cacheManager.cacheBundle('bundle2', [4, 5, 6]);
      
      expect(cacheManager.getCachedBundleNames().length, equals(2));
      
      await cacheManager.clearCache();
      
      expect(cacheManager.getCachedBundleNames().length, equals(0));
    });
    
    test('getCacheSize returns correct size', () async {
      await cacheManager.initialize();
      final testData = List.generate(1000, (i) => i % 256);
      
      await cacheManager.cacheBundle('test.bundle', testData);
      final size = await cacheManager.getCacheSize();
      
      // Size should be at least the data size (plus some overhead for manifest)
      expect(size, greaterThanOrEqualTo(testData.length));
    });
    
    test('isCachedWithHash verifies hash', () async {
      await cacheManager.initialize();
      final testData = [1, 2, 3, 4, 5];
      const bundleName = 'test.bundle';
      const correctHash = '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0';
      
      await cacheManager.cacheBundle(bundleName, testData, sha256Hash: correctHash);
      
      expect(await cacheManager.isCachedWithHash(bundleName, correctHash), isTrue);
      expect(await cacheManager.isCachedWithHash(bundleName, 'wronghash'), isFalse);
    });
    
    test('getCacheEntry returns entry for cached bundle', () async {
      await cacheManager.initialize();
      final testData = [1, 2, 3, 4, 5];
      const bundleName = 'test.bundle';
      
      await cacheManager.cacheBundle(bundleName, testData);
      final entry = cacheManager.getCacheEntry(bundleName);
      
      expect(entry, isNotNull);
      expect(entry!.name, equals(bundleName));
      expect(entry.sizeBytes, equals(testData.length));
    });
  });
}
