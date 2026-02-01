import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'cache_manager.dart';
import 'models/content_bundle.dart';
import 'models/download_progress.dart';
import 'models/download_strategy.dart';

/// Downloads and manages streaming content bundles
class ContentDownloader {
  final CacheManager cacheManager;
  final http.Client _httpClient;
  final Duration timeout;
  final int maxRetries;

  /// Currently active downloads
  final Map<String, _ActiveDownload> _activeDownloads = {};

  ContentDownloader({
    required this.cacheManager,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
    this.maxRetries = 3,
  }) : _httpClient = httpClient ?? http.Client();

  /// Download a bundle with progress reporting
  Stream<DownloadProgress> downloadBundle(ContentBundle bundle) async* {
    // Check if already cached
    if (await cacheManager.isCachedWithHash(bundle.name, bundle.sha256)) {
      yield DownloadProgress.cached(bundle.name);
      return;
    }

    // Check if already downloading
    if (_activeDownloads.containsKey(bundle.name)) {
      yield* _activeDownloads[bundle.name]!.progressStream;
      return;
    }

    // Start download
    final download = _ActiveDownload(bundle.name);
    _activeDownloads[bundle.name] = download;

    try {
      yield* _downloadWithRetry(bundle, download);
    } finally {
      _activeDownloads.remove(bundle.name);
      download.close();
    }
  }

  /// Download multiple bundles
  Stream<DownloadProgress> downloadBundles(
    List<ContentBundle> bundles,
    DownloadStrategy strategy, {
    int concurrency = 3,
  }) async* {
    // Check network connectivity
    if (!await _checkConnectivity(strategy)) {
      for (final bundle in bundles) {
        yield DownloadProgress.failed(
          bundle.name,
          'Network not available for selected download strategy',
        );
      }
      return;
    }

    // Download in batches
    for (var i = 0; i < bundles.length; i += concurrency) {
      final batch = bundles.skip(i).take(concurrency).toList();
      final streams = batch.map((b) => downloadBundle(b));

      // Merge streams from concurrent downloads
      await for (final progress in _mergeStreams(streams)) {
        yield progress;
      }
    }
  }

  /// Check if network is available for the given strategy
  Future<bool> _checkConnectivity(DownloadStrategy strategy) async {
    if (strategy == DownloadStrategy.any) return true;

    final connectivity = await Connectivity().checkConnectivity();
    
    if (connectivity.contains(ConnectivityResult.wifi)) {
      return true;
    }

    if (strategy.allowsCellular && 
        (connectivity.contains(ConnectivityResult.mobile) ||
         connectivity.contains(ConnectivityResult.ethernet))) {
      return true;
    }

    return false;
  }

  /// Download with retry logic
  Stream<DownloadProgress> _downloadWithRetry(
    ContentBundle bundle,
    _ActiveDownload download,
  ) async* {
    var retryCount = 0;
    Exception? lastError;

    while (retryCount <= maxRetries) {
      try {
        yield* _performDownload(bundle, download);
        return; // Success
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        retryCount++;

        if (retryCount <= maxRetries) {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(seconds: retryCount * 2));
          download.addProgress(DownloadProgress(
            bundleName: bundle.name,
            downloadedBytes: 0,
            totalBytes: bundle.sizeBytes,
            state: DownloadState.queued,
            error: 'Retrying... ($retryCount/$maxRetries)',
          ));
        }
      }
    }

    yield DownloadProgress.failed(
      bundle.name,
      'Download failed after $maxRetries retries: $lastError',
    );
  }

  /// Perform the actual download
  Stream<DownloadProgress> _performDownload(
    ContentBundle bundle,
    _ActiveDownload download,
  ) async* {
    // Start request
    final request = http.Request('GET', Uri.parse(bundle.url));
    final response = await _httpClient.send(request).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    // Get content length
    final totalBytes = response.contentLength ?? bundle.sizeBytes;
    var downloadedBytes = 0;
    final chunks = <List<int>>[];
    final stopwatch = Stopwatch()..start();

    yield DownloadProgress.starting(bundle.name, totalBytes);

    // Download with progress
    await for (final chunk in response.stream) {
      chunks.add(chunk);
      downloadedBytes += chunk.length;

      // Calculate speed
      final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
      final bytesPerSecond =
          elapsedSeconds > 0 ? (downloadedBytes / elapsedSeconds).round() : 0;
      final remainingBytes = totalBytes - downloadedBytes;
      final eta = bytesPerSecond > 0
          ? (remainingBytes / bytesPerSecond).round()
          : null;

      final progress = DownloadProgress(
        bundleName: bundle.name,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        state: DownloadState.downloading,
        bytesPerSecond: bytesPerSecond,
        estimatedSecondsRemaining: eta,
      );

      download.addProgress(progress);
      yield progress;
    }

    stopwatch.stop();

    // Combine chunks
    final allBytes = Uint8List(downloadedBytes);
    var offset = 0;
    for (final chunk in chunks) {
      allBytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    // Verify SHA256
    final computedHash = sha256.convert(allBytes).toString();
    if (computedHash != bundle.sha256) {
      throw Exception(
        'SHA256 mismatch: expected ${bundle.sha256}, got $computedHash',
      );
    }

    // Cache the bundle
    await cacheManager.cacheBundle(
      bundle.name,
      allBytes,
      sha256Hash: computedHash,
    );

    yield DownloadProgress.completed(bundle.name, totalBytes);
  }

  /// Merge multiple streams
  Stream<DownloadProgress> _mergeStreams(
    Iterable<Stream<DownloadProgress>> streams,
  ) async* {
    final controller = StreamController<DownloadProgress>();
    var activeCount = streams.length;

    for (final stream in streams) {
      stream.listen(
        (progress) => controller.add(progress),
        onError: (e) => controller.addError(e),
        onDone: () {
          activeCount--;
          if (activeCount == 0) {
            controller.close();
          }
        },
      );
    }

    yield* controller.stream;
  }

  /// Cancel an active download
  void cancelDownload(String bundleName) {
    final download = _activeDownloads[bundleName];
    if (download != null) {
      download.cancel();
      _activeDownloads.remove(bundleName);
    }
  }

  /// Cancel all active downloads
  void cancelAllDownloads() {
    for (final download in _activeDownloads.values) {
      download.cancel();
    }
    _activeDownloads.clear();
  }

  /// Check if a bundle is currently downloading
  bool isDownloading(String bundleName) {
    return _activeDownloads.containsKey(bundleName);
  }

  /// Get active download count
  int get activeDownloadCount => _activeDownloads.length;

  /// Dispose resources
  void dispose() {
    cancelAllDownloads();
    _httpClient.close();
  }
}

/// Tracks an active download
class _ActiveDownload {
  final String bundleName;
  final StreamController<DownloadProgress> _controller =
      StreamController<DownloadProgress>.broadcast();
  bool _cancelled = false;

  _ActiveDownload(this.bundleName);

  Stream<DownloadProgress> get progressStream => _controller.stream;
  bool get isCancelled => _cancelled;

  void addProgress(DownloadProgress progress) {
    if (!_cancelled && !_controller.isClosed) {
      _controller.add(progress);
    }
  }

  void cancel() {
    _cancelled = true;
    if (!_controller.isClosed) {
      _controller.add(DownloadProgress(
        bundleName: bundleName,
        downloadedBytes: 0,
        totalBytes: 0,
        state: DownloadState.cancelled,
      ));
    }
  }

  void close() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
