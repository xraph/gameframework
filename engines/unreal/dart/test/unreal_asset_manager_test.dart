import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_unreal/src/unreal_asset_manager.dart';

/// Unit tests for UnrealAssetManager data classes.
/// Note: Full UnrealAssetManager tests require platform channel mocking
/// and are done in widget/integration tests.
void main() {
  group('AssetLoadState', () {
    test('has all required states', () {
      expect(AssetLoadState.values, contains(AssetLoadState.notLoaded));
      expect(AssetLoadState.values, contains(AssetLoadState.loading));
      expect(AssetLoadState.values, contains(AssetLoadState.loaded));
      expect(AssetLoadState.values, contains(AssetLoadState.failed));
    });

    test('enum values are distinct', () {
      expect(AssetLoadState.notLoaded, isNot(equals(AssetLoadState.loading)));
      expect(AssetLoadState.loading, isNot(equals(AssetLoadState.loaded)));
      expect(AssetLoadState.loaded, isNot(equals(AssetLoadState.failed)));
    });
  });

  group('LoadedAssetInfo', () {
    test('creates with required fields', () {
      final info = LoadedAssetInfo(
        path: '/Game/Textures/MyTexture',
        assetType: 'Texture2D',
        state: AssetLoadState.loaded,
      );

      expect(info.path, equals('/Game/Textures/MyTexture'));
      expect(info.assetType, equals('Texture2D'));
      expect(info.state, equals(AssetLoadState.loaded));
      expect(info.loadedAt, isNotNull);
      expect(info.metadata, isEmpty);
    });

    test('creates with optional fields', () {
      final loadTime = DateTime.now();
      final info = LoadedAssetInfo(
        path: '/Game/Meshes/Hero',
        assetType: 'StaticMesh',
        state: AssetLoadState.loaded,
        sizeBytes: 4096,
        loadedAt: loadTime,
        metadata: {'customField': 'value'},
      );

      expect(info.path, equals('/Game/Meshes/Hero'));
      expect(info.sizeBytes, equals(4096));
      expect(info.loadedAt, equals(loadTime));
      expect(info.metadata['customField'], equals('value'));
    });

    test('handles null sizeBytes', () {
      final info = LoadedAssetInfo(
        path: '/Game/Asset',
        assetType: 'Asset',
        state: AssetLoadState.loading,
      );

      expect(info.sizeBytes, isNull);
    });

    test('has correct state for different scenarios', () {
      final loadingInfo = LoadedAssetInfo(
        path: '/Game/Loading',
        assetType: 'Asset',
        state: AssetLoadState.loading,
      );
      expect(loadingInfo.state, equals(AssetLoadState.loading));

      final loadedInfo = LoadedAssetInfo(
        path: '/Game/Loaded',
        assetType: 'Asset',
        state: AssetLoadState.loaded,
        sizeBytes: 1024,
      );
      expect(loadedInfo.state, equals(AssetLoadState.loaded));

      final failedInfo = LoadedAssetInfo(
        path: '/Game/Failed',
        assetType: 'Asset',
        state: AssetLoadState.failed,
      );
      expect(failedInfo.state, equals(AssetLoadState.failed));
    });

    test('metadata is modifiable', () {
      final info = LoadedAssetInfo(
        path: '/Game/Asset',
        assetType: 'Asset',
        state: AssetLoadState.loaded,
        metadata: {'key1': 'value1'},
      );

      // Metadata can be accessed
      expect(info.metadata['key1'], equals('value1'));
    });

    test('default loadedAt is current time', () {
      final beforeCreate = DateTime.now();
      final info = LoadedAssetInfo(
        path: '/Game/Asset',
        assetType: 'Asset',
        state: AssetLoadState.loaded,
      );
      final afterCreate = DateTime.now();

      expect(
        info.loadedAt
            .isAfter(beforeCreate.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        info.loadedAt.isBefore(afterCreate.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
