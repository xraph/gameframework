/// Strategy for downloading content bundles
enum DownloadStrategy {
  /// Only download when connected to WiFi
  wifiOnly,

  /// Download on WiFi or cellular data
  wifiOrCellular,

  /// Download on any connection, including metered
  any,

  /// Manual download only - don't auto-download
  manual,
}

/// Extension methods for DownloadStrategy
extension DownloadStrategyExtension on DownloadStrategy {
  /// Whether this strategy allows downloading on cellular
  bool get allowsCellular {
    switch (this) {
      case DownloadStrategy.wifiOnly:
        return false;
      case DownloadStrategy.wifiOrCellular:
      case DownloadStrategy.any:
        return true;
      case DownloadStrategy.manual:
        return true; // Manual means user explicitly requested
    }
  }

  /// Whether this strategy allows automatic downloads
  bool get allowsAutoDownload {
    return this != DownloadStrategy.manual;
  }

  /// Human-readable description
  String get description {
    switch (this) {
      case DownloadStrategy.wifiOnly:
        return 'Download only on WiFi';
      case DownloadStrategy.wifiOrCellular:
        return 'Download on WiFi or cellular';
      case DownloadStrategy.any:
        return 'Download on any connection';
      case DownloadStrategy.manual:
        return 'Manual download only';
    }
  }
}
