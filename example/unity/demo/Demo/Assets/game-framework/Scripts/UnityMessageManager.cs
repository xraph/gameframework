using System;
using System.Collections.Generic;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Centralized message manager for Unity-Flutter communication
    /// 
    /// Provides a high-level API with callbacks, type safety, and message routing.
    /// Singleton pattern ensures consistent communication channel.
    /// 
    /// Usage:
    /// <code>
    /// UnityMessageManager.Instance.SendToFlutter("target", "method", data);
    /// UnityMessageManager.Instance.AddEventListener("event", HandleEvent);
    /// </code>
    /// </summary>
    public class UnityMessageManager : SingletonMonoBehaviour<UnityMessageManager>
    {
        private Dictionary<int, Action<string>> _messageCallbacks = new Dictionary<int, Action<string>>();
        private Dictionary<string, List<Action<string>>> _eventListeners = new Dictionary<string, List<Action<string>>>();
        private int _nextCallbackId = 0;
        private Queue<Action> _executionQueue = new Queue<Action>();
        private readonly object _queueLock = new object();

        /// <summary>
        /// Initialize the singleton instance
        /// Called automatically by SingletonMonoBehaviour
        /// </summary>
        protected override void SingletonAwake()
        {
            base.SingletonAwake();

            // Initialize NativeAPI
            NativeAPI.Initialize();

            // Subscribe to NativeAPI events
            NativeAPI.OnMessageReceived += HandleNativeMessage;
            NativeAPI.OnUnityReady += HandleUnityReady;
            NativeAPI.OnUnityPaused += HandleUnityPaused;
            NativeAPI.OnSceneLoaded += HandleSceneLoaded;

            Debug.Log("UnityMessageManager: Initialized");
        }

        protected override void OnDestroy()
        {
            // Unsubscribe from events
            NativeAPI.OnMessageReceived -= HandleNativeMessage;
            NativeAPI.OnUnityReady -= HandleUnityReady;
            NativeAPI.OnUnityPaused -= HandleUnityPaused;
            NativeAPI.OnSceneLoaded -= HandleSceneLoaded;
            
            base.OnDestroy();
        }

        void Update()
        {
            // Process queued actions on main thread
            lock (_queueLock)
            {
                while (_executionQueue.Count > 0)
                {
                    Action action = _executionQueue.Dequeue();
                    try
                    {
                        action?.Invoke();
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"UnityMessageManager: Error executing queued action: {e.Message}\n{e.StackTrace}");
                    }
                }
            }
        }

        /// <summary>
        /// Send a message to Flutter
        /// </summary>
        /// <param name="target">Target component in Flutter</param>
        /// <param name="method">Method to invoke</param>
        /// <param name="data">Data to send (will be JSON serialized if object)</param>
        public void SendToFlutter(string target, string method, string data)
        {
            if (string.IsNullOrEmpty(target) || string.IsNullOrEmpty(method))
            {
                Debug.LogError("UnityMessageManager: Target and method cannot be null or empty");
                return;
            }

            NativeAPI.SendMessageToFlutter(target, method, data);
        }

        /// <summary>
        /// Send a typed object to Flutter
        /// </summary>
        public void SendToFlutter<T>(string target, string method, T data) where T : class
        {
            string json = JsonUtility.ToJson(data);
            SendToFlutter(target, method, json);
        }

        /// <summary>
        /// Send a message to Flutter with a callback
        /// </summary>
        /// <param name="target">Target component</param>
        /// <param name="method">Method to invoke</param>
        /// <param name="data">Data to send</param>
        /// <param name="callback">Callback to invoke when response is received</param>
        /// <returns>Callback ID for tracking</returns>
        public int SendToFlutterWithCallback(string target, string method, string data, Action<string> callback)
        {
            int callbackId = _nextCallbackId++;
            _messageCallbacks[callbackId] = callback;

            var message = new MessageWithCallback
            {
                target = target,
                method = method,
                data = data,
                callbackId = callbackId
            };

            string json = JsonUtility.ToJson(message);
            NativeAPI.SendMessageToFlutter(json);

            return callbackId;
        }

        /// <summary>
        /// Handle callback response from Flutter
        /// </summary>
        /// <param name="callbackId">ID of the callback</param>
        /// <param name="data">Response data</param>
        public void HandleCallbackResponse(int callbackId, string data)
        {
            if (_messageCallbacks.TryGetValue(callbackId, out Action<string> callback))
            {
                QueueAction(() =>
                {
                    try
                    {
                        callback?.Invoke(data);
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"UnityMessageManager: Error in callback {callbackId}: {e.Message}");
                    }
                    finally
                    {
                        _messageCallbacks.Remove(callbackId);
                    }
                });
            }
            else
            {
                Debug.LogWarning($"UnityMessageManager: No callback found for ID {callbackId}");
            }
        }

        /// <summary>
        /// Register an event listener
        /// </summary>
        /// <param name="eventName">Name of the event</param>
        /// <param name="listener">Listener callback</param>
        public void AddEventListener(string eventName, Action<string> listener)
        {
            if (string.IsNullOrEmpty(eventName) || listener == null)
            {
                Debug.LogError("UnityMessageManager: Event name and listener cannot be null");
                return;
            }

            if (!_eventListeners.ContainsKey(eventName))
            {
                _eventListeners[eventName] = new List<Action<string>>();
            }

            if (!_eventListeners[eventName].Contains(listener))
            {
                _eventListeners[eventName].Add(listener);
                Debug.Log($"UnityMessageManager: Added listener for event '{eventName}'");
            }
        }

        /// <summary>
        /// Unregister an event listener
        /// </summary>
        public void RemoveEventListener(string eventName, Action<string> listener)
        {
            if (_eventListeners.ContainsKey(eventName))
            {
                _eventListeners[eventName].Remove(listener);
                Debug.Log($"UnityMessageManager: Removed listener for event '{eventName}'");
            }
        }

        /// <summary>
        /// Trigger an event to all listeners
        /// </summary>
        public void TriggerEvent(string eventName, string data)
        {
            if (_eventListeners.TryGetValue(eventName, out List<Action<string>> listeners))
            {
                QueueAction(() =>
                {
                    foreach (var listener in listeners)
                    {
                        try
                        {
                            listener?.Invoke(data);
                        }
                        catch (Exception e)
                        {
                            Debug.LogError($"UnityMessageManager: Error in event listener for '{eventName}': {e.Message}");
                        }
                    }
                });
            }
        }

        /// <summary>
        /// Queue an action to be executed on the main thread
        /// </summary>
        private void QueueAction(Action action)
        {
            lock (_queueLock)
            {
                _executionQueue.Enqueue(action);
            }
        }

        /// <summary>
        /// Handle native message from Flutter
        /// </summary>
        private void HandleNativeMessage(string message)
        {
            QueueAction(() =>
            {
                try
                {
                    // Try to parse as a callback response first
                    var callbackResponse = JsonUtility.FromJson<CallbackResponse>(message);
                    if (callbackResponse != null && callbackResponse.callbackId >= 0)
                    {
                        HandleCallbackResponse(callbackResponse.callbackId, callbackResponse.data);
                        return;
                    }

                    // Parse as regular message
                    var messageData = JsonUtility.FromJson<MessageData>(message);
                    if (messageData != null)
                    {
                        TriggerEvent($"{messageData.target}:{messageData.method}", messageData.data);
                    }
                }
                catch (Exception e)
                {
                    Debug.LogError($"UnityMessageManager: Error handling message: {e.Message}\n{e.StackTrace}");
                }
            });
        }

        /// <summary>
        /// Handle Unity ready event
        /// </summary>
        private void HandleUnityReady()
        {
            QueueAction(() =>
            {
                TriggerEvent("Unity:Ready", "true");
            });
        }

        /// <summary>
        /// Handle Unity paused event
        /// </summary>
        private void HandleUnityPaused(bool isPaused)
        {
            QueueAction(() =>
            {
                TriggerEvent("Unity:Paused", isPaused.ToString().ToLower());
            });
        }

        /// <summary>
        /// Handle scene loaded event
        /// </summary>
        private void HandleSceneLoaded(string sceneName, int buildIndex)
        {
            QueueAction(() =>
            {
                var data = new SceneData
                {
                    name = sceneName,
                    buildIndex = buildIndex
                };
                string json = JsonUtility.ToJson(data);
                TriggerEvent("Unity:SceneLoaded", json);
            });
        }

        /// <summary>
        /// Notify Flutter that Unity is ready
        /// Call this after your Unity scene is fully loaded
        /// </summary>
        public void NotifyReady()
        {
            NativeAPI.NotifyUnityReady();
        }

        // Data structures

        [Serializable]
        private class MessageData
        {
            public string target;
            public string method;
            public string data;
        }

        [Serializable]
        private class MessageWithCallback
        {
            public string target;
            public string method;
            public string data;
            public int callbackId;
        }

        [Serializable]
        private class CallbackResponse
        {
            public int callbackId;
            public string data;
        }

        [Serializable]
        private class SceneData
        {
            public string name;
            public int buildIndex;
        }
    }
}

