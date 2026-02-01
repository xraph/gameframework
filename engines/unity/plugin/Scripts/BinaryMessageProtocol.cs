using System;
using System.IO;
using System.IO.Compression;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Protocol for binary data transfer between Flutter and Unity.
    /// 
    /// Provides encoding, decoding, compression, and chunked transfer
    /// for efficient binary data exchange.
    /// </summary>
    public static class BinaryMessageProtocol
    {
        #region Configuration

        /// <summary>
        /// Default chunk size for chunked transfers (64KB)
        /// </summary>
        public const int DefaultChunkSize = 65536;

        /// <summary>
        /// Compression threshold - data smaller than this won't be compressed
        /// </summary>
        public const int CompressionThreshold = 1024;

        #endregion

        #region Encoding/Decoding

        /// <summary>
        /// Encode binary data to base64 string.
        /// </summary>
        /// <param name="data">Raw binary data</param>
        /// <returns>Base64 encoded string</returns>
        public static string Encode(byte[] data)
        {
            if (data == null || data.Length == 0) return string.Empty;
            return Convert.ToBase64String(data);
        }

        /// <summary>
        /// Decode base64 string to binary data.
        /// </summary>
        /// <param name="base64">Base64 encoded string</param>
        /// <returns>Raw binary data</returns>
        public static byte[] Decode(string base64)
        {
            if (string.IsNullOrEmpty(base64)) return Array.Empty<byte>();

            try
            {
                return Convert.FromBase64String(base64);
            }
            catch (FormatException e)
            {
                Debug.LogError($"[BinaryMessageProtocol] Invalid base64: {e.Message}");
                return Array.Empty<byte>();
            }
        }

        #endregion

        #region Compression

        /// <summary>
        /// Compress binary data using GZip.
        /// </summary>
        /// <param name="data">Raw data to compress</param>
        /// <returns>Compressed data with header byte</returns>
        public static byte[] Compress(byte[] data)
        {
            if (data == null || data.Length == 0) return data;

            // Don't compress small data
            if (data.Length < CompressionThreshold) return data;

            try
            {
                using (var output = new MemoryStream())
                {
                    // Write compression marker
                    output.WriteByte(0x1F); // Marker for compressed data

                    using (var gzip = new GZipStream(output, CompressionMode.Compress, leaveOpen: true))
                    {
                        gzip.Write(data, 0, data.Length);
                    }

                    var compressed = output.ToArray();

                    // Only use compressed if smaller
                    if (compressed.Length < data.Length)
                    {
                        return compressed;
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning($"[BinaryMessageProtocol] Compression failed: {e.Message}");
            }

            return data;
        }

        /// <summary>
        /// Decompress binary data.
        /// </summary>
        /// <param name="data">Potentially compressed data</param>
        /// <returns>Decompressed data</returns>
        public static byte[] Decompress(byte[] data)
        {
            if (data == null || data.Length == 0) return data;

            // Check for compression marker
            if (data[0] != 0x1F) return data; // Not compressed

            try
            {
                using (var input = new MemoryStream(data, 1, data.Length - 1)) // Skip marker
                using (var gzip = new GZipStream(input, CompressionMode.Decompress))
                using (var output = new MemoryStream())
                {
                    gzip.CopyTo(output);
                    return output.ToArray();
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[BinaryMessageProtocol] Decompression failed: {e.Message}");
                return data;
            }
        }

        /// <summary>
        /// Check if data is compressed (has compression marker).
        /// </summary>
        public static bool IsCompressed(byte[] data)
        {
            return data != null && data.Length > 0 && data[0] == 0x1F;
        }

        #endregion

        #region Chunked Transfer

        /// <summary>
        /// Send large binary data in chunks.
        /// </summary>
        /// <param name="target">Target component</param>
        /// <param name="method">Method name</param>
        /// <param name="data">Binary data to send</param>
        /// <param name="chunkSize">Size of each chunk</param>
        public static void SendChunked(string target, string method, byte[] data, int chunkSize = DefaultChunkSize)
        {
            if (data == null || data.Length == 0) return;

            string transferId = Guid.NewGuid().ToString("N").Substring(0, 8);
            int totalChunks = (int)Math.Ceiling((double)data.Length / chunkSize);

            // Send header
            var header = new ChunkHeader
            {
                transferId = transferId,
                totalSize = data.Length,
                totalChunks = totalChunks,
                chunkSize = chunkSize
            };
            string headerJson = JsonUtility.ToJson(header);
            FlutterBridge.Instance.SendToFlutter(target, $"{method}_header", headerJson);

            // Send chunks
            for (int i = 0; i < totalChunks; i++)
            {
                int offset = i * chunkSize;
                int size = Math.Min(chunkSize, data.Length - offset);
                
                byte[] chunk = new byte[size];
                Array.Copy(data, offset, chunk, 0, size);

                var chunkData = new ChunkData
                {
                    transferId = transferId,
                    index = i,
                    data = Convert.ToBase64String(chunk)
                };
                string chunkJson = JsonUtility.ToJson(chunkData);
                FlutterBridge.Instance.SendToFlutter(target, $"{method}_chunk", chunkJson);
            }

            // Send footer (completion marker)
            var footer = new ChunkFooter
            {
                transferId = transferId,
                checksum = ComputeChecksum(data)
            };
            string footerJson = JsonUtility.ToJson(footer);
            FlutterBridge.Instance.SendToFlutter(target, $"{method}_complete", footerJson);

            Debug.Log($"[BinaryMessageProtocol] Sent {data.Length} bytes in {totalChunks} chunks (id: {transferId})");
        }

        /// <summary>
        /// Reassemble chunked data.
        /// </summary>
        public static byte[] ReassembleChunks(ChunkHeader header, ChunkData[] chunks)
        {
            if (header == null || chunks == null || chunks.Length == 0)
            {
                return Array.Empty<byte>();
            }

            byte[] result = new byte[header.totalSize];
            int offset = 0;

            // Sort chunks by index
            Array.Sort(chunks, (a, b) => a.index.CompareTo(b.index));

            foreach (var chunk in chunks)
            {
                byte[] chunkData = Decode(chunk.data);
                Array.Copy(chunkData, 0, result, offset, chunkData.Length);
                offset += chunkData.Length;
            }

            return result;
        }

        /// <summary>
        /// Compute simple checksum for data integrity verification.
        /// </summary>
        public static long ComputeChecksum(byte[] data)
        {
            if (data == null || data.Length == 0) return 0;

            long checksum = 0;
            for (int i = 0; i < data.Length; i++)
            {
                checksum = (checksum + data[i]) * 31;
            }
            return checksum;
        }

        /// <summary>
        /// Verify checksum matches.
        /// </summary>
        public static bool VerifyChecksum(byte[] data, long expectedChecksum)
        {
            return ComputeChecksum(data) == expectedChecksum;
        }

        #endregion

        #region Message Envelope

        /// <summary>
        /// Create a binary message envelope.
        /// </summary>
        /// <param name="data">Binary data</param>
        /// <param name="compress">Whether to compress the data</param>
        /// <returns>JSON envelope string</returns>
        public static string CreateEnvelope(byte[] data, bool compress = false)
        {
            byte[] payload = data;
            string dataType = "binary";

            if (compress && data.Length > CompressionThreshold)
            {
                payload = Compress(data);
                if (payload.Length < data.Length)
                {
                    dataType = "compressedBinary";
                }
                else
                {
                    payload = data; // Compression didn't help
                }
            }

            var envelope = new BinaryEnvelope
            {
                dataType = dataType,
                data = Encode(payload),
                size = data.Length,
                compressedSize = payload.Length
            };

            return JsonUtility.ToJson(envelope);
        }

        /// <summary>
        /// Parse a binary message envelope.
        /// </summary>
        /// <param name="json">JSON envelope string</param>
        /// <returns>Decoded binary data</returns>
        public static byte[] ParseEnvelope(string json)
        {
            if (string.IsNullOrEmpty(json)) return Array.Empty<byte>();

            try
            {
                var envelope = JsonUtility.FromJson<BinaryEnvelope>(json);
                if (envelope == null || string.IsNullOrEmpty(envelope.data))
                {
                    return Array.Empty<byte>();
                }

                byte[] decoded = Decode(envelope.data);

                if (envelope.dataType == "compressedBinary")
                {
                    decoded = Decompress(decoded);
                }

                return decoded;
            }
            catch (Exception e)
            {
                Debug.LogError($"[BinaryMessageProtocol] ParseEnvelope failed: {e.Message}");
                return Array.Empty<byte>();
            }
        }

        #endregion

        #region Data Types

        [Serializable]
        public class ChunkHeader
        {
            public string transferId;
            public int totalSize;
            public int totalChunks;
            public int chunkSize;
        }

        [Serializable]
        public class ChunkData
        {
            public string transferId;
            public int index;
            public string data; // Base64
        }

        [Serializable]
        public class ChunkFooter
        {
            public string transferId;
            public long checksum;
        }

        [Serializable]
        private class BinaryEnvelope
        {
            public string dataType;
            public string data;
            public int size;
            public int compressedSize;
        }

        #endregion
    }
}
