/// Represents the progress of a content download
class DownloadProgress {
  /// Name of the bundle being downloaded
  final String bundleName;

  /// Bytes downloaded so far
  final int downloadedBytes;

  /// Total bytes to download
  final int totalBytes;

  /// Current state of the download
  final DownloadState state;

  /// Error message if download failed
  final String? error;

  /// Download speed in bytes per second
  final int? bytesPerSecond;

  /// Estimated time remaining in seconds
  final int? estimatedSecondsRemaining;

  DownloadProgress({
    required this.bundleName,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.state,
    this.error,
    this.bytesPerSecond,
    this.estimatedSecondsRemaining,
  });

  /// Create a progress instance for a completed download
  factory DownloadProgress.completed(String bundleName, int totalBytes) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: totalBytes,
      totalBytes: totalBytes,
      state: DownloadState.completed,
    );
  }

  /// Create a progress instance for a cached/skipped download
  factory DownloadProgress.cached(String bundleName) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: 0,
      totalBytes: 0,
      state: DownloadState.cached,
    );
  }

  /// Create a progress instance for a failed download
  factory DownloadProgress.failed(String bundleName, String error) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: 0,
      totalBytes: 0,
      state: DownloadState.failed,
      error: error,
    );
  }

  /// Create a progress instance for the start of a download
  factory DownloadProgress.starting(String bundleName, int totalBytes) {
    return DownloadProgress(
      bundleName: bundleName,
      downloadedBytes: 0,
      totalBytes: totalBytes,
      state: DownloadState.downloading,
    );
  }

  /// Progress as a value between 0.0 and 1.0
  double get percentage {
    if (totalBytes == 0) return state == DownloadState.completed ? 1.0 : 0.0;
    return downloadedBytes / totalBytes;
  }

  /// Progress as a percentage string (e.g., "45%")
  String get percentageString => '${(percentage * 100).toInt()}%';

  /// Whether the download is complete
  bool get isComplete =>
      state == DownloadState.completed || state == DownloadState.cached;

  /// Whether the download failed
  bool get isFailed => state == DownloadState.failed;

  /// Whether the download is in progress
  bool get isInProgress => state == DownloadState.downloading;

  /// Human-readable downloaded size
  String get downloadedSizeString => _formatBytes(downloadedBytes);

  /// Human-readable total size
  String get totalSizeString => _formatBytes(totalBytes);

  /// Human-readable download speed
  String? get speedString {
    if (bytesPerSecond == null) return null;
    return '${_formatBytes(bytesPerSecond!)}/s';
  }

  /// Human-readable ETA
  String? get etaString {
    if (estimatedSecondsRemaining == null) return null;
    if (estimatedSecondsRemaining! < 60) {
      return '${estimatedSecondsRemaining}s';
    }
    final minutes = estimatedSecondsRemaining! ~/ 60;
    final seconds = estimatedSecondsRemaining! % 60;
    return '${minutes}m ${seconds}s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'DownloadProgress(bundle: $bundleName, state: $state, progress: $percentageString)';
  }
}

/// State of a download operation
enum DownloadState {
  /// Download is queued
  queued,

  /// Download is in progress
  downloading,

  /// Download is paused
  paused,

  /// Download completed successfully
  completed,

  /// Content was already cached
  cached,

  /// Download failed
  failed,

  /// Download was cancelled
  cancelled,
}
