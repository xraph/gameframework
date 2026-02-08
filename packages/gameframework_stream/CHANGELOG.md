# Changelog

All notable changes to the gameframework_stream package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.3] - 2026-02-06

### Changed
- Updated documentation to reflect accurate development status
- Improved clarity on platform support

## [0.0.2] - 2026-02-06

### Changed
- Updated README with improved documentation and examples
- Minor documentation improvements

## [0.0.1] - 2026-02-06

### Initial Release

Asset streaming support for GameFramework. Enables on-demand downloading of Unity Addressable assets from GameFramework Cloud.

#### Core Features

**Asset Streaming:**
- On-demand asset downloading from remote servers
- Support for Unity Addressables integration
- Asset bundle management and caching
- Bandwidth-aware streaming with quality adaptation
- Resume capability for interrupted downloads
- Progress tracking and reporting

**Cache Management:**
- Local asset cache with configurable size limits
- LRU (Least Recently Used) eviction strategy
- Cache persistence across app sessions
- Manual cache clearing APIs
- Cache statistics and monitoring

**Network Optimization:**
- Automatic quality adjustment based on connection speed
- Chunked downloads with retry logic
- Concurrent download management
- Bandwidth throttling options
- Connection type awareness (WiFi vs Cellular)

**API:**
- `StreamingAssetManager` - Main asset streaming controller
- `AssetDownloadRequest` - Request model for asset downloads
- `StreamingConfig` - Configuration for streaming behavior
- `CacheConfig` - Cache size and policy configuration
- Event streams for download progress and completion

**Integration:**
- Seamless integration with `gameframework` core package
- Compatible with Unity Addressables workflow
- Works with GameFramework Cloud CDN
- Platform-agnostic implementation

#### Technical Specifications

**Dependencies:**
```yaml
dependencies:
  gameframework: ^0.0.1
  http: ^1.2.0
  path_provider: ^2.1.1
  crypto: ^3.0.3
  connectivity_plus: ^6.0.0
```

**Supported Platforms:**
- Android (API 21+)
- iOS (12.0+)
- macOS (10.14+)
- Windows (10+)
- Linux (Ubuntu 20.04+)
- Web (with limitations)

#### Usage Example

```dart
import 'package:gameframework_stream/gameframework_stream.dart';

// Initialize streaming manager
final manager = StreamingAssetManager(
  config: StreamingConfig(
    baseUrl: 'https://cdn.gameframework.cloud',
    maxCacheSizeMB: 500,
    enableBackgroundDownloads: true,
  ),
);

// Download an asset
await manager.downloadAsset(
  AssetDownloadRequest(
    assetId: 'level_001',
    bundleName: 'levels.bundle',
  ),
  onProgress: (progress) {
    print('Download progress: ${progress * 100}%');
  },
);

// Load downloaded asset
final assetPath = await manager.getAssetPath('level_001');
```

#### Features

**Quality Adaptation:**
- Automatic quality selection based on network speed
- Manual quality override options
- Progressive quality enhancement

**Download Management:**
- Priority-based download queue
- Pause/resume support
- Background download capability
- Batch download operations

**Error Handling:**
- Automatic retry with exponential backoff
- Network error recovery
- Disk space monitoring
- Graceful degradation

**Monitoring:**
- Real-time download progress
- Cache utilization metrics
- Network bandwidth usage
- Download history tracking

#### Breaking Changes

None - Initial release.

#### Known Limitations

- Web platform has limited cache persistence
- Background downloads require platform-specific permissions
- Maximum concurrent downloads: 3 (configurable)

---

## [Unreleased]

### Planned Features

**v0.1.0 - Enhanced Streaming:**
- Differential asset updates
- P2P asset sharing (experimental)
- Advanced prefetching strategies
- Custom CDN integrations

**v0.2.0 - Analytics:**
- Detailed streaming analytics
- User behavior insights
- Performance profiling
- A/B testing support

**v0.3.0 - Advanced Features:**
- Multi-CDN failover
- Regional content delivery
- Asset version management
- Content encryption support

**v1.0.0 - Production Release:**
- Complete documentation
- Production performance benchmarks
- Enterprise features
- SLA guarantees

---

## Links

- [GitHub Repository](https://github.com/xraph/gameframework)
- [Issue Tracker](https://github.com/xraph/gameframework/issues)
- [pub.dev Package](https://pub.dev/packages/gameframework_stream)

---

**Last Updated:** 2026-02-06
