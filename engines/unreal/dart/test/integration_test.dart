import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_unreal/src/unreal_binary_protocol.dart';
import 'package:gameframework_unreal/src/unreal_delta_compressor.dart';

/// Integration tests for end-to-end messaging flows.
/// Note: Tests that require UnrealController/MethodChannel are in widget tests.
void main() {
  group('Binary Protocol Integration', () {
    late UnrealBinaryProtocol protocol;

    setUp(() {
      protocol = UnrealBinaryProtocol();
    });

    test('encode and decode roundtrip', () {
      final originalData = Uint8List.fromList(List.generate(100, (i) => i));

      // Encode
      final encoded = protocol.encode(originalData);
      expect(encoded, isNotEmpty);

      // Decode
      final decoded = protocol.decode(encoded);
      expect(decoded, equals(originalData));
    });

    test('compress and decompress roundtrip', () {
      // Create compressible data (repeated patterns compress well)
      final originalData = Uint8List.fromList(
        List.generate(10000, (i) => i % 256),
      );

      // Compress
      final compressed = protocol.compressData(originalData);
      expect(compressed.length, lessThan(originalData.length));

      // Decompress
      final decompressed = protocol.decompressData(compressed);
      expect(decompressed, equals(originalData));
    });

    test('encodeWithMetadata auto-compresses large data', () {
      // Large compressible data
      final largeData = Uint8List.fromList(
        List.generate(5000, (i) => i % 50), // Repetitive = compressible
      );

      final envelope = protocol.encodeWithMetadata(largeData);

      expect(envelope.isCompressed, isTrue);
      expect(envelope.originalSize, equals(largeData.length));
      expect(envelope.compressedSize, lessThan(largeData.length));
    });

    test('encodeWithMetadata skips compression for small data', () {
      final smallData = Uint8List.fromList([1, 2, 3, 4, 5]);

      final envelope = protocol.encodeWithMetadata(smallData);

      expect(envelope.isCompressed, isFalse);
    });

    test('createAssembler creates valid assembler', () {
      final assembler = protocol.createAssembler();
      expect(assembler, isNotNull);
    });

    test('verifyChecksum validates correctly', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

      // Get checksum via encodeWithMetadata
      final envelope = protocol.encodeWithMetadata(data, compress: false);

      // Verify with correct checksum
      expect(protocol.verifyChecksum(data, envelope.checksum), isTrue);

      // Verify with wrong checksum
      expect(protocol.verifyChecksum(data, 12345), isFalse);
    });
  });

  group('Delta Compression Integration', () {
    late UnrealDeltaCompressor compressor;

    setUp(() {
      compressor = UnrealDeltaCompressor();
    });

    tearDown(() {
      compressor.clearAllHistory();
    });

    test('delta computation reduces data size', () {
      // Large state with small change
      final largeState = Map<String, dynamic>.fromIterable(
        List.generate(50, (i) => 'key$i'),
        value: (k) => 0,
      );

      final changedState = Map<String, dynamic>.from(largeState);
      changedState['key0'] = 1; // Single change

      final delta = compressor.computeDelta(changedState, largeState);

      // Delta should be much smaller than full state
      expect(delta.length, lessThan(5)); // Just the changed key
      expect(delta['key0'], equals(1));
    });

    test('computeDeltaWithHistory tracks state changes', () {
      // First call - establishes baseline
      final result1 = compressor.computeDeltaWithHistory('player', {
        'x': 0,
        'y': 0,
        'health': 100,
      });

      expect(result1.isDelta, isFalse); // First time, no delta possible

      // Second call - should compute delta
      final result2 = compressor.computeDeltaWithHistory('player', {
        'x': 10,
        'y': 0,
        'health': 100,
      });

      // Should contain only changed value
      expect(result2.data.containsKey('x'), isTrue);
      expect(result2.data['x'], equals(10));
    });

    test('delta roundtrip preserves state', () {
      final oldState = {
        'position': {'x': 0, 'y': 0},
        'velocity': {'dx': 1, 'dy': 2},
        'health': 100,
      };

      final newState = {
        'position': {'x': 10, 'y': 5},
        'velocity': {'dx': 1, 'dy': 2},
        'health': 95,
      };

      // Compute delta
      final delta = compressor.computeDelta(newState, oldState);

      // Apply delta to old state
      final reconstructed = compressor.applyDelta(oldState, delta);

      // Should equal new state
      expect(reconstructed['position']['x'], equals(10));
      expect(reconstructed['position']['y'], equals(5));
      expect(reconstructed['health'], equals(95));
      // Unchanged values preserved
      expect(reconstructed['velocity']['dx'], equals(1));
    });

    test('handles removed keys correctly', () {
      final oldState = {'a': 1, 'b': 2, 'c': 3};
      final newState = {'a': 1, 'c': 3}; // 'b' removed

      final delta = compressor.computeDelta(newState, oldState);

      expect(delta['_removed'], contains('b'));

      // Apply delta
      final result = compressor.applyDelta(oldState, delta);
      expect(result.containsKey('b'), isFalse);
      expect(result['a'], equals(1));
      expect(result['c'], equals(3));
    });

    test('statistics track operations', () {
      compressor.computeDelta({'a': 1}, {'a': 0});
      compressor.computeDelta({'b': 2}, {'b': 2}); // No change
      compressor.applyDelta({'x': 0}, {'x': 1});

      final stats = compressor.statistics;

      expect(stats.deltasComputed, equals(2));
      expect(stats.deltasApplied, equals(1));
    });
  });

  group('Combined Protocol and Compression', () {
    test('binary data can be compressed, encoded, and decoded', () {
      final protocol = UnrealBinaryProtocol();

      // Original binary data
      final originalData = Uint8List.fromList(
        List.generate(5000, (i) => i % 100), // Compressible pattern
      );

      // Compress
      final compressed = protocol.compressData(originalData);

      // Encode to base64
      final encoded = protocol.encode(compressed);

      // Decode from base64
      final decodedCompressed = protocol.decode(encoded);

      // Decompress
      final decompressed = protocol.decompressData(decodedCompressed);

      // Should match original
      expect(decompressed, equals(originalData));
    });

    test('state updates can be delta-compressed then encoded', () {
      final protocol = UnrealBinaryProtocol();
      final compressor = UnrealDeltaCompressor();

      final oldState = {'x': 0, 'y': 0, 'z': 0};
      final newState = {'x': 100, 'y': 0, 'z': 50};

      // Compute delta
      final delta = compressor.computeDelta(newState, oldState);

      // Convert to binary (JSON string bytes)
      final deltaBytes = Uint8List.fromList(delta.toString().codeUnits);

      // Encode
      final encoded = protocol.encode(deltaBytes);

      // This encoded string would be sent over the bridge
      expect(encoded, isNotEmpty);

      // Decode on the other side
      final decoded = protocol.decode(encoded);
      expect(decoded, equals(deltaBytes));
    });
  });

  group('Performance Characteristics', () {
    test('delta compression reduces data for repeated updates', () {
      final compressor = UnrealDeltaCompressor();
      var totalFullSize = 0;
      var totalDeltaSize = 0;

      // Base state with many fields
      final baseState = Map<String, dynamic>.fromIterable(
        List.generate(50, (i) => 'key$i'),
        value: (k) => 0,
      );

      // Store initial state
      compressor.computeDeltaWithHistory('test', baseState);

      // Simulate 100 updates with small changes
      for (var i = 0; i < 100; i++) {
        final newState = Map<String, dynamic>.from(baseState);
        newState['key${i % 50}'] = i; // Change one key

        totalFullSize += newState.toString().length;

        final result = compressor.computeDeltaWithHistory('test', newState);
        totalDeltaSize += result.data.toString().length;
      }

      // Delta should be significantly smaller
      expect(totalDeltaSize, lessThan(totalFullSize ~/ 3));
    });

    test('binary compression effective for repetitive data', () {
      final protocol = UnrealBinaryProtocol();

      // Highly repetitive data compresses well
      final repetitiveData = Uint8List.fromList(
        List.generate(10000, (i) => i % 10),
      );

      final compressed = protocol.compressData(repetitiveData);

      // Should achieve significant compression
      expect(compressed.length, lessThan(repetitiveData.length ~/ 5));
    });

    test('binary compression less effective for random data', () {
      final protocol = UnrealBinaryProtocol();

      // Random data doesn't compress as well
      final randomData = Uint8List.fromList(
        List.generate(1000, (i) => (i * 17 + 13) % 256),
      );

      final compressed = protocol.compressData(randomData);

      // Still compresses somewhat but not dramatically
      expect(compressed.length, lessThan(randomData.length * 1.5));
    });
  });
}
