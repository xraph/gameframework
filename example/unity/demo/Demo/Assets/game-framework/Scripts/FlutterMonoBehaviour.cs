using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Base class for Unity MonoBehaviours that communicate with Flutter.
    /// 
    /// Provides automatic message routing, typed serialization, binary data support,
    /// and high-performance messaging features.
    /// 
    /// <example>
    /// <code>
    /// public class GameManager : FlutterMonoBehaviour
    /// {
    ///     protected override string TargetName => "GameManager";
    ///     
    ///     [FlutterMethod("startGame")]
    ///     public void OnStartGame(GameConfig config)
    ///     {
    ///         Debug.Log($"Starting level {config.level}");
    ///     }
    ///     
    ///     [FlutterMethod("loadAsset", AcceptsBinary = true)]
    ///     public void OnLoadAsset(byte[] data)
    ///     {
    ///         ProcessAsset(data);
    ///     }
    /// }
    /// </code>
    /// </example>
    /// </summary>
    public abstract class FlutterMonoBehaviour : MonoBehaviour
    {
        #region Configuration

        /// <summary>
        /// The target name used for message routing.
        /// Messages from Flutter with this target will be routed to this behaviour.
        /// Default: GameObject name
        /// </summary>
        protected virtual string TargetName => gameObject.name;

        /// <summary>
        /// If true, this behaviour operates in singleton mode.
        /// Only one instance can receive messages for this target.
        /// Default: false
        /// </summary>
        protected virtual bool IsSingleton => false;

        /// <summary>
        /// Enable delta compression for outbound state messages.
        /// Only changed fields will be sent.
        /// Default: false
        /// </summary>
        protected bool EnableDeltaCompression { get; set; } = false;

        /// <summary>
        /// Enable batching for outbound messages.
        /// Messages will be coalesced and sent together.
        /// Default: false
        /// </summary>
        protected bool EnableBatching { get; set; } = false;

        /// <summary>
        /// Enable debug logging for message handling.
        /// Default: false
        /// </summary>
        protected bool EnableDebugLogging { get; set; } = false;

        #endregion

        #region State

        private bool _isRegistered = false;
        private Dictionary<string, object> _previousStates;
        private StringBuilder _stringBuilder;

        #endregion

        #region Unity Lifecycle

        /// <summary>
        /// Called when the behaviour awakes. Registers with MessageRouter.
        /// Override and call base.Awake() if you need custom initialization.
        /// </summary>
        protected virtual void Awake()
        {
            // Initialize state tracking for delta compression
            if (EnableDeltaCompression)
            {
                _previousStates = new Dictionary<string, object>();
            }

            // Register with message router
            RegisterWithRouter();

            // Allow derived classes to configure routing
            ConfigureRouting();
        }

        /// <summary>
        /// Called when the behaviour is destroyed. Unregisters from MessageRouter.
        /// Override and call base.OnDestroy() if you need custom cleanup.
        /// </summary>
        protected virtual void OnDestroy()
        {
            UnregisterFromRouter();

            // Return StringBuilder to pool
            if (_stringBuilder != null)
            {
                MessagePool.Instance?.ReturnStringBuilder(_stringBuilder);
                _stringBuilder = null;
            }
        }

        /// <summary>
        /// Called when the behaviour is enabled. Re-registers if needed.
        /// </summary>
        protected virtual void OnEnable()
        {
            if (!_isRegistered)
            {
                RegisterWithRouter();
            }
        }

        /// <summary>
        /// Called when the behaviour is disabled. Optionally unregisters.
        /// </summary>
        protected virtual void OnDisable()
        {
            // Keep registered by default to allow message queueing
        }

        #endregion

        #region Registration

        private void RegisterWithRouter()
        {
            if (_isRegistered) return;

            try
            {
                MessageRouter.Instance.Register(this, TargetName, IsSingleton);
                _isRegistered = true;

                if (EnableDebugLogging)
                {
                    Debug.Log($"[FlutterMonoBehaviour] Registered '{TargetName}' (Singleton: {IsSingleton})");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterMonoBehaviour] Failed to register '{TargetName}': {e.Message}");
            }
        }

        private void UnregisterFromRouter()
        {
            if (!_isRegistered) return;

            try
            {
                MessageRouter.Instance.Unregister(this, TargetName);
                _isRegistered = false;

                if (EnableDebugLogging)
                {
                    Debug.Log($"[FlutterMonoBehaviour] Unregistered '{TargetName}'");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterMonoBehaviour] Failed to unregister '{TargetName}': {e.Message}");
            }
        }

        #endregion

        #region Configuration Hooks

        /// <summary>
        /// Override to configure message routing, throttling, etc.
        /// Called after registration in Awake().
        /// </summary>
        protected virtual void ConfigureRouting()
        {
            // Override in derived classes
        }

        /// <summary>
        /// Set throttle rate for a specific method.
        /// </summary>
        /// <param name="methodName">The Flutter method name</param>
        /// <param name="rateHz">Maximum calls per second (0 = unlimited)</param>
        /// <param name="strategy">How to handle excess messages</param>
        protected void SetThrottle(string methodName, int rateHz, ThrottleStrategy strategy = ThrottleStrategy.KeepLatest)
        {
            MessageRouter.Instance.SetThrottle(TargetName, methodName, rateHz, strategy);
        }

        #endregion

        #region Send Messages to Flutter

        /// <summary>
        /// Send a string message to Flutter.
        /// </summary>
        /// <param name="method">The method name on Flutter side</param>
        /// <param name="data">String data to send</param>
        protected void SendToFlutter(string method, string data)
        {
            try
            {
                if (EnableBatching)
                {
                    MessageBatcher.Instance.QueueMessage(TargetName, method, data, MessageDataType.String);
                }
                else
                {
                    FlutterBridge.Instance.SendToFlutter(TargetName, method, data);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterMonoBehaviour] SendToFlutter failed: {e.Message}");
            }
        }

        /// <summary>
        /// Send a typed object to Flutter (JSON serialized).
        /// </summary>
        /// <typeparam name="T">Type of data to send</typeparam>
        /// <param name="method">The method name on Flutter side</param>
        /// <param name="data">Object to serialize and send</param>
        protected void SendToFlutter<T>(string method, T data) where T : class
        {
            try
            {
                string json;

                if (EnableDeltaCompression)
                {
                    json = CompressDelta(method, data);
                    if (json == null)
                    {
                        // No changes, skip sending
                        return;
                    }
                }
                else
                {
                    json = FlutterSerialization.Serialize(data);
                }

                if (EnableBatching)
                {
                    MessageBatcher.Instance.QueueMessage(TargetName, method, json, MessageDataType.Json);
                }
                else
                {
                    FlutterBridge.Instance.SendToFlutter(TargetName, method, json);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterMonoBehaviour] SendToFlutter<{typeof(T).Name}> failed: {e.Message}");
            }
        }

        /// <summary>
        /// Send a typed object using batching (queued for batch send).
        /// </summary>
        protected void SendToFlutterBatched<T>(string method, T data) where T : class
        {
            try
            {
                string json;

                if (EnableDeltaCompression)
                {
                    json = CompressDelta(method, data);
                    if (json == null) return;
                }
                else
                {
                    json = FlutterSerialization.Serialize(data);
                }

                MessageBatcher.Instance.QueueMessage(TargetName, method, json, MessageDataType.Json);
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterMonoBehaviour] SendToFlutterBatched failed: {e.Message}");
            }
        }

        /// <summary>
        /// Send binary data to Flutter (base64 encoded).
        /// </summary>
        /// <param name="method">The method name on Flutter side</param>
        /// <param name="data">Binary data to send</param>
        /// <param name="compress">Whether to compress the data</param>
        protected void SendBinaryToFlutter(string method, byte[] data, bool compress = false)
        {
            try
            {
                byte[] payload = data;

                if (compress && data.Length > 1024)
                {
                    payload = BinaryMessageProtocol.Compress(data);
                }

                string base64 = Convert.ToBase64String(payload);

                if (EnableBatching)
                {
                    var dataType = compress ? MessageDataType.CompressedBinary : MessageDataType.Binary;
                    MessageBatcher.Instance.QueueMessage(TargetName, method, base64, dataType);
                }
                else
                {
                    var envelope = new BinaryEnvelope
                    {
                        dataType = compress ? "compressedBinary" : "binary",
                        data = base64
                    };
                    string json = JsonUtility.ToJson(envelope);
                    FlutterBridge.Instance.SendToFlutter(TargetName, method, json);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterMonoBehaviour] SendBinaryToFlutter failed: {e.Message}");
            }
        }

        /// <summary>
        /// Send binary data with chunking for large payloads.
        /// </summary>
        /// <param name="method">The method name on Flutter side</param>
        /// <param name="data">Binary data to send</param>
        /// <param name="chunkSize">Size of each chunk in bytes (default: 64KB)</param>
        protected void SendBinaryChunked(string method, byte[] data, int chunkSize = 65536)
        {
            try
            {
                BinaryMessageProtocol.SendChunked(TargetName, method, data, chunkSize);
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterMonoBehaviour] SendBinaryChunked failed: {e.Message}");
            }
        }

        #endregion

        #region Delta Compression

        private string CompressDelta<T>(string key, T newState) where T : class
        {
            if (_previousStates == null)
            {
                _previousStates = new Dictionary<string, object>();
            }

            string fullKey = $"{TargetName}:{key}";

            if (!_previousStates.TryGetValue(fullKey, out object prevState))
            {
                // First time, send full state
                _previousStates[fullKey] = CloneState(newState);
                return FlutterSerialization.Serialize(newState);
            }

            // Compute delta
            string delta = FlutterSerialization.ComputeDelta(prevState, newState);

            if (string.IsNullOrEmpty(delta) || delta == "{}")
            {
                // No changes
                return null;
            }

            // Update stored state
            _previousStates[fullKey] = CloneState(newState);

            return delta;
        }

        private object CloneState<T>(T state) where T : class
        {
            // Simple clone via JSON round-trip
            string json = FlutterSerialization.Serialize(state);
            return JsonUtility.FromJson<T>(json);
        }

        /// <summary>
        /// Clear delta compression state for fresh sync.
        /// </summary>
        protected void ResetDeltaState()
        {
            _previousStates?.Clear();
        }

        /// <summary>
        /// Clear delta state for a specific method.
        /// </summary>
        protected void ResetDeltaState(string method)
        {
            string fullKey = $"{TargetName}:{method}";
            _previousStates?.Remove(fullKey);
        }

        #endregion

        #region Utility

        /// <summary>
        /// Get a pooled StringBuilder for efficient string operations.
        /// </summary>
        protected StringBuilder GetStringBuilder()
        {
            if (_stringBuilder == null)
            {
                _stringBuilder = MessagePool.Instance?.RentStringBuilder() ?? new StringBuilder(256);
            }
            _stringBuilder.Clear();
            return _stringBuilder;
        }

        /// <summary>
        /// Force flush any batched messages immediately.
        /// </summary>
        protected void FlushBatchedMessages()
        {
            MessageBatcher.Instance?.Flush();
        }

        #endregion

        #region Internal Types

        [Serializable]
        private class BinaryEnvelope
        {
            public string dataType;
            public string data;
        }

        #endregion
    }
}
