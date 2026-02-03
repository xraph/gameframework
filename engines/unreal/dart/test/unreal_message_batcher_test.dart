import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_unreal/src/unreal_message_batcher.dart';

/// Unit tests for UnrealMessageBatcher data classes.
/// Note: Full UnrealMessageBatcher tests require UnrealController/platform channels
/// and are done in widget/integration tests.
void main() {
  group('BatcherStatistics', () {
    test('creates with default values', () {
      final stats = BatcherStatistics(
        messagesBatched: 0,
        batchesSent: 0,
        messagesCoalesced: 0,
        pendingCount: 0,
        bytesSent: 0,
      );

      expect(stats.messagesBatched, equals(0));
      expect(stats.batchesSent, equals(0));
      expect(stats.messagesCoalesced, equals(0));
      expect(stats.pendingCount, equals(0));
      expect(stats.bytesSent, equals(0));
    });

    test('creates with custom values', () {
      final stats = BatcherStatistics(
        messagesBatched: 100,
        batchesSent: 10,
        messagesCoalesced: 25,
        pendingCount: 5,
        bytesSent: 5000,
      );

      expect(stats.messagesBatched, equals(100));
      expect(stats.batchesSent, equals(10));
      expect(stats.messagesCoalesced, equals(25));
      expect(stats.pendingCount, equals(5));
      expect(stats.bytesSent, equals(5000));
    });

    test('calculates average messages per batch', () {
      final stats = BatcherStatistics(
        messagesBatched: 100,
        batchesSent: 10,
        messagesCoalesced: 0,
        pendingCount: 0,
        bytesSent: 0,
      );

      expect(stats.averageMessagesPerBatch, equals(10.0));
    });

    test('handles zero batches for average calculation', () {
      final stats = BatcherStatistics(
        messagesBatched: 0,
        batchesSent: 0,
        messagesCoalesced: 0,
        pendingCount: 0,
        bytesSent: 0,
      );

      expect(stats.averageMessagesPerBatch, equals(0.0));
    });

    test('calculates coalescing efficiency', () {
      final stats = BatcherStatistics(
        messagesBatched: 100,
        batchesSent: 10,
        messagesCoalesced: 50,
        pendingCount: 0,
        bytesSent: 0,
      );

      expect(stats.coalescingEfficiency, equals(0.5));
    });

    test('handles zero messages for coalescing efficiency', () {
      final stats = BatcherStatistics(
        messagesBatched: 0,
        batchesSent: 0,
        messagesCoalesced: 0,
        pendingCount: 0,
        bytesSent: 0,
      );

      expect(stats.coalescingEfficiency, equals(0.0));
    });

    test('toString provides readable output', () {
      final stats = BatcherStatistics(
        messagesBatched: 50,
        batchesSent: 5,
        messagesCoalesced: 10,
        pendingCount: 2,
        bytesSent: 1024,
      );

      final str = stats.toString();

      expect(str, contains('Batched=50'));
      expect(str, contains('Sent=5'));
      expect(str, contains('Coalesced=10'));
      expect(str, contains('Pending=2'));
      expect(str, contains('Bytes=1024'));
      expect(str, contains('Avg/Batch=10.0'));
    });
  });
}
