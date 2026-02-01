import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_stream/gameframework_stream.dart';

void main() {
  group('ContentBundle', () {
    test('fromJson parses correctly', () {
      final json = {
        'name': 'level1.bundle',
        'url': 'https://cdn.example.com/level1.bundle',
        'sizeBytes': 1048576,
        'sha256': 'abc123',
        'isBase': false,
        'dependencies': ['base.bundle'],
        'group': 'Level1',
      };

      final bundle = ContentBundle.fromJson(json);

      expect(bundle.name, equals('level1.bundle'));
      expect(bundle.url, equals('https://cdn.example.com/level1.bundle'));
      expect(bundle.sizeBytes, equals(1048576));
      expect(bundle.sha256, equals('abc123'));
      expect(bundle.isBase, isFalse);
      expect(bundle.dependencies, contains('base.bundle'));
      expect(bundle.group, equals('Level1'));
    });

    test('toJson roundtrips correctly', () {
      final bundle = ContentBundle(
        name: 'test.bundle',
        url: 'https://example.com/test.bundle',
        sizeBytes: 500000,
        sha256: 'def456',
        isBase: true,
        dependencies: [],
      );

      final json = bundle.toJson();
      final restored = ContentBundle.fromJson(json);

      expect(restored.name, equals(bundle.name));
      expect(restored.url, equals(bundle.url));
      expect(restored.sizeBytes, equals(bundle.sizeBytes));
      expect(restored.sha256, equals(bundle.sha256));
      expect(restored.isBase, equals(bundle.isBase));
    });

    test('formattedSize returns human-readable size', () {
      expect(
        ContentBundle(
          name: 'a', url: '', sizeBytes: 500, sha256: '', isBase: false,
        ).formattedSize,
        equals('500 B'),
      );
      
      expect(
        ContentBundle(
          name: 'a', url: '', sizeBytes: 1536, sha256: '', isBase: false,
        ).formattedSize,
        equals('1.5 KB'),
      );
      
      expect(
        ContentBundle(
          name: 'a', url: '', sizeBytes: 5242880, sha256: '', isBase: false,
        ).formattedSize,
        equals('5.0 MB'),
      );
    });
  });

  group('ContentManifest', () {
    test('fromJson parses correctly', () {
      final json = {
        'version': '1.0.0',
        'baseUrl': 'https://cdn.example.com',
        'bundles': [
          {'name': 'base.bundle', 'url': 'url1', 'sizeBytes': 1000, 'sha256': 'a', 'isBase': true},
          {'name': 'level1.bundle', 'url': 'url2', 'sizeBytes': 2000, 'sha256': 'b', 'isBase': false},
        ],
        'buildTime': '2024-01-15T10:30:00Z',
        'platform': 'Android',
      };

      final manifest = ContentManifest.fromJson(json);

      expect(manifest.version, equals('1.0.0'));
      expect(manifest.baseUrl, equals('https://cdn.example.com'));
      expect(manifest.bundles.length, equals(2));
      expect(manifest.platform, equals('Android'));
    });

    test('baseBundles filters correctly', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(name: 'base', url: 'u1', sizeBytes: 100, sha256: 'a', isBase: true),
          ContentBundle(name: 'streaming', url: 'u2', sizeBytes: 200, sha256: 'b', isBase: false),
        ],
      );

      expect(manifest.baseBundles.length, equals(1));
      expect(manifest.baseBundles.first.name, equals('base'));
    });

    test('streamingBundles filters correctly', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(name: 'base', url: 'u1', sizeBytes: 100, sha256: 'a', isBase: true),
          ContentBundle(name: 'streaming', url: 'u2', sizeBytes: 200, sha256: 'b', isBase: false),
        ],
      );

      expect(manifest.streamingBundles.length, equals(1));
      expect(manifest.streamingBundles.first.name, equals('streaming'));
    });

    test('totalSize calculates correctly', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(name: 'a', url: 'u1', sizeBytes: 100, sha256: 'a', isBase: true),
          ContentBundle(name: 'b', url: 'u2', sizeBytes: 200, sha256: 'b', isBase: false),
          ContentBundle(name: 'c', url: 'u3', sizeBytes: 300, sha256: 'c', isBase: false),
        ],
      );

      expect(manifest.totalSize, equals(600));
      expect(manifest.baseSize, equals(100));
      expect(manifest.streamingSize, equals(500));
    });

    test('getBundleByName finds bundle', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(name: 'target', url: 'u1', sizeBytes: 100, sha256: 'a', isBase: true),
        ],
      );

      expect(manifest.getBundleByName('target')?.name, equals('target'));
      expect(manifest.getBundleByName('nonexistent'), isNull);
    });

    test('resolveDependencies resolves correctly', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(name: 'base', url: 'u1', sizeBytes: 100, sha256: 'a', isBase: true, dependencies: []),
          ContentBundle(name: 'level1', url: 'u2', sizeBytes: 200, sha256: 'b', isBase: false, dependencies: ['base']),
          ContentBundle(name: 'level2', url: 'u3', sizeBytes: 300, sha256: 'c', isBase: false, dependencies: ['level1']),
        ],
      );

      final deps = manifest.resolveDependencies('level2');
      
      expect(deps.length, equals(3));
      expect(deps[0].name, equals('base'));
      expect(deps[1].name, equals('level1'));
      expect(deps[2].name, equals('level2'));
    });
  });

  group('DownloadProgress', () {
    test('percentage calculates correctly', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 50,
        totalBytes: 100,
        state: DownloadState.downloading,
      );

      expect(progress.percentage, equals(0.5));
      expect(progress.percentageString, equals('50%'));
    });

    test('completed factory creates correct state', () {
      final progress = DownloadProgress.completed('test', 1000);

      expect(progress.state, equals(DownloadState.completed));
      expect(progress.isComplete, isTrue);
      expect(progress.percentage, equals(1.0));
    });

    test('failed factory creates correct state', () {
      final progress = DownloadProgress.failed('test', 'Network error');

      expect(progress.state, equals(DownloadState.failed));
      expect(progress.isFailed, isTrue);
      expect(progress.error, equals('Network error'));
    });

    test('cached factory creates correct state', () {
      final progress = DownloadProgress.cached('test');

      expect(progress.state, equals(DownloadState.cached));
      expect(progress.isComplete, isTrue);
    });
  });

  group('DownloadStrategy', () {
    test('allowsCellular is correct', () {
      expect(DownloadStrategy.wifiOnly.allowsCellular, isFalse);
      expect(DownloadStrategy.wifiOrCellular.allowsCellular, isTrue);
      expect(DownloadStrategy.any.allowsCellular, isTrue);
      expect(DownloadStrategy.manual.allowsCellular, isTrue);
    });

    test('allowsAutoDownload is correct', () {
      expect(DownloadStrategy.wifiOnly.allowsAutoDownload, isTrue);
      expect(DownloadStrategy.wifiOrCellular.allowsAutoDownload, isTrue);
      expect(DownloadStrategy.any.allowsAutoDownload, isTrue);
      expect(DownloadStrategy.manual.allowsAutoDownload, isFalse);
    });
  });
}
