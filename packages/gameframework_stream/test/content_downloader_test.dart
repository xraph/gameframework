import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_stream/gameframework_stream.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadProgress', () {
    test('percentage returns 0 when totalBytes is 0', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 0,
        totalBytes: 0,
        state: DownloadState.queued,
      );

      expect(progress.percentage, equals(0.0));
    });

    test('percentage returns 1 when completed with 0 total', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 0,
        totalBytes: 0,
        state: DownloadState.completed,
      );

      expect(progress.percentage, equals(1.0));
    });

    test('percentage calculates correctly', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 250,
        totalBytes: 1000,
        state: DownloadState.downloading,
      );

      expect(progress.percentage, equals(0.25));
    });

    test('percentageString formats correctly', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 333,
        totalBytes: 1000,
        state: DownloadState.downloading,
      );

      expect(progress.percentageString, equals('33%'));
    });

    test('isComplete returns true for completed state', () {
      expect(
        DownloadProgress.completed('test', 1000).isComplete,
        isTrue,
      );
    });

    test('isComplete returns true for cached state', () {
      expect(
        DownloadProgress.cached('test').isComplete,
        isTrue,
      );
    });

    test('isComplete returns false for downloading state', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
      );

      expect(progress.isComplete, isFalse);
    });

    test('isFailed returns true for failed state', () {
      expect(
        DownloadProgress.failed('test', 'error').isFailed,
        isTrue,
      );
    });

    test('isInProgress returns true for downloading state', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
      );

      expect(progress.isInProgress, isTrue);
    });

    test('downloadedSizeString formats bytes correctly', () {
      expect(
        DownloadProgress(
          bundleName: 'test',
          downloadedBytes: 500,
          totalBytes: 1000,
          state: DownloadState.downloading,
        ).downloadedSizeString,
        equals('500 B'),
      );

      expect(
        DownloadProgress(
          bundleName: 'test',
          downloadedBytes: 1536,
          totalBytes: 2048,
          state: DownloadState.downloading,
        ).downloadedSizeString,
        equals('1.5 KB'),
      );

      expect(
        DownloadProgress(
          bundleName: 'test',
          downloadedBytes: 5242880,
          totalBytes: 10485760,
          state: DownloadState.downloading,
        ).downloadedSizeString,
        equals('5.0 MB'),
      );
    });

    test('speedString returns null when bytesPerSecond is null', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
      );

      expect(progress.speedString, isNull);
    });

    test('speedString formats correctly', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
        bytesPerSecond: 1048576, // 1 MB/s
      );

      expect(progress.speedString, equals('1.0 MB/s'));
    });

    test('etaString returns null when estimatedSecondsRemaining is null', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
      );

      expect(progress.etaString, isNull);
    });

    test('etaString formats seconds correctly', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
        estimatedSecondsRemaining: 45,
      );

      expect(progress.etaString, equals('45s'));
    });

    test('etaString formats minutes correctly', () {
      final progress = DownloadProgress(
        bundleName: 'test',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
        estimatedSecondsRemaining: 125, // 2m 5s
      );

      expect(progress.etaString, equals('2m 5s'));
    });

    test('toString returns meaningful string', () {
      final progress = DownloadProgress(
        bundleName: 'level1.bundle',
        downloadedBytes: 500,
        totalBytes: 1000,
        state: DownloadState.downloading,
      );

      final str = progress.toString();
      expect(str, contains('level1.bundle'));
      expect(str, contains('downloading'));
      expect(str, contains('50%'));
    });
  });

  group('DownloadState', () {
    test('all states are defined', () {
      expect(DownloadState.queued, isNotNull);
      expect(DownloadState.downloading, isNotNull);
      expect(DownloadState.paused, isNotNull);
      expect(DownloadState.completed, isNotNull);
      expect(DownloadState.cached, isNotNull);
      expect(DownloadState.failed, isNotNull);
      expect(DownloadState.cancelled, isNotNull);
    });
  });
}
