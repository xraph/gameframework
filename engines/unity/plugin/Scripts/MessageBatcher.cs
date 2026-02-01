using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Batches multiple messages for efficient transmission.
    /// 
    /// Reduces overhead by coalescing messages sent within a short time window
    /// into a single transmission. Essential for high-frequency updates like
    /// position synchronization at 60+ Hz.
    /// </summary>
    public class MessageBatcher : SingletonMonoBehaviour<MessageBatcher>
    {
        #region Configuration

        [Header("Batching Configuration")]
        [Tooltip("Maximum number of messages per batch")]
        [SerializeField] private int maxBatchSize = 50;

        [Tooltip("Maximum delay before auto-flush (milliseconds)")]
        [SerializeField] private float maxBatchDelayMs = 16f; // ~60fps

        [Tooltip("Enable batching (can be toggled at runtime)")]
        [SerializeField] private bool enableBatching = true;

        [Tooltip("Enable delta compression for repeated targets")]
        [SerializeField] private bool enableDeltaCompression = false;

        [Tooltip("Enable debug logging")]
        [SerializeField] private bool enableDebugLogging = false;

        #endregion

        #region State

        private readonly List<BatchedMessage> _pendingMessages = new List<BatchedMessage>();
        private readonly Dictionary<string, string> _lastValues = new Dictionary<string, string>();
        private readonly object _lock = new object();

        private float _lastFlushTime;
        private float _maxBatchDelaySeconds;
        private StringBuilder _batchBuilder;

        // Statistics
        private int _messagesBatched = 0;
        private int _batchesSent = 0;
        private int _messagesCoalesced = 0;

        #endregion

        #region Properties

        /// <summary>
        /// Enable or disable batching at runtime.
        /// </summary>
        public bool EnableBatching
        {
            get => enableBatching;
            set => enableBatching = value;
        }

        /// <summary>
        /// Maximum batch size.
        /// </summary>
        public int MaxBatchSize
        {
            get => maxBatchSize;
            set => maxBatchSize = Mathf.Max(1, value);
        }

        /// <summary>
        /// Maximum batch delay in milliseconds.
        /// </summary>
        public float MaxBatchDelayMs
        {
            get => maxBatchDelayMs;
            set
            {
                maxBatchDelayMs = Mathf.Max(1f, value);
                _maxBatchDelaySeconds = maxBatchDelayMs / 1000f;
            }
        }

        #endregion

        #region Initialization

        protected override void SingletonAwake()
        {
            base.SingletonAwake();

            _maxBatchDelaySeconds = maxBatchDelayMs / 1000f;
            _lastFlushTime = Time.unscaledTime;
            _batchBuilder = new StringBuilder(4096);

            Debug.Log($"[MessageBatcher] Initialized: MaxBatch={maxBatchSize}, MaxDelay={maxBatchDelayMs}ms");
        }

        void Update()
        {
            if (!enableBatching || _pendingMessages.Count == 0) return;

            // Check if we should auto-flush based on time
            float elapsed = Time.unscaledTime - _lastFlushTime;
            if (elapsed >= _maxBatchDelaySeconds)
            {
                Flush();
            }
        }

        void LateUpdate()
        {
            // Also flush at end of frame if any messages pending
            if (enableBatching && _pendingMessages.Count > 0)
            {
                Flush();
            }
        }

        #endregion

        #region Queue Messages

        /// <summary>
        /// Queue a message for batched transmission.
        /// </summary>
        /// <param name="target">Target component</param>
        /// <param name="method">Method name</param>
        /// <param name="data">Data payload</param>
        /// <param name="dataType">Type of data</param>
        public void QueueMessage(string target, string method, string data, MessageDataType dataType = MessageDataType.Json)
        {
            if (!enableBatching)
            {
                // Send immediately if batching disabled
                SendImmediate(target, method, data, dataType);
                return;
            }

            lock (_lock)
            {
                // Check for coalescing opportunity
                if (enableDeltaCompression)
                {
                    string key = $"{target}:{method}";
                    
                    // Check if this is a duplicate/update of existing queued message
                    for (int i = _pendingMessages.Count - 1; i >= 0; i--)
                    {
                        var existing = _pendingMessages[i];
                        if (existing.Target == target && existing.Method == method)
                        {
                            // Coalesce: replace with newer value
                            _pendingMessages[i] = new BatchedMessage
                            {
                                Target = target,
                                Method = method,
                                Data = data,
                                DataType = dataType,
                                Timestamp = Time.unscaledTime
                            };
                            _messagesCoalesced++;
                            return;
                        }
                    }
                }

                // Add new message
                _pendingMessages.Add(new BatchedMessage
                {
                    Target = target,
                    Method = method,
                    Data = data,
                    DataType = dataType,
                    Timestamp = Time.unscaledTime
                });

                _messagesBatched++;

                // Check if batch is full
                if (_pendingMessages.Count >= maxBatchSize)
                {
                    Flush();
                }
            }
        }

        /// <summary>
        /// Queue a binary message for batched transmission.
        /// </summary>
        public void QueueBinaryMessage(string target, string method, byte[] data, bool compress = false)
        {
            string base64 = Convert.ToBase64String(data);
            var dataType = compress ? MessageDataType.CompressedBinary : MessageDataType.Binary;
            QueueMessage(target, method, base64, dataType);
        }

        #endregion

        #region Flush

        /// <summary>
        /// Immediately flush all pending messages.
        /// </summary>
        public void Flush()
        {
            List<BatchedMessage> toSend;

            lock (_lock)
            {
                if (_pendingMessages.Count == 0) return;

                toSend = new List<BatchedMessage>(_pendingMessages);
                _pendingMessages.Clear();
                _lastFlushTime = Time.unscaledTime;
            }

            if (toSend.Count == 1)
            {
                // Single message - send directly
                var msg = toSend[0];
                SendImmediate(msg.Target, msg.Method, msg.Data, msg.DataType);
            }
            else
            {
                // Multiple messages - send as batch
                SendBatch(toSend);
            }

            _batchesSent++;

            if (enableDebugLogging)
            {
                Debug.Log($"[MessageBatcher] Flushed {toSend.Count} messages");
            }
        }

        private void SendImmediate(string target, string method, string data, MessageDataType dataType)
        {
            try
            {
                if (dataType == MessageDataType.Binary || dataType == MessageDataType.CompressedBinary)
                {
                    // Wrap binary in envelope
                    var envelope = new BinaryEnvelope
                    {
                        dataType = dataType == MessageDataType.CompressedBinary ? "compressedBinary" : "binary",
                        data = data
                    };
                    FlutterBridge.Instance.SendToFlutter(target, method, JsonUtility.ToJson(envelope));
                }
                else
                {
                    FlutterBridge.Instance.SendToFlutter(target, method, data);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[MessageBatcher] SendImmediate failed: {e.Message}");
            }
        }

        private void SendBatch(List<BatchedMessage> messages)
        {
            try
            {
                _batchBuilder.Clear();
                _batchBuilder.Append("{\"batch\":true,\"count\":");
                _batchBuilder.Append(messages.Count);
                _batchBuilder.Append(",\"messages\":[");

                for (int i = 0; i < messages.Count; i++)
                {
                    if (i > 0) _batchBuilder.Append(",");

                    var msg = messages[i];
                    _batchBuilder.Append("{\"t\":\"");
                    _batchBuilder.Append(EscapeJson(msg.Target));
                    _batchBuilder.Append("\",\"m\":\"");
                    _batchBuilder.Append(EscapeJson(msg.Method));
                    _batchBuilder.Append("\",\"dt\":\"");
                    _batchBuilder.Append(GetDataTypeString(msg.DataType));
                    _batchBuilder.Append("\",\"d\":");

                    // Handle data based on type
                    if (msg.DataType == MessageDataType.Json)
                    {
                        // JSON data - include directly (already JSON)
                        if (string.IsNullOrEmpty(msg.Data))
                        {
                            _batchBuilder.Append("null");
                        }
                        else if (msg.Data.StartsWith("{") || msg.Data.StartsWith("["))
                        {
                            _batchBuilder.Append(msg.Data);
                        }
                        else
                        {
                            _batchBuilder.Append("\"");
                            _batchBuilder.Append(EscapeJson(msg.Data));
                            _batchBuilder.Append("\"");
                        }
                    }
                    else
                    {
                        // String or binary data - wrap in quotes
                        _batchBuilder.Append("\"");
                        _batchBuilder.Append(EscapeJson(msg.Data ?? ""));
                        _batchBuilder.Append("\"");
                    }

                    _batchBuilder.Append("}");
                }

                _batchBuilder.Append("]}");

                // Send batch to Flutter
                FlutterBridge.Instance.SendToFlutter("_batch", "onBatch", _batchBuilder.ToString());
            }
            catch (Exception e)
            {
                Debug.LogError($"[MessageBatcher] SendBatch failed: {e.Message}");

                // Fallback: send individually
                foreach (var msg in messages)
                {
                    SendImmediate(msg.Target, msg.Method, msg.Data, msg.DataType);
                }
            }
        }

        private string GetDataTypeString(MessageDataType dataType)
        {
            switch (dataType)
            {
                case MessageDataType.String: return "s";
                case MessageDataType.Json: return "j";
                case MessageDataType.Binary: return "b";
                case MessageDataType.CompressedBinary: return "cb";
                default: return "s";
            }
        }

        private string EscapeJson(string value)
        {
            if (string.IsNullOrEmpty(value)) return "";

            // Simple JSON escaping
            return value
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\n", "\\n")
                .Replace("\r", "\\r")
                .Replace("\t", "\\t");
        }

        #endregion

        #region Statistics

        /// <summary>
        /// Get batching statistics.
        /// </summary>
        public BatcherStatistics GetStatistics()
        {
            return new BatcherStatistics
            {
                MessagesBatched = _messagesBatched,
                BatchesSent = _batchesSent,
                MessagesCoalesced = _messagesCoalesced,
                PendingMessages = _pendingMessages.Count,
                AverageMessagesPerBatch = _batchesSent > 0 ? (float)_messagesBatched / _batchesSent : 0f
            };
        }

        /// <summary>
        /// Reset statistics counters.
        /// </summary>
        public void ResetStatistics()
        {
            _messagesBatched = 0;
            _batchesSent = 0;
            _messagesCoalesced = 0;
        }

        /// <summary>
        /// Get count of pending messages.
        /// </summary>
        public int PendingCount
        {
            get { lock (_lock) { return _pendingMessages.Count; } }
        }

        #endregion

        #region Internal Types

        private struct BatchedMessage
        {
            public string Target;
            public string Method;
            public string Data;
            public MessageDataType DataType;
            public float Timestamp;
        }

        [Serializable]
        private class BinaryEnvelope
        {
            public string dataType;
            public string data;
        }

        #endregion
    }

    /// <summary>
    /// Batcher statistics for monitoring.
    /// </summary>
    [Serializable]
    public struct BatcherStatistics
    {
        public int MessagesBatched;
        public int BatchesSent;
        public int MessagesCoalesced;
        public int PendingMessages;
        public float AverageMessagesPerBatch;

        public override string ToString()
        {
            return $"Batched={MessagesBatched}, Sent={BatchesSent}, Coalesced={MessagesCoalesced}, " +
                   $"Pending={PendingMessages}, Avg/Batch={AverageMessagesPerBatch:F1}";
        }
    }
}
