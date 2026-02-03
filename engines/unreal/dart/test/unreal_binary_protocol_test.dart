import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameframework_unreal/src/unreal_binary_protocol.dart';

void main() {
  group('UnrealBinaryProtocol', () {
    late UnrealBinaryProtocol protocol;

    setUp(() {
      protocol = UnrealBinaryProtocol();
    });

    group('Base64 encoding/decoding', () {
      test('encodes bytes to base64 string', () {
        final bytes = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
        final encoded = protocol.encode(bytes);

        expect(encoded, isNotEmpty);
        expect(encoded, equals('SGVsbG8=')); // Base64 for "Hello"
      });

      test('decodes base64 string to bytes', () {
        const encoded = 'SGVsbG8=';
        final decoded = protocol.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded.length, equals(5));
        expect(String.fromCharCodes(decoded), equals('Hello'));
      });

      test('throws for invalid base64', () {
        expect(
          () => protocol.decode('invalid!!!'),
          throwsA(isA<BinaryProtocolException>()),
        );
      });

      test('handles empty input', () {
        final bytes = Uint8List(0);
        final encoded = protocol.encode(bytes);
        expect(encoded, isEmpty);

        final decoded = protocol.decode('');
        expect(decoded, isNotNull);
        expect(decoded.length, equals(0));
      });

      test('roundtrip encoding/decoding preserves data', () {
        final original = Uint8List.fromList(
          List.generate(256, (i) => i),
        ); // All byte values 0-255

        final encoded = protocol.encode(original);
        final decoded = protocol.decode(encoded);

        expect(decoded, isNotNull);
        expect(decoded.length, equals(original.length));
        for (var i = 0; i < original.length; i++) {
          expect(decoded[i], equals(original[i]));
        }
      });
    });

    group('Compression/decompression', () {
      test('compresses data', () {
        // Repetitive data compresses well
        final data = Uint8List.fromList(List.generate(1000, (i) => i % 10));
        final compressed = protocol.compressData(data);

        expect(compressed, isNotNull);
        expect(compressed.length, lessThan(data.length));
      });

      test('decompresses data', () {
        final original = Uint8List.fromList([72, 101, 108, 108, 111]);
        final compressed = protocol.compressData(original);
        final decompressed = protocol.decompressData(compressed);

        expect(decompressed, isNotNull);
        expect(decompressed, equals(original));
      });

      test('roundtrip compression preserves data', () {
        final original =
            Uint8List.fromList(List.generate(500, (i) => (i * 7) % 256));

        final compressed = protocol.compressData(original);
        final decompressed = protocol.decompressData(compressed);

        expect(decompressed, equals(original));
      });

      test('handles empty data', () {
        final empty = Uint8List(0);
        final compressed = protocol.compressData(empty);

        expect(compressed, isNotNull);

        final decompressed = protocol.decompressData(compressed);
        expect(decompressed, isNotNull);
        expect(decompressed.length, equals(0));
      });
    });

    group('Checksum verification', () {
      test('verifyChecksum validates correctly', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);

        // Get checksum via encodeWithMetadata
        final envelope = protocol.encodeWithMetadata(data, compress: false);
        final checksum = envelope.checksum;

        // Verify with correct checksum
        expect(protocol.verifyChecksum(data, checksum), isTrue);

        // Verify with wrong checksum
        expect(protocol.verifyChecksum(data, checksum + 1), isFalse);
      });

      test('same data produces same checksum', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);

        final envelope1 = protocol.encodeWithMetadata(data, compress: false);
        final envelope2 = protocol.encodeWithMetadata(data, compress: false);

        expect(envelope1.checksum, equals(envelope2.checksum));
      });

      test('different data produces different checksum', () {
        final data1 = Uint8List.fromList([1, 2, 3]);
        final data2 = Uint8List.fromList([1, 2, 4]);

        final envelope1 = protocol.encodeWithMetadata(data1, compress: false);
        final envelope2 = protocol.encodeWithMetadata(data2, compress: false);

        expect(envelope1.checksum, isNot(equals(envelope2.checksum)));
      });
    });

    group('encodeWithMetadata', () {
      test('creates envelope with metadata', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final envelope = protocol.encodeWithMetadata(data, compress: false);

        expect(envelope.originalSize, equals(5));
        expect(envelope.isCompressed, isFalse);
        expect(envelope.checksum, isNot(0));
      });

      test('auto-compresses large data', () {
        // Large repetitive data
        final data = Uint8List.fromList(List.generate(5000, (i) => i % 50));
        final envelope = protocol.encodeWithMetadata(data);

        expect(envelope.isCompressed, isTrue);
        expect(envelope.originalSize, equals(5000));
        expect(envelope.compressedSize, lessThan(5000));
      });

      test('skips compression for small data', () {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        final envelope = protocol.encodeWithMetadata(data);

        expect(envelope.isCompressed, isFalse);
      });

      test('allows explicit compression control', () {
        final data = Uint8List.fromList(List.generate(2000, (i) => i % 10));

        // Force no compression
        final noCompress = protocol.encodeWithMetadata(data, compress: false);
        expect(noCompress.isCompressed, isFalse);

        // Force compression
        final compressed = protocol.encodeWithMetadata(data, compress: true);
        expect(compressed.isCompressed, isTrue);
      });
    });

    group('ChunkAssembler', () {
      test('creates assembler', () {
        final assembler = protocol.createAssembler();
        expect(assembler, isNotNull);
      });

      test('hasTransfer returns false for unknown transfers', () {
        final assembler = protocol.createAssembler();
        expect(assembler.hasTransfer('unknown'), isFalse);
      });

      test('getProgress returns 0 for unknown transfers', () {
        final assembler = protocol.createAssembler();
        expect(assembler.getProgress('unknown'), equals(0.0));
      });

      test('cancelAll clears all transfers', () {
        final assembler = protocol.createAssembler();
        // Should not throw
        assembler.cancelAll();
      });
    });

    group('BinaryEnvelope', () {
      test('creates envelope with all fields', () {
        const encodedData = 'AQID'; // Base64 for [1, 2, 3]
        final envelope = BinaryEnvelope(
          data: encodedData,
          isCompressed: false,
          checksum: 12345,
          originalSize: 3,
          compressedSize: 3,
        );

        expect(envelope.data, equals(encodedData));
        expect(envelope.isCompressed, isFalse);
        expect(envelope.checksum, equals(12345));
        expect(envelope.originalSize, equals(3));
        expect(envelope.compressedSize, equals(3));
      });

      test('data field is already base64 encoded', () {
        const encodedData = 'SGVsbG8='; // Base64 for "Hello"
        final envelope = BinaryEnvelope(
          data: encodedData,
          isCompressed: false,
          checksum: 0,
          originalSize: 5,
          compressedSize: 5,
        );

        expect(envelope.data, equals('SGVsbG8='));
      });

      test('compressionRatio calculates correctly', () {
        final envelope = BinaryEnvelope(
          data: 'data',
          isCompressed: true,
          checksum: 0,
          originalSize: 100,
          compressedSize: 50,
        );

        expect(envelope.compressionRatio, equals(0.5));
      });
    });

    group('BinaryChunk', () {
      test('creates header chunk via factory', () {
        final chunk = BinaryChunk.header(
          transferId: 'test-id',
          totalSize: 1000,
          totalChunks: 10,
          checksum: 12345,
        );

        expect(chunk.type, equals(BinaryChunkType.header));
        expect(chunk.transferId, equals('test-id'));
        expect(chunk.totalSize, equals(1000));
        expect(chunk.totalChunks, equals(10));
      });

      test('creates data chunk via factory', () {
        final chunk = BinaryChunk.data(
          transferId: 'test-id',
          chunkIndex: 5,
          totalChunks: 10,
          data: 'encodedData',
        );

        expect(chunk.type, equals(BinaryChunkType.data));
        expect(chunk.chunkIndex, equals(5));
        expect(chunk.data, equals('encodedData'));
      });

      test('creates footer chunk via factory', () {
        final chunk = BinaryChunk.footer(
          transferId: 'test-id',
          totalChunks: 10,
          checksum: 12345,
        );

        expect(chunk.type, equals(BinaryChunkType.footer));
        expect(chunk.transferId, equals('test-id'));
        expect(chunk.totalChunks, equals(10));
        expect(chunk.checksum, equals(12345));
      });

      test('toMap includes all fields for header', () {
        final chunk = BinaryChunk.header(
          transferId: 'test',
          totalSize: 100,
          totalChunks: 5,
          checksum: 999,
        );

        final map = chunk.toMap();

        expect(map['type'], equals('header'));
        expect(map['transferId'], equals('test'));
        expect(map['totalSize'], equals(100));
        expect(map['totalChunks'], equals(5));
        expect(map['checksum'], equals(999));
      });
    });

    group('Configuration', () {
      test('configure changes chunk size', () {
        protocol.configure(chunkSize: 1024);
        expect(protocol.chunkSize, equals(1024));
      });

      test('configure changes auto compress', () {
        protocol.configure(autoCompress: false);
        expect(protocol.autoCompress, isFalse);

        protocol.configure(autoCompress: true);
        expect(protocol.autoCompress, isTrue);
      });
    });
  });
}
