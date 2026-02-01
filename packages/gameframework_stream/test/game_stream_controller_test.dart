import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_stream/gameframework_stream.dart';
import 'package:gameframework_stream/src/game_stream_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreamingState', () {
    test('all states are defined', () {
      expect(StreamingState.uninitialized, isNotNull);
      expect(StreamingState.initializing, isNotNull);
      expect(StreamingState.ready, isNotNull);
      expect(StreamingState.downloading, isNotNull);
      expect(StreamingState.error, isNotNull);
    });
  });

  group('StreamingErrorType', () {
    test('all error types are defined', () {
      expect(StreamingErrorType.notInitialized, isNotNull);
      expect(StreamingErrorType.initializationFailed, isNotNull);
      expect(StreamingErrorType.manifestFetchFailed, isNotNull);
      expect(StreamingErrorType.bundleNotFound, isNotNull);
      expect(StreamingErrorType.downloadFailed, isNotNull);
      expect(StreamingErrorType.networkUnavailable, isNotNull);
      expect(StreamingErrorType.cacheError, isNotNull);
    });
  });

  group('StreamingError', () {
    test('creates with required fields', () {
      final error = StreamingError(
        type: StreamingErrorType.downloadFailed,
        message: 'Download failed',
      );

      expect(error.type, equals(StreamingErrorType.downloadFailed));
      expect(error.message, equals('Download failed'));
      expect(error.cause, isNull);
    });

    test('creates with cause', () {
      final cause = Exception('Network error');
      final error = StreamingError(
        type: StreamingErrorType.downloadFailed,
        message: 'Download failed',
        cause: cause,
      );

      expect(error.cause, equals(cause));
    });

    test('toString returns meaningful string', () {
      final error = StreamingError(
        type: StreamingErrorType.manifestFetchFailed,
        message: 'Could not fetch manifest',
      );

      final str = error.toString();
      expect(str, contains('StreamingError'));
      expect(str, contains('manifestFetchFailed'));
      expect(str, contains('Could not fetch manifest'));
    });

    test('implements Exception', () {
      final error = StreamingError(
        type: StreamingErrorType.notInitialized,
        message: 'Not initialized',
      );

      expect(error, isA<Exception>());
    });
  });

  group('ContentBundle advanced tests', () {
    test('equality compares by name and sha256', () {
      final bundle1 = ContentBundle(
        name: 'test.bundle',
        url: 'url1',
        sizeBytes: 100,
        sha256: 'hash123',
        isBase: false,
      );

      final bundle2 = ContentBundle(
        name: 'test.bundle',
        url: 'url2',
        sizeBytes: 200,
        sha256: 'hash123',
        isBase: true,
      );

      final bundle3 = ContentBundle(
        name: 'test.bundle',
        url: 'url1',
        sizeBytes: 100,
        sha256: 'different',
        isBase: false,
      );

      expect(bundle1, equals(bundle2)); // Same name and hash
      expect(bundle1, isNot(equals(bundle3))); // Different hash
    });

    test('hashCode is consistent with equality', () {
      final bundle1 = ContentBundle(
        name: 'test.bundle',
        url: 'url1',
        sizeBytes: 100,
        sha256: 'hash123',
        isBase: false,
      );

      final bundle2 = ContentBundle(
        name: 'test.bundle',
        url: 'url2',
        sizeBytes: 200,
        sha256: 'hash123',
        isBase: true,
      );

      expect(bundle1.hashCode, equals(bundle2.hashCode));
    });

    test('toString returns meaningful string', () {
      final bundle = ContentBundle(
        name: 'level1.bundle',
        url: 'https://example.com/level1.bundle',
        sizeBytes: 5242880, // 5 MB
        sha256: 'abc123',
        isBase: false,
      );

      final str = bundle.toString();
      expect(str, contains('level1.bundle'));
      expect(str, contains('5.0 MB'));
      expect(str, contains('false'));
    });
  });

  group('ContentManifest advanced tests', () {
    test('groups returns unique groups', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(
            name: 'a',
            url: 'u1',
            sizeBytes: 100,
            sha256: 'a',
            isBase: true,
            group: 'Base',
          ),
          ContentBundle(
            name: 'b',
            url: 'u2',
            sizeBytes: 200,
            sha256: 'b',
            isBase: false,
            group: 'Level1',
          ),
          ContentBundle(
            name: 'c',
            url: 'u3',
            sizeBytes: 300,
            sha256: 'c',
            isBase: false,
            group: 'Level1',
          ),
          ContentBundle(
            name: 'd',
            url: 'u4',
            sizeBytes: 400,
            sha256: 'd',
            isBase: false,
            group: 'Characters',
          ),
        ],
      );

      final groups = manifest.groups;
      expect(groups.length, equals(3));
      expect(groups, contains('Base'));
      expect(groups, contains('Level1'));
      expect(groups, contains('Characters'));
    });

    test('getBundlesByGroup filters correctly', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(
            name: 'a',
            url: 'u1',
            sizeBytes: 100,
            sha256: 'a',
            isBase: true,
            group: 'Level1',
          ),
          ContentBundle(
            name: 'b',
            url: 'u2',
            sizeBytes: 200,
            sha256: 'b',
            isBase: false,
            group: 'Level1',
          ),
          ContentBundle(
            name: 'c',
            url: 'u3',
            sizeBytes: 300,
            sha256: 'c',
            isBase: false,
            group: 'Level2',
          ),
        ],
      );

      final level1Bundles = manifest.getBundlesByGroup('Level1');
      expect(level1Bundles.length, equals(2));
      expect(level1Bundles.every((b) => b.group == 'Level1'), isTrue);
    });

    test('formattedTotalSize returns human-readable size', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(
            name: 'a',
            url: 'u1',
            sizeBytes: 5242880,
            sha256: 'a',
            isBase: true,
          ),
          ContentBundle(
            name: 'b',
            url: 'u2',
            sizeBytes: 10485760,
            sha256: 'b',
            isBase: false,
          ),
        ],
      );

      expect(manifest.formattedTotalSize, equals('15.0 MB'));
      expect(manifest.formattedBaseSize, equals('5.0 MB'));
      expect(manifest.formattedStreamingSize, equals('10.0 MB'));
    });

    test('bundleCount returns correct count', () {
      final manifest = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(
              name: 'a', url: 'u1', sizeBytes: 100, sha256: 'a', isBase: true),
          ContentBundle(
              name: 'b', url: 'u2', sizeBytes: 200, sha256: 'b', isBase: false),
          ContentBundle(
              name: 'c', url: 'u3', sizeBytes: 300, sha256: 'c', isBase: false),
        ],
      );

      expect(manifest.bundleCount, equals(3));
    });

    test('toJson roundtrips correctly', () {
      final original = ContentManifest(
        version: '1.0.0',
        baseUrl: 'https://example.com',
        platform: 'Android',
        bundles: [
          ContentBundle(
            name: 'test',
            url: 'url',
            sizeBytes: 100,
            sha256: 'hash',
            isBase: true,
          ),
        ],
      );

      final json = original.toJson();
      final restored = ContentManifest.fromJson(json);

      expect(restored.version, equals(original.version));
      expect(restored.baseUrl, equals(original.baseUrl));
      expect(restored.platform, equals(original.platform));
      expect(restored.bundles.length, equals(original.bundles.length));
    });

    test('toString returns meaningful string', () {
      final manifest = ContentManifest(
        version: '2.0.0',
        baseUrl: 'https://example.com',
        bundles: [
          ContentBundle(
              name: 'a',
              url: 'u1',
              sizeBytes: 1048576,
              sha256: 'a',
              isBase: true),
        ],
      );

      final str = manifest.toString();
      expect(str, contains('2.0.0'));
      expect(str, contains('1'));
      expect(str, contains('1.0 MB'));
    });
  });
}
