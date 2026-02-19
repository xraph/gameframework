using System;
using UnityEngine;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Demonstrates binary data transfer between Flutter and Unity.
    /// 
    /// Features:
    /// - Receiving binary data (images, files, etc.)
    /// - Sending binary data back to Flutter
    /// - Chunked transfer for large files
    /// - Compression support
    /// 
    /// Flutter usage:
    /// ```dart
    /// // Send binary data
    /// final imageBytes = await File('image.png').readAsBytes();
    /// await controller.sendBinaryMessage('BinaryData', 'receiveImage', imageBytes);
    /// 
    /// // Request binary data
    /// await controller.sendJsonMessage('BinaryData', 'requestScreenshot', {});
    /// 
    /// // Listen for binary responses
    /// controller.messageStream.listen((msg) {
    ///   if (msg.method == 'onScreenshot') {
    ///     final data = jsonDecode(msg.data);
    ///     final bytes = base64Decode(data['data']);
    ///   }
    /// });
    /// ```
    /// </summary>
    public class BinaryDataExample : FlutterMonoBehaviour
    {
        protected override string TargetName => "BinaryData";

        [Header("Binary Settings")]
        [SerializeField] private int maxTextureSize = 2048;
        [SerializeField] private bool enableCompression = true;

        private Texture2D _lastReceivedTexture;

        #region Receiving Binary Data

        /// <summary>
        /// Receive raw binary data from Flutter.
        /// </summary>
        [FlutterMethod("receiveData", AcceptsBinary = true)]
        public void ReceiveData(byte[] data)
        {
            Debug.Log($"[BinaryData] Received {data.Length} bytes");

            // Process the data (example: compute hash)
            int hash = ComputeSimpleHash(data);

            SendToFlutter("onDataReceived", new DataReceivedEvent
            {
                size = data.Length,
                hash = hash,
                timestamp = DateTime.UtcNow.ToString("o")
            });
        }

        /// <summary>
        /// Receive image data and create a texture.
        /// </summary>
        [FlutterMethod("receiveImage", AcceptsBinary = true)]
        public void ReceiveImage(byte[] imageData)
        {
            Debug.Log($"[BinaryData] Received image: {imageData.Length} bytes");

            try
            {
                // Create texture from image data
                _lastReceivedTexture = new Texture2D(2, 2);
                bool loaded = _lastReceivedTexture.LoadImage(imageData);

                if (loaded)
                {
                    Debug.Log($"[BinaryData] Texture loaded: {_lastReceivedTexture.width}x{_lastReceivedTexture.height}");

                    SendToFlutter("onImageReceived", new ImageReceivedEvent
                    {
                        success = true,
                        width = _lastReceivedTexture.width,
                        height = _lastReceivedTexture.height,
                        format = _lastReceivedTexture.format.ToString()
                    });
                }
                else
                {
                    SendToFlutter("onImageReceived", new ImageReceivedEvent
                    {
                        success = false,
                        error = "Failed to load image data"
                    });
                }
            }
            catch (Exception e)
            {
                SendToFlutter("onImageReceived", new ImageReceivedEvent
                {
                    success = false,
                    error = e.Message
                });
            }
        }

        /// <summary>
        /// Receive file data with metadata.
        /// </summary>
        [FlutterMethod("receiveFile", AcceptsBinary = true)]
        public void ReceiveFile(byte[] fileData)
        {
            Debug.Log($"[BinaryData] Received file: {fileData.Length} bytes");

            // In a real app, you might save this to disk or process it
            // For demo, just acknowledge receipt

            SendToFlutter("onFileReceived", new FileReceivedEvent
            {
                success = true,
                size = fileData.Length,
                checksum = BinaryMessageProtocol.ComputeChecksum(fileData)
            });
        }

        #endregion

        #region Sending Binary Data

        /// <summary>
        /// Send binary data to Flutter.
        /// </summary>
        [FlutterMethod("requestData")]
        public void RequestData(DataRequest request)
        {
            Debug.Log($"[BinaryData] Data request: {request.size} bytes");

            // Generate test data
            byte[] data = GenerateTestData(request.size);

            // Send with optional compression
            SendBinaryToFlutter("onData", data, enableCompression && request.compress);
        }

        /// <summary>
        /// Capture and send a screenshot.
        /// </summary>
        [FlutterMethod("requestScreenshot")]
        public void RequestScreenshot()
        {
            Debug.Log("[BinaryData] Screenshot requested");

            // Note: ScreenCapture requires end of frame
            StartCoroutine(CaptureAndSendScreenshot());
        }

        private System.Collections.IEnumerator CaptureAndSendScreenshot()
        {
            yield return new WaitForEndOfFrame();

            try
            {
                // Capture screenshot
                Texture2D screenshot = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
                screenshot.ReadPixels(new Rect(0, 0, Screen.width, Screen.height), 0, 0);
                screenshot.Apply();

                // Encode to PNG
                byte[] pngData = screenshot.EncodeToPNG();
                Destroy(screenshot);

                Debug.Log($"[BinaryData] Screenshot captured: {pngData.Length} bytes");

                // Send to Flutter
                SendBinaryToFlutter("onScreenshot", pngData, enableCompression);
            }
            catch (Exception e)
            {
                Debug.LogError($"[BinaryData] Screenshot failed: {e.Message}");
                SendToFlutter("onScreenshotError", new { error = e.Message });
            }
        }

        /// <summary>
        /// Send the last received texture back.
        /// </summary>
        [FlutterMethod("requestTexture")]
        public void RequestTexture(TextureRequest request)
        {
            if (_lastReceivedTexture == null)
            {
                SendToFlutter("onTextureError", new { error = "No texture available" });
                return;
            }

            try
            {
                byte[] data;
                
                switch (request.format?.ToLower())
                {
                    case "jpg":
                    case "jpeg":
                        data = _lastReceivedTexture.EncodeToJPG(request.quality);
                        break;
                    default:
                        data = _lastReceivedTexture.EncodeToPNG();
                        break;
                }

                SendBinaryToFlutter("onTexture", data, enableCompression);
            }
            catch (Exception e)
            {
                SendToFlutter("onTextureError", new { error = e.Message });
            }
        }

        #endregion

        #region Chunked Transfer

        /// <summary>
        /// Send large data using chunked transfer.
        /// </summary>
        [FlutterMethod("requestLargeData")]
        public void RequestLargeData(LargeDataRequest request)
        {
            Debug.Log($"[BinaryData] Large data request: {request.size} bytes");

            // Generate large test data
            byte[] data = GenerateTestData(request.size);

            // Send using chunked protocol
            int chunkSize = request.chunkSize > 0 ? request.chunkSize : 65536;
            SendBinaryChunked("onLargeData", data, chunkSize);
        }

        #endregion

        #region Utility

        private byte[] GenerateTestData(int size)
        {
            byte[] data = new byte[size];
            System.Random random = new System.Random();

            for (int i = 0; i < size; i++)
            {
                data[i] = (byte)random.Next(256);
            }

            return data;
        }

        private int ComputeSimpleHash(byte[] data)
        {
            int hash = 0;
            for (int i = 0; i < data.Length; i++)
            {
                hash = (hash * 31) + data[i];
            }
            return hash;
        }

        #endregion

        #region Data Types

        [Serializable]
        public class DataReceivedEvent
        {
            public int size;
            public int hash;
            public string timestamp;
        }

        [Serializable]
        public class ImageReceivedEvent
        {
            public bool success;
            public int width;
            public int height;
            public string format;
            public string error;
        }

        [Serializable]
        public class FileReceivedEvent
        {
            public bool success;
            public int size;
            public long checksum;
        }

        [Serializable]
        public class DataRequest
        {
            public int size;
            public bool compress;
        }

        [Serializable]
        public class TextureRequest
        {
            public string format;
            public int quality;
        }

        [Serializable]
        public class LargeDataRequest
        {
            public int size;
            public int chunkSize;
        }

        #endregion
    }
}
