import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Binary message protocol for Unreal Engine communication.
///
/// Provides utilities for encoding, compressing, and chunking binary data
/// for transmission between Flutter and Unreal Engine.
///
/// Features:
/// - Base64 encoding/decoding
/// - GZip compression for large payloads
/// - Chunked transfer for files >64KB
/// - CRC32 checksum verification
/// - Progress tracking
///
/// Example:
/// ```dart
/// final protocol = UnrealBinaryProtocol();
///
/// // Encode and compress
/// final encoded = protocol.encode(imageBytes);
/// final compressed = protocol.compress(largeData);
///
/// // Chunked transfer for large files
/// await for (final chunk in protocol.createChunks(hugeFile, onProgress: (p) {
///   print('Progress: ${(p * 100).toStringAsFixed(1)}%');
/// })) {
///   await sendChunk(chunk);
/// }
/// ```
class UnrealBinaryProtocol {
  /// GZip marker byte (0x1F indicates gzip magic number start)
  static const int gzipMarker = 0x1F;

  /// Compression threshold in bytes (default 1KB)
  static const int compressionThreshold = 1024;

  /// Default chunk size for large transfers (64KB)
  static const int defaultChunkSize = 64 * 1024;

  /// Maximum message size before chunking is required
  static const int maxSingleMessageSize = 256 * 1024;

  int _chunkSize = defaultChunkSize;
  bool _autoCompress = true;

  /// Configure protocol settings.
  void configure({
    int? chunkSize,
    bool? autoCompress,
  }) {
    if (chunkSize != null) _chunkSize = chunkSize;
    if (autoCompress != null) _autoCompress = autoCompress;
  }

  /// Current chunk size setting.
  int get chunkSize => _chunkSize;

  /// Whether auto-compression is enabled.
  bool get autoCompress => _autoCompress;

  // ============================================================
  // MARK: - Encoding
  // ============================================================

  /// Encode binary data to base64 string.
  String encode(Uint8List data) {
    return base64Encode(data);
  }

  /// Decode base64 string to binary data.
  Uint8List decode(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      throw BinaryProtocolException(
        'Failed to decode base64 data: $e',
        BinaryProtocolErrorCode.decodingFailed,
      );
    }
  }

  /// Encode with optional auto-compression.
  ///
  /// Returns a [BinaryEnvelope] containing the encoded data and metadata.
  BinaryEnvelope encodeWithMetadata(Uint8List data, {bool? compress}) {
    final shouldCompress =
        (compress ?? _autoCompress) && data.length > compressionThreshold;

    Uint8List processedData;
    bool wasCompressed = false;

    if (shouldCompress) {
      processedData = compressData(data);
      wasCompressed = true;
      // Only use compression if it actually reduces size
      if (processedData.length >= data.length) {
        processedData = data;
        wasCompressed = false;
      }
    } else {
      processedData = data;
    }

    final checksum = _calculateCRC32(processedData);

    return BinaryEnvelope(
      data: encode(processedData),
      originalSize: data.length,
      compressedSize: processedData.length,
      isCompressed: wasCompressed,
      checksum: checksum,
    );
  }

  // ============================================================
  // MARK: - Compression
  // ============================================================

  /// Compress data using GZip.
  Uint8List compressData(Uint8List data) {
    try {
      return Uint8List.fromList(gzip.encode(data));
    } catch (e) {
      throw BinaryProtocolException(
        'Failed to compress data: $e',
        BinaryProtocolErrorCode.compressionFailed,
      );
    }
  }

  /// Decompress GZip data.
  Uint8List decompressData(Uint8List data) {
    try {
      // Check for GZip magic number
      if (data.length >= 2 && data[0] == gzipMarker && data[1] == 0x8B) {
        return Uint8List.fromList(gzip.decode(data));
      }
      // Not compressed, return as-is
      return data;
    } catch (e) {
      throw BinaryProtocolException(
        'Failed to decompress data: $e',
        BinaryProtocolErrorCode.decompressionFailed,
      );
    }
  }

  /// Check if data is GZip compressed.
  bool isCompressed(Uint8List data) {
    return data.length >= 2 && data[0] == gzipMarker && data[1] == 0x8B;
  }

  // ============================================================
  // MARK: - Chunking
  // ============================================================

  /// Split large data into chunks for transmission.
  ///
  /// Returns an async stream of [BinaryChunk] objects.
  Stream<BinaryChunk> createChunks(
    Uint8List data, {
    void Function(double progress)? onProgress,
    String? transferId,
  }) async* {
    final id = transferId ?? _generateTransferId();
    final totalChunks = (data.length / _chunkSize).ceil();
    final checksum = _calculateCRC32(data);

    // Emit header chunk
    yield BinaryChunk.header(
      transferId: id,
      totalSize: data.length,
      totalChunks: totalChunks,
      checksum: checksum,
    );

    // Emit data chunks
    for (int i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize).clamp(0, data.length);
      final chunkData = data.sublist(start, end);

      yield BinaryChunk.data(
        transferId: id,
        chunkIndex: i,
        totalChunks: totalChunks,
        data: encode(chunkData),
      );

      // Report progress
      if (onProgress != null) {
        onProgress((i + 1) / totalChunks);
      }
    }

    // Emit footer chunk
    yield BinaryChunk.footer(
      transferId: id,
      totalChunks: totalChunks,
      checksum: checksum,
    );
  }

  /// Reassemble chunks into complete data.
  ///
  /// The [assembler] accumulates chunks until the transfer is complete.
  ChunkAssembler createAssembler() {
    return ChunkAssembler(this);
  }

  // ============================================================
  // MARK: - Checksum
  // ============================================================

  /// Calculate CRC32 checksum.
  int _calculateCRC32(Uint8List data) {
    // CRC32 implementation
    const table = _crc32Table;
    int crc = 0xFFFFFFFF;

    for (final byte in data) {
      crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }

    return crc ^ 0xFFFFFFFF;
  }

  /// Verify CRC32 checksum.
  bool verifyChecksum(Uint8List data, int expectedChecksum) {
    return _calculateCRC32(data) == expectedChecksum;
  }

  // ============================================================
  // MARK: - Utilities
  // ============================================================

  String _generateTransferId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random =
        (DateTime.now().millisecond * 1000 + DateTime.now().microsecond % 1000)
            .toRadixString(36);
    return 'tf_${timestamp.toRadixString(36)}_$random';
  }

  /// CRC32 lookup table
  static const List<int> _crc32Table = [
    0x00000000,
    0x77073096,
    0xEE0E612C,
    0x990951BA,
    0x076DC419,
    0x706AF48F,
    0xE963A535,
    0x9E6495A3,
    0x0EDB8832,
    0x79DCB8A4,
    0xE0D5E91E,
    0x97D2D988,
    0x09B64C2B,
    0x7EB17CBD,
    0xE7B82D07,
    0x90BF1D91,
    0x1DB71064,
    0x6AB020F2,
    0xF3B97148,
    0x84BE41DE,
    0x1ADAD47D,
    0x6DDDE4EB,
    0xF4D4B551,
    0x83D385C7,
    0x136C9856,
    0x646BA8C0,
    0xFD62F97A,
    0x8A65C9EC,
    0x14015C4F,
    0x63066CD9,
    0xFA0F3D63,
    0x8D080DF5,
    0x3B6E20C8,
    0x4C69105E,
    0xD56041E4,
    0xA2677172,
    0x3C03E4D1,
    0x4B04D447,
    0xD20D85FD,
    0xA50AB56B,
    0x35B5A8FA,
    0x42B2986C,
    0xDBBBC9D6,
    0xACBCF940,
    0x32D86CE3,
    0x45DF5C75,
    0xDCD60DCF,
    0xABD13D59,
    0x26D930AC,
    0x51DE003A,
    0xC8D75180,
    0xBFD06116,
    0x21B4F4B5,
    0x56B3C423,
    0xCFBA9599,
    0xB8BDA50F,
    0x2802B89E,
    0x5F058808,
    0xC60CD9B2,
    0xB10BE924,
    0x2F6F7C87,
    0x58684C11,
    0xC1611DAB,
    0xB6662D3D,
    0x76DC4190,
    0x01DB7106,
    0x98D220BC,
    0xEFD5102A,
    0x71B18589,
    0x06B6B51F,
    0x9FBFE4A5,
    0xE8B8D433,
    0x7807C9A2,
    0x0F00F934,
    0x9609A88E,
    0xE10E9818,
    0x7F6A0DBB,
    0x086D3D2D,
    0x91646C97,
    0xE6635C01,
    0x6B6B51F4,
    0x1C6C6162,
    0x856530D8,
    0xF262004E,
    0x6C0695ED,
    0x1B01A57B,
    0x8208F4C1,
    0xF50FC457,
    0x65B0D9C6,
    0x12B7E950,
    0x8BBEB8EA,
    0xFCB9887C,
    0x62DD1DDF,
    0x15DA2D49,
    0x8CD37CF3,
    0xFBD44C65,
    0x4DB26158,
    0x3AB551CE,
    0xA3BC0074,
    0xD4BB30E2,
    0x4ADFA541,
    0x3DD895D7,
    0xA4D1C46D,
    0xD3D6F4FB,
    0x4369E96A,
    0x346ED9FC,
    0xAD678846,
    0xDA60B8D0,
    0x44042D73,
    0x33031DE5,
    0xAA0A4C5F,
    0xDD0D7CC9,
    0x5005713C,
    0x270241AA,
    0xBE0B1010,
    0xC90C2086,
    0x5768B525,
    0x206F85B3,
    0xB966D409,
    0xCE61E49F,
    0x5EDEF90E,
    0x29D9C998,
    0xB0D09822,
    0xC7D7A8B4,
    0x59B33D17,
    0x2EB40D81,
    0xB7BD5C3B,
    0xC0BA6CAD,
    0xEDB88320,
    0x9ABFB3B6,
    0x03B6E20C,
    0x74B1D29A,
    0xEAD54739,
    0x9DD277AF,
    0x04DB2615,
    0x73DC1683,
    0xE3630B12,
    0x94643B84,
    0x0D6D6A3E,
    0x7A6A5AA8,
    0xE40ECF0B,
    0x9309FF9D,
    0x0A00AE27,
    0x7D079EB1,
    0xF00F9344,
    0x8708A3D2,
    0x1E01F268,
    0x6906C2FE,
    0xF762575D,
    0x806567CB,
    0x196C3671,
    0x6E6B06E7,
    0xFED41B76,
    0x89D32BE0,
    0x10DA7A5A,
    0x67DD4ACC,
    0xF9B9DF6F,
    0x8EBEEFF9,
    0x17B7BE43,
    0x60B08ED5,
    0xD6D6A3E8,
    0xA1D1937E,
    0x38D8C2C4,
    0x4FDFF252,
    0xD1BB67F1,
    0xA6BC5767,
    0x3FB506DD,
    0x48B2364B,
    0xD80D2BDA,
    0xAF0A1B4C,
    0x36034AF6,
    0x41047A60,
    0xDF60EFC3,
    0xA867DF55,
    0x316E8EEF,
    0x4669BE79,
    0xCB61B38C,
    0xBC66831A,
    0x256FD2A0,
    0x5268E236,
    0xCC0C7795,
    0xBB0B4703,
    0x220216B9,
    0x5505262F,
    0xC5BA3BBE,
    0xB2BD0B28,
    0x2BB45A92,
    0x5CB36A04,
    0xC2D7FFA7,
    0xB5D0CF31,
    0x2CD99E8B,
    0x5BDEAE1D,
    0x9B64C2B0,
    0xEC63F226,
    0x756AA39C,
    0x026D930A,
    0x9C0906A9,
    0xEB0E363F,
    0x72076785,
    0x05005713,
    0x95BF4A82,
    0xE2B87A14,
    0x7BB12BAE,
    0x0CB61B38,
    0x92D28E9B,
    0xE5D5BE0D,
    0x7CDCEFB7,
    0x0BDBDF21,
    0x86D3D2D4,
    0xF1D4E242,
    0x68DDB3F8,
    0x1FDA836E,
    0x81BE16CD,
    0xF6B9265B,
    0x6FB077E1,
    0x18B74777,
    0x88085AE6,
    0xFF0F6A70,
    0x66063BCA,
    0x11010B5C,
    0x8F659EFF,
    0xF862AE69,
    0x616BFFD3,
    0x166CCF45,
    0xA00AE278,
    0xD70DD2EE,
    0x4E048354,
    0x3903B3C2,
    0xA7672661,
    0xD06016F7,
    0x4969474D,
    0x3E6E77DB,
    0xAED16A4A,
    0xD9D65ADC,
    0x40DF0B66,
    0x37D83BF0,
    0xA9BCAE53,
    0xDEBB9EC5,
    0x47B2CF7F,
    0x30B5FFE9,
    0xBDBDF21C,
    0xCABAC28A,
    0x53B39330,
    0x24B4A3A6,
    0xBAD03605,
    0xCDD70693,
    0x54DE5729,
    0x23D967BF,
    0xB3667A2E,
    0xC4614AB8,
    0x5D681B02,
    0x2A6F2B94,
    0xB40BBE37,
    0xC30C8EA1,
    0x5A05DF1B,
    0x2D02EF8D,
  ];
}

// ============================================================
// MARK: - Data Classes
// ============================================================

/// Binary data envelope with metadata.
class BinaryEnvelope {
  /// Base64 encoded data
  final String data;

  /// Original uncompressed size in bytes
  final int originalSize;

  /// Size after compression (or original if not compressed)
  final int compressedSize;

  /// Whether data is compressed
  final bool isCompressed;

  /// CRC32 checksum
  final int checksum;

  BinaryEnvelope({
    required this.data,
    required this.originalSize,
    required this.compressedSize,
    required this.isCompressed,
    required this.checksum,
  });

  /// Compression ratio (1.0 = no compression, lower = better)
  double get compressionRatio =>
      originalSize > 0 ? compressedSize / originalSize : 1.0;

  /// Convert to JSON map for transmission.
  Map<String, dynamic> toMap() => {
        '_binary': true,
        'data': data,
        'originalSize': originalSize,
        'compressedSize': compressedSize,
        'isCompressed': isCompressed,
        'checksum': checksum,
      };

  /// Create from JSON map.
  factory BinaryEnvelope.fromMap(Map<String, dynamic> map) {
    return BinaryEnvelope(
      data: map['data'] as String,
      originalSize: map['originalSize'] as int,
      compressedSize: map['compressedSize'] as int,
      isCompressed: map['isCompressed'] as bool,
      checksum: map['checksum'] as int,
    );
  }

  @override
  String toString() =>
      'BinaryEnvelope(size=$originalSize, compressed=$isCompressed, '
      'ratio=${(compressionRatio * 100).toStringAsFixed(1)}%)';
}

/// Binary chunk for chunked transfer.
class BinaryChunk {
  final BinaryChunkType type;
  final String transferId;
  final int? chunkIndex;
  final int? totalChunks;
  final int? totalSize;
  final String? data;
  final int? checksum;

  BinaryChunk._({
    required this.type,
    required this.transferId,
    this.chunkIndex,
    this.totalChunks,
    this.totalSize,
    this.data,
    this.checksum,
  });

  /// Create a header chunk.
  factory BinaryChunk.header({
    required String transferId,
    required int totalSize,
    required int totalChunks,
    required int checksum,
  }) {
    return BinaryChunk._(
      type: BinaryChunkType.header,
      transferId: transferId,
      totalSize: totalSize,
      totalChunks: totalChunks,
      checksum: checksum,
    );
  }

  /// Create a data chunk.
  factory BinaryChunk.data({
    required String transferId,
    required int chunkIndex,
    required int totalChunks,
    required String data,
  }) {
    return BinaryChunk._(
      type: BinaryChunkType.data,
      transferId: transferId,
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      data: data,
    );
  }

  /// Create a footer chunk.
  factory BinaryChunk.footer({
    required String transferId,
    required int totalChunks,
    required int checksum,
  }) {
    return BinaryChunk._(
      type: BinaryChunkType.footer,
      transferId: transferId,
      totalChunks: totalChunks,
      checksum: checksum,
    );
  }

  /// Convert to JSON map for transmission.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      '_chunk': true,
      'type': type.name,
      'transferId': transferId,
    };

    if (chunkIndex != null) map['chunkIndex'] = chunkIndex;
    if (totalChunks != null) map['totalChunks'] = totalChunks;
    if (totalSize != null) map['totalSize'] = totalSize;
    if (data != null) map['data'] = data;
    if (checksum != null) map['checksum'] = checksum;

    return map;
  }

  /// Create from JSON map.
  factory BinaryChunk.fromMap(Map<String, dynamic> map) {
    final type = BinaryChunkType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => BinaryChunkType.data,
    );

    return BinaryChunk._(
      type: type,
      transferId: map['transferId'] as String,
      chunkIndex: map['chunkIndex'] as int?,
      totalChunks: map['totalChunks'] as int?,
      totalSize: map['totalSize'] as int?,
      data: map['data'] as String?,
      checksum: map['checksum'] as int?,
    );
  }
}

/// Chunk type enumeration.
enum BinaryChunkType {
  /// Header chunk with metadata
  header,

  /// Data chunk with payload
  data,

  /// Footer chunk with verification
  footer,
}

/// Chunk assembler for receiving chunked transfers.
class ChunkAssembler {
  final UnrealBinaryProtocol _protocol;
  final Map<String, _TransferState> _transfers = {};

  ChunkAssembler(this._protocol);

  /// Process an incoming chunk.
  ///
  /// Returns completed [Uint8List] when transfer finishes, null otherwise.
  Uint8List? processChunk(BinaryChunk chunk) {
    switch (chunk.type) {
      case BinaryChunkType.header:
        _transfers[chunk.transferId] = _TransferState(
          totalSize: chunk.totalSize!,
          totalChunks: chunk.totalChunks!,
          expectedChecksum: chunk.checksum!,
        );
        return null;

      case BinaryChunkType.data:
        final state = _transfers[chunk.transferId];
        if (state == null) {
          debugPrint('ChunkAssembler: Unknown transfer ${chunk.transferId}');
          return null;
        }

        final decoded = _protocol.decode(chunk.data!);
        state.chunks[chunk.chunkIndex!] = decoded;
        state.receivedChunks++;
        return null;

      case BinaryChunkType.footer:
        final state = _transfers[chunk.transferId];
        if (state == null) {
          debugPrint('ChunkAssembler: Unknown transfer ${chunk.transferId}');
          return null;
        }

        // Verify all chunks received
        if (state.receivedChunks != state.totalChunks) {
          throw BinaryProtocolException(
            'Incomplete transfer: received ${state.receivedChunks}/${state.totalChunks} chunks',
            BinaryProtocolErrorCode.incompleteTransfer,
          );
        }

        // Reassemble data
        final buffer = BytesBuilder();
        for (int i = 0; i < state.totalChunks; i++) {
          final chunkData = state.chunks[i];
          if (chunkData == null) {
            throw BinaryProtocolException(
              'Missing chunk $i',
              BinaryProtocolErrorCode.missingChunk,
            );
          }
          buffer.add(chunkData);
        }

        final result = buffer.toBytes();

        // Verify checksum
        if (!_protocol.verifyChecksum(result, state.expectedChecksum)) {
          throw BinaryProtocolException(
            'Checksum verification failed',
            BinaryProtocolErrorCode.checksumMismatch,
          );
        }

        // Cleanup
        _transfers.remove(chunk.transferId);

        return result;
    }
  }

  /// Get transfer progress (0.0 - 1.0).
  double getProgress(String transferId) {
    final state = _transfers[transferId];
    if (state == null) return 0.0;
    return state.receivedChunks / state.totalChunks;
  }

  /// Check if transfer is in progress.
  bool hasTransfer(String transferId) => _transfers.containsKey(transferId);

  /// Cancel a transfer.
  void cancelTransfer(String transferId) {
    _transfers.remove(transferId);
  }

  /// Cancel all transfers.
  void cancelAll() {
    _transfers.clear();
  }
}

class _TransferState {
  final int totalSize;
  final int totalChunks;
  final int expectedChecksum;
  final Map<int, Uint8List> chunks = {};
  int receivedChunks = 0;

  _TransferState({
    required this.totalSize,
    required this.totalChunks,
    required this.expectedChecksum,
  });
}

// ============================================================
// MARK: - Progress Tracking
// ============================================================

/// Progress information for binary transfers.
class BinaryTransferProgress {
  /// Transfer identifier
  final String transferId;

  /// Current chunk index (0-based)
  final int currentChunk;

  /// Total number of chunks
  final int totalChunks;

  /// Bytes transferred so far
  final int bytesTransferred;

  /// Total bytes to transfer
  final int totalBytes;

  /// Transfer direction
  final BinaryTransferDirection direction;

  /// Timestamp
  final DateTime timestamp;

  BinaryTransferProgress({
    required this.transferId,
    required this.currentChunk,
    required this.totalChunks,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.direction,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Progress percentage (0.0 - 1.0)
  double get progress => totalChunks > 0 ? currentChunk / totalChunks : 0.0;

  /// Progress percentage as integer (0 - 100)
  int get progressPercent => (progress * 100).round();

  /// Whether transfer is complete
  bool get isComplete => currentChunk >= totalChunks;

  @override
  String toString() =>
      'BinaryTransferProgress($transferId: $currentChunk/$totalChunks, '
      '$bytesTransferred/$totalBytes bytes, $progressPercent%)';
}

/// Direction of binary transfer.
enum BinaryTransferDirection {
  /// Sending to Unreal
  sending,

  /// Receiving from Unreal
  receiving,
}

// ============================================================
// MARK: - Exceptions
// ============================================================

/// Exception for binary protocol errors.
class BinaryProtocolException implements Exception {
  final String message;
  final BinaryProtocolErrorCode code;

  BinaryProtocolException(this.message, this.code);

  @override
  String toString() => 'BinaryProtocolException($code): $message';
}

/// Error codes for binary protocol.
enum BinaryProtocolErrorCode {
  /// Failed to encode data
  encodingFailed,

  /// Failed to decode data
  decodingFailed,

  /// Failed to compress data
  compressionFailed,

  /// Failed to decompress data
  decompressionFailed,

  /// Transfer incomplete
  incompleteTransfer,

  /// Missing chunk in sequence
  missingChunk,

  /// Checksum verification failed
  checksumMismatch,

  /// Transfer timeout
  transferTimeout,

  /// Unknown error
  unknown,
}
