using System;
using System.Collections.Generic;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Type-safe message handler for Unity-Flutter communication
    /// 
    /// Provides structured message handling with automatic deserialization,
    /// validation, and routing. Use this for complex message flows.
    /// </summary>
    public class MessageHandler : MonoBehaviour
    {
        [Header("Configuration")]
        [Tooltip("Enable detailed logging for debugging")]
        public bool enableDebugLogging = false;

        [Tooltip("Maximum message queue size")]
        public int maxQueueSize = 100;

        private Dictionary<string, Action<object>> _handlers = new Dictionary<string, Action<object>>();
        private Queue<PendingMessage> _messageQueue = new Queue<PendingMessage>();
        private bool _isProcessing = false;

        void Start()
        {
            // Register with UnityMessageManager
            RegisterDefaultHandlers();
            Debug.Log("MessageHandler: Initialized");
        }

        /// <summary>
        /// Register a typed message handler
        /// </summary>
        /// <typeparam name="T">Type of the message data</typeparam>
        /// <param name="messageType">Message type identifier</param>
        /// <param name="handler">Handler callback</param>
        public void RegisterHandler<T>(string messageType, Action<T> handler) where T : class
        {
            if (string.IsNullOrEmpty(messageType))
            {
                Debug.LogError("MessageHandler: Message type cannot be null or empty");
                return;
            }

            if (handler == null)
            {
                Debug.LogError("MessageHandler: Handler cannot be null");
                return;
            }

            _handlers[messageType] = (data) =>
            {
                try
                {
                    T typedData = data as T;
                    if (typedData == null && data is string stringData)
                    {
                        // Try to deserialize from JSON
                        typedData = JsonUtility.FromJson<T>(stringData);
                    }

                    if (typedData != null)
                    {
                        handler(typedData);
                    }
                    else
                    {
                        Debug.LogError($"MessageHandler: Failed to cast data to {typeof(T).Name} for message type '{messageType}'");
                    }
                }
                catch (Exception e)
                {
                    Debug.LogError($"MessageHandler: Error in handler for '{messageType}': {e.Message}\n{e.StackTrace}");
                }
            };

            if (enableDebugLogging)
            {
                Debug.Log($"MessageHandler: Registered handler for '{messageType}' with type {typeof(T).Name}");
            }
        }

        /// <summary>
        /// Unregister a message handler
        /// </summary>
        public void UnregisterHandler(string messageType)
        {
            if (_handlers.ContainsKey(messageType))
            {
                _handlers.Remove(messageType);
                if (enableDebugLogging)
                {
                    Debug.Log($"MessageHandler: Unregistered handler for '{messageType}'");
                }
            }
        }

        /// <summary>
        /// Handle an incoming message
        /// </summary>
        public void HandleMessage(string messageType, string data)
        {
            if (string.IsNullOrEmpty(messageType))
            {
                Debug.LogError("MessageHandler: Message type cannot be null or empty");
                return;
            }

            if (_messageQueue.Count >= maxQueueSize)
            {
                Debug.LogWarning($"MessageHandler: Message queue full ({maxQueueSize}), dropping oldest message");
                _messageQueue.Dequeue();
            }

            _messageQueue.Enqueue(new PendingMessage
            {
                messageType = messageType,
                data = data,
                timestamp = Time.time
            });

            if (!_isProcessing)
            {
                ProcessMessageQueue();
            }
        }

        /// <summary>
        /// Process the message queue
        /// </summary>
        private void ProcessMessageQueue()
        {
            _isProcessing = true;

            while (_messageQueue.Count > 0)
            {
                PendingMessage pending = _messageQueue.Dequeue();

                if (enableDebugLogging)
                {
                    Debug.Log($"MessageHandler: Processing message '{pending.messageType}' (age: {Time.time - pending.timestamp:F3}s)");
                }

                if (_handlers.TryGetValue(pending.messageType, out Action<object> handler))
                {
                    try
                    {
                        handler(pending.data);
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"MessageHandler: Error processing message '{pending.messageType}': {e.Message}\n{e.StackTrace}");
                    }
                }
                else
                {
                    if (enableDebugLogging)
                    {
                        Debug.LogWarning($"MessageHandler: No handler registered for message type '{pending.messageType}'");
                    }
                }
            }

            _isProcessing = false;
        }

        /// <summary>
        /// Send a typed message to Flutter
        /// </summary>
        public void SendMessage<T>(string target, string method, T data) where T : class
        {
            try
            {
                UnityMessageManager.Instance.SendToFlutter(target, method, data);
            }
            catch (Exception e)
            {
                Debug.LogError($"MessageHandler: Error sending message: {e.Message}");
            }
        }

        /// <summary>
        /// Send a message to Flutter and wait for response
        /// </summary>
        public void SendMessageWithResponse<TRequest, TResponse>(
            string target,
            string method,
            TRequest requestData,
            Action<TResponse> responseHandler)
            where TRequest : class
            where TResponse : class
        {
            try
            {
                string requestJson = JsonUtility.ToJson(requestData);

                UnityMessageManager.Instance.SendToFlutterWithCallback(target, method, requestJson, (responseJson) =>
                {
                    try
                    {
                        TResponse response = JsonUtility.FromJson<TResponse>(responseJson);
                        responseHandler?.Invoke(response);
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"MessageHandler: Error parsing response: {e.Message}");
                    }
                });
            }
            catch (Exception e)
            {
                Debug.LogError($"MessageHandler: Error sending message with response: {e.Message}");
            }
        }

        /// <summary>
        /// Register default handlers for common message types
        /// </summary>
        private void RegisterDefaultHandlers()
        {
            // Listen to UnityMessageManager events
            UnityMessageManager.Instance.AddEventListener("Unity:Ready", (data) =>
            {
                if (enableDebugLogging)
                {
                    Debug.Log("MessageHandler: Unity ready");
                }
            });

            UnityMessageManager.Instance.AddEventListener("Unity:Paused", (data) =>
            {
                if (enableDebugLogging)
                {
                    Debug.Log($"MessageHandler: Unity paused: {data}");
                }
            });

            UnityMessageManager.Instance.AddEventListener("Unity:SceneLoaded", (data) =>
            {
                if (enableDebugLogging)
                {
                    Debug.Log($"MessageHandler: Scene loaded: {data}");
                }
            });
        }

        /// <summary>
        /// Clear all registered handlers
        /// </summary>
        public void ClearHandlers()
        {
            _handlers.Clear();
            Debug.Log("MessageHandler: All handlers cleared");
        }

        /// <summary>
        /// Get count of registered handlers
        /// </summary>
        public int GetHandlerCount()
        {
            return _handlers.Count;
        }

        /// <summary>
        /// Get current queue size
        /// </summary>
        public int GetQueueSize()
        {
            return _messageQueue.Count;
        }

        // Helper structures

        private struct PendingMessage
        {
            public string messageType;
            public string data;
            public float timestamp;
        }

        // Common message types for convenience

        [Serializable]
        public class GameStateMessage
        {
            public bool isPlaying;
            public bool isPaused;
            public int score;
            public int level;
            public float health;
        }

        [Serializable]
        public class PlayerActionMessage
        {
            public string action;
            public float x;
            public float y;
            public float z;
            public Dictionary<string, string> parameters;
        }

        [Serializable]
        public class EventMessage
        {
            public string eventType;
            public string eventName;
            public float timestamp;
            public string data;
        }

        [Serializable]
        public class ResponseMessage
        {
            public bool success;
            public string message;
            public string data;
        }
    }
}

