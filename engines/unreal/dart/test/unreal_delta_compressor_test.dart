import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_unreal/src/unreal_delta_compressor.dart';

void main() {
  group('UnrealDeltaCompressor', () {
    late UnrealDeltaCompressor compressor;

    setUp(() {
      compressor = UnrealDeltaCompressor();
    });

    tearDown(() {
      compressor.clearAllHistory();
    });

    group('Delta computation', () {
      test('computes delta for simple objects', () {
        final oldState = {'x': 0, 'y': 0, 'z': 0};
        final newState = {'x': 10, 'y': 0, 'z': 5};

        final delta = compressor.computeDelta(newState, oldState);

        expect(delta['x'], equals(10));
        expect(delta['z'], equals(5));
        // Unchanged 'y' should not be in delta
        expect(delta.containsKey('y'), isFalse);
      });

      test('returns empty delta when no changes', () {
        final state = {'x': 10, 'y': 20};

        final delta = compressor.computeDelta(state, state);

        expect(delta, isEmpty);
      });

      test('handles nested objects', () {
        final oldState = {
          'position': {'x': 0, 'y': 0},
          'rotation': {'angle': 0}
        };
        final newState = {
          'position': {'x': 10, 'y': 0},
          'rotation': {'angle': 45}
        };

        final delta = compressor.computeDelta(newState, oldState);

        expect(delta.isNotEmpty, isTrue);
      });

      test('handles added keys', () {
        final oldState = {'x': 0};
        final newState = {'x': 0, 'y': 10};

        final delta = compressor.computeDelta(newState, oldState);

        expect(delta['y'], equals(10));
      });

      test('handles removed keys', () {
        final oldState = {'x': 0, 'y': 10};
        final newState = {'x': 0};

        final delta = compressor.computeDelta(newState, oldState);

        // Removed keys should be in _removed list
        expect(delta['_removed'], contains('y'));
      });
    });

    group('Delta application', () {
      test('applies delta to state', () {
        final baseState = {'x': 0, 'y': 0, 'z': 0};
        final delta = {'x': 10, 'z': 5};

        final result = compressor.applyDelta(baseState, delta);

        expect(result['x'], equals(10));
        expect(result['y'], equals(0)); // Unchanged
        expect(result['z'], equals(5));
      });

      test('applies delta with _removed marker', () {
        final baseState = {'x': 10, 'y': 20};
        final delta = {
          '_removed': ['y']
        };

        final result = compressor.applyDelta(baseState, delta);

        expect(result.containsKey('y'), isFalse);
        expect(result['x'], equals(10));
      });

      test('applies delta with _null marker', () {
        final baseState = {'x': 10, 'y': 20};
        final delta = {
          '_null': ['y']
        };

        final result = compressor.applyDelta(baseState, delta);

        expect(result['y'], isNull);
        expect(result['x'], equals(10));
      });

      test('applies delta with new keys', () {
        final baseState = {'x': 10};
        final delta = {'y': 20};

        final result = compressor.applyDelta(baseState, delta);

        expect(result['x'], equals(10));
        expect(result['y'], equals(20));
      });
    });

    group('State history', () {
      test('stores and retrieves state', () {
        final result = compressor.computeDeltaWithHistory('entity1', {'x': 0});

        expect(result.isDelta, isFalse); // First time, no previous state

        final stored = compressor.getStoredState('entity1');
        expect(stored, isNotNull);
        expect(stored!['x'], equals(0));
      });

      test('computes delta on subsequent calls', () {
        // First call - no previous state
        compressor.computeDeltaWithHistory('entity1', {'x': 0, 'y': 0});

        // Second call - should compute delta
        final result =
            compressor.computeDeltaWithHistory('entity1', {'x': 10, 'y': 0});

        // Delta should contain only changed value
        expect(result.data.containsKey('x'), isTrue);
      });

      test('clears history for entity', () {
        compressor.computeDeltaWithHistory('entity1', {'x': 0});
        compressor.computeDeltaWithHistory('entity2', {'y': 0});

        compressor.clearHistory('entity1');

        expect(compressor.getStoredState('entity1'), isNull);
        expect(compressor.getStoredState('entity2'), isNotNull);
      });

      test('clears all history', () {
        compressor.computeDeltaWithHistory('entity1', {'x': 0});
        compressor.computeDeltaWithHistory('entity2', {'y': 0});

        compressor.clearAllHistory();

        expect(compressor.getStoredState('entity1'), isNull);
        expect(compressor.getStoredState('entity2'), isNull);
      });
    });

    group('DeltaResult', () {
      test('calculates compression ratio', () {
        // First call to establish history
        compressor.computeDeltaWithHistory('test', {'a': 1, 'b': 2, 'c': 3});

        // Small change on larger state
        final result = compressor
            .computeDeltaWithHistory('test', {'a': 1, 'b': 5, 'c': 3});

        expect(result.originalSize, greaterThan(0));
        expect(result.resultSize, greaterThan(0));
      });

      test('returns full state when delta not beneficial', () {
        // Very small state where delta isn't beneficial
        final result = compressor.computeDeltaWithHistory('tiny', {'x': 1});

        expect(result.isDelta, isFalse);
        expect(result.data['x'], equals(1));
      });
    });

    group('Statistics', () {
      test('tracks compression statistics', () {
        compressor
            .computeDelta({'a': 1, 'b': 5, 'c': 3}, {'a': 1, 'b': 2, 'c': 3});
        compressor.computeDelta({'x': 1}, {'x': 1}); // No change

        final stats = compressor.statistics;

        expect(stats.deltasComputed, equals(2));
      });

      test('resets statistics', () {
        compressor.computeDelta({'a': 1}, {'a': 2});
        compressor.resetStatistics();

        final stats = compressor.statistics;
        expect(stats.deltasComputed, equals(0));
      });
    });

    group('Configuration', () {
      test('configures compressor', () {
        compressor.configure(
          maxHistorySize: 50,
          deepComparison: false,
          minimumSavingsRatio: 0.3,
        );

        // Configuration should be applied (internal state)
        expect(compressor.statistics.historyEntries, equals(0));
      });
    });

    group('Type handling', () {
      test('handles list values', () {
        final oldState = {
          'items': [1, 2, 3]
        };
        final newState = {
          'items': [1, 2, 3, 4]
        };

        final delta = compressor.computeDelta(newState, oldState);
        expect(delta.isNotEmpty, isTrue);
      });

      test('handles numeric type changes', () {
        final oldState = {'value': 10};
        final newState = {'value': 10.5};

        final delta = compressor.computeDelta(newState, oldState);
        expect(delta.isNotEmpty, isTrue);
      });

      test('handles boolean values', () {
        final oldState = {'active': true};
        final newState = {'active': false};

        final delta = compressor.computeDelta(newState, oldState);
        expect(delta['active'], isFalse);
      });
    });

    group('Utility methods', () {
      test('isDelta detects delta markers', () {
        expect(
            compressor.isDelta({
              '_removed': ['key']
            }),
            isTrue);
        expect(
            compressor.isDelta({
              '_null': ['key']
            }),
            isTrue);
        expect(compressor.isDelta({'_delta': true}), isTrue);
        expect(compressor.isDelta({'x': 1}), isFalse);
      });

      test('wrapAsDelta wraps data correctly', () {
        final delta = {'x': 10};
        final wrapped = compressor.wrapAsDelta(delta);

        expect(wrapped['_delta'], isTrue);
        expect(wrapped['_timestamp'], isNotNull);
        expect(wrapped['data'], equals(delta));
      });

      test('unwrapDelta unwraps data correctly', () {
        final delta = {'x': 10};
        final wrapped = compressor.wrapAsDelta(delta);
        final unwrapped = compressor.unwrapDelta(wrapped);

        expect(unwrapped, equals(delta));
      });
    });
  });
}
