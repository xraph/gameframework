using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Bridge between Unity and Flutter
    ///
    /// This component enables bidirectional communication between Unity and Flutter.
    /// Add this to a GameObject in your Unity scene and mark it as DontDestroyOnLoad.
    /// 
    /// Messages are automatically routed to FlutterMonoBehaviour instances via MessageRouter.
    /// Legacy GameObject.SendMessage fallback is supported for backward compatibility.
    /// </summary>
    public class FlutterBridge : MonoBehaviour
    {
        private static FlutterBridge _instance;

        /// <summary>
        /// Singleton instance of the FlutterBridge
        /// </summary>
        public static FlutterBridge Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = FindObjectOfType<FlutterBridge>();
                    if (_instance == null)
                    {
                        GameObject go = new GameObject("FlutterBridge");
                        _instance = go.AddComponent<FlutterBridge>();
                        DontDestroyOnLoad(go);
                    }
                }
                return _instance;
            }
        }

        /// <summary>
        /// Event triggered when a message is received from Flutter.
        /// Subscribe to this event for custom message handling.
        /// Note: Messages are also automatically routed via MessageRouter.
        /// </summary>
        public static event Action<string, string, string> OnFlutterMessage;

        /// <summary>
        /// Event triggered when a binary message is received from Flutter.
        /// </summary>
        public static event Action<string, string, byte[]> OnFlutterBinaryMessage;

        /// <summary>
        /// Enable debug logging for all messages
        /// </summary>
        [SerializeField] private bool enableDebugLogging = false;

        /// <summary>
        /// Enable/disable debug logging at runtime
        /// </summary>
        public bool EnableDebugLogging
        {
            get => enableDebugLogging;
            set => enableDebugLogging = value;
        }

        void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);
            Debug.Log("[FlutterBridge] Initialized");
        }

        /// <summary>
        /// Called from Flutter to send a message to Unity.
        /// This method is called via UnitySendMessage.
        /// </summary>
        /// <param name="message">JSON message containing target, method, and data</param>
        public void ReceiveMessage(string message)
        {
            try
            {
                if (enableDebugLogging)
                {
                    Debug.Log($"[FlutterBridge] Received: {TruncateForLog(message)}");
                }

                // Check for batch message
                if (message.Contains("\"batch\":true"))
                {
                    HandleBatchMessage(message);
                    return;
                }

                // Parse the message (expecting JSON format)
                var messageData = JsonUtility.FromJson<FlutterMessage>(message);

                if (messageData != null)
                {
                    ProcessMessage(messageData.target, messageData.method, messageData.data, messageData.dataType);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterBridge] Error receiving message: {e.Message}\n{e.StackTrace}");
                SendError($"Failed to receive message: {e.Message}");
            }
        }

        /// <summary>
        /// Process a single message (from direct call or batch).
        /// </summary>
        private void ProcessMessage(string target, string method, string data, string dataType = null)
        {
            // Trigger event for legacy listeners
            OnFlutterMessage?.Invoke(target, method, data);

            // Handle binary data
            if (dataType == "binary" || dataType == "b" || 
                dataType == "compressedBinary" || dataType == "cb")
            {
                HandleBinaryMessage(target, method, data, dataType);
                return;
            }

            // Route via MessageRouter (handles FlutterMonoBehaviour and fallback)
            // MessageRouter is subscribed to OnFlutterMessage event
        }

        /// <summary>
        /// Handle binary message (base64 encoded).
        /// </summary>
        private void HandleBinaryMessage(string target, string method, string data, string dataType)
        {
            try
            {
                byte[] binaryData = Convert.FromBase64String(data);

                // Decompress if needed
                if (dataType == "compressedBinary" || dataType == "cb")
                {
                    binaryData = BinaryMessageProtocol.Decompress(binaryData);
                }

                // Trigger binary event
                OnFlutterBinaryMessage?.Invoke(target, method, binaryData);

                if (enableDebugLogging)
                {
                    Debug.Log($"[FlutterBridge] Binary message: {target}:{method}, {binaryData.Length} bytes");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterBridge] Binary decode failed: {e.Message}");
            }
        }

        /// <summary>
        /// Handle batch message containing multiple messages.
        /// </summary>
        private void HandleBatchMessage(string message)
        {
            try
            {
                var batch = JsonUtility.FromJson<BatchMessage>(message);
                if (batch == null || batch.messages == null) return;

                if (enableDebugLogging)
                {
                    Debug.Log($"[FlutterBridge] Processing batch of {batch.count} messages");
                }

                foreach (var msg in batch.messages)
                {
                    ProcessMessage(msg.t, msg.m, msg.d, msg.dt);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterBridge] Batch processing failed: {e.Message}");
            }
        }

        /// <summary>
        /// Handle incoming messages from Flutter.
        /// Override this method to add custom message handling.
        /// Note: MessageRouter handles routing automatically via OnFlutterMessage event.
        /// </summary>
        protected virtual void HandleMessage(string target, string method, string data)
        {
            if (enableDebugLogging)
            {
                Debug.Log($"[FlutterBridge] HandleMessage - Target: {target}, Method: {method}");
            }

            // Fallback to GameObject.SendMessage for backward compatibility
            // This is now primarily handled by MessageRouter
            GameObject targetObject = GameObject.Find(target);
            if (targetObject != null)
            {
                targetObject.SendMessage(method, data, SendMessageOptions.DontRequireReceiver);
            }
            else
            {
                // Provide helpful debugging information
                LogTargetNotFoundError(target, method);
            }
        }

        /// <summary>
        /// Log a helpful error message when target GameObject is not found.
        /// Includes suggestions for fixing the issue.
        /// </summary>
        private void LogTargetNotFoundError(string target, string method)
        {
            var message = new System.Text.StringBuilder();
            message.AppendLine($"[FlutterBridge] GameObject '{target}' not found for method '{method}'!");
            message.AppendLine();
            message.AppendLine("Fix options:");
            message.AppendLine($"  1. Create a GameObject named '{target}' in your Unity scene");
            message.AppendLine($"  2. Attach a FlutterMonoBehaviour script with TargetName = \"{target}\"");
            message.AppendLine($"  3. Ensure the GameObject is active when Unity starts");
            message.AppendLine($"  4. Check that MessageRouter is initialized before messages are sent");
            message.AppendLine($"  5. Add GameFrameworkBootstrapper to your scene for auto-creation");
            
            // Attempt to find by type name
            var allMonoBehaviours = FindObjectsOfType<MonoBehaviour>();
            var suggestions = allMonoBehaviours.Where(o => o.GetType().Name == target).ToList();
            
            if (suggestions.Any())
            {
                message.AppendLine();
                message.AppendLine($"Found {suggestions.Count} GameObject(s) with '{target}' script attached:");
                foreach (var suggestion in suggestions)
                {
                    message.AppendLine($"  - GameObject '{suggestion.gameObject.name}' (consider renaming to '{target}')");
                }
                message.AppendLine();
                message.AppendLine("The script exists but the GameObject name doesn't match the target.");
                message.AppendLine("Either rename the GameObject or use MessageRouter for automatic routing.");
            }
            else
            {
                // Look for any FlutterMonoBehaviour
                var flutterBehaviours = allMonoBehaviours.OfType<FlutterMonoBehaviour>().ToList();
                if (flutterBehaviours.Any())
                {
                    message.AppendLine();
                    message.AppendLine("FlutterMonoBehaviour instances in scene:");
                    foreach (var fb in flutterBehaviours)
                    {
                        message.AppendLine($"  - {fb.GetType().Name} on GameObject '{fb.gameObject.name}'");
                    }
                }
                else
                {
                    message.AppendLine();
                    message.AppendLine("No FlutterMonoBehaviour instances found in scene.");
                    message.AppendLine("Make sure you have added the required script to a GameObject.");
                }
            }
            
            Debug.LogError(message.ToString());
        }

        /// <summary>
        /// Send a message to Flutter
        /// </summary>
        /// <param name="target">The Flutter target (for routing)</param>
        /// <param name="method">The method name</param>
        /// <param name="data">The data to send (will be JSON serialized)</param>
        public void SendToFlutter(string target, string method, string data)
        {
            try
            {
                Debug.Log($"FlutterBridge: Sending to Flutter - Target: {target}, Method: {method}, Data: {data}");

#if UNITY_ANDROID && !UNITY_EDITOR
                SendToFlutterAndroid(target, method, data);
#elif UNITY_IOS && !UNITY_EDITOR
                SendToFlutterIOS(target, method, data);
#elif UNITY_WEBGL && !UNITY_EDITOR
                SendToFlutterWebGL(target, method, data);
#elif UNITY_STANDALONE_OSX && !UNITY_EDITOR
                SendToFlutterMacOS(target, method, data);
#else
                Debug.LogWarning("FlutterBridge: SendToFlutter only works on Android/iOS/WebGL/macOS builds");
#endif
            }
            catch (Exception e)
            {
                Debug.LogError($"FlutterBridge: Error sending message: {e.Message}");
            }
        }

        /// <summary>
        /// Send a message to Flutter with automatic JSON serialization
        /// </summary>
        public void SendToFlutter<T>(string target, string method, T data) where T : class
        {
            string jsonData = JsonUtility.ToJson(data);
            SendToFlutter(target, method, jsonData);
        }

        /// <summary>
        /// Send an error message to Flutter
        /// </summary>
        public void SendError(string errorMessage)
        {
            SendToFlutter("FlutterBridge", "onError", errorMessage);
        }

        /// <summary>
        /// Notify Flutter when a scene is loaded
        /// </summary>
        public void NotifySceneLoaded(string sceneName, int buildIndex)
        {
            var sceneData = new SceneLoadedData
            {
                name = sceneName,
                buildIndex = buildIndex,
                isLoaded = true,
                isValid = true
            };

            string jsonData = JsonUtility.ToJson(sceneData);
            SendToFlutter("SceneManager", "onSceneLoaded", jsonData);
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        // Cached references to avoid repeated JNI lookups
        private static AndroidJavaClass _flutterBridgeRegistryClass = null;
        private static bool _registryClassLoadAttempted = false;
        
        /// <summary>
        /// Send message to Flutter on Android using FlutterBridgeRegistry
        /// The registry is a Kotlin singleton accessible via JNI
        /// 
        /// Uses Activity's classloader to find Flutter plugin classes,
        /// since Unity's default classloader may not have access to them.
        /// </summary>
        private void SendToFlutterAndroid(string target, string method, string data)
        {
            Debug.Log($"FlutterBridge Android: Sending - Target: {target}, Method: {method}");
            
            try
            {
                // Try to get or load the FlutterBridgeRegistry class
                AndroidJavaClass registry = GetFlutterBridgeRegistryClass();
                
                if (registry == null)
                {
                    Debug.LogError("FlutterBridge Android: Cannot find FlutterBridgeRegistry class!");
                    return;
                }
                
                bool success = registry.CallStatic<bool>("sendMessageToFlutter", target, method, data);
                if (success)
                {
                    Debug.Log($"FlutterBridge Android: Message sent successfully!");
                }
                else
                {
                    Debug.LogWarning("FlutterBridge Android: sendMessageToFlutter returned false - controller may not be registered");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"FlutterBridge Android: Exception sending message: {e.Message}");
                Debug.LogError($"FlutterBridge Android: StackTrace: {e.StackTrace}");
            }
        }
        
        /// <summary>
        /// Get the FlutterBridgeRegistry class, trying multiple classloaders if needed
        /// </summary>
        private AndroidJavaClass GetFlutterBridgeRegistryClass()
        {
            // Return cached class if available
            if (_flutterBridgeRegistryClass != null)
            {
                return _flutterBridgeRegistryClass;
            }
            
            // If we already tried and failed, don't retry
            if (_registryClassLoadAttempted)
            {
                return null;
            }
            
            _registryClassLoadAttempted = true;
            string className = "com.xraph.gameframework.unity.FlutterBridgeRegistry";
            
            // Method 1: Try direct class loading (works if classloaders are unified)
            try
            {
                Debug.Log("FlutterBridge Android: Trying direct class loading...");
                _flutterBridgeRegistryClass = new AndroidJavaClass(className);
                
                // Test that it works by calling isReady
                _flutterBridgeRegistryClass.CallStatic<bool>("isReady");
                Debug.Log("FlutterBridge Android: Direct class loading succeeded!");
                return _flutterBridgeRegistryClass;
            }
            catch (Exception e)
            {
                Debug.Log($"FlutterBridge Android: Direct loading failed: {e.Message}");
                _flutterBridgeRegistryClass = null;
            }
            
            // Method 2: Try loading via Activity's classloader
            try
            {
                Debug.Log("FlutterBridge Android: Trying Activity classloader...");
                using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                using (AndroidJavaObject activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
                {
                    if (activity != null)
                    {
                        using (AndroidJavaObject classLoader = activity.Call<AndroidJavaObject>("getClassLoader"))
                        {
                            if (classLoader != null)
                            {
                                using (AndroidJavaObject clazz = classLoader.Call<AndroidJavaObject>("loadClass", className))
                                {
                                    if (clazz != null)
                                    {
                                        // Wrap the loaded class - need to use AndroidJavaObject for this
                                        // Store reference to the class object
                                        _flutterBridgeRegistryClass = new AndroidJavaClass(className);
                                        Debug.Log("FlutterBridge Android: Activity classloader succeeded!");
                                        return _flutterBridgeRegistryClass;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"FlutterBridge Android: Activity classloader failed: {e.Message}");
            }
            
            Debug.LogError("FlutterBridge Android: All class loading methods failed!");
            return null;
        }
#endif

#if UNITY_IOS && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void SendMessageToFlutter(string target, string method, string data);

        private void SendToFlutterIOS(string target, string method, string data)
        {
            SendMessageToFlutter(target, method, data);
        }
#endif

#if UNITY_WEBGL && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void SendMessageToFlutter(string target, string method, string data);

        [DllImport("__Internal")]
        private static extern void SendSceneLoadedToFlutter(string name, int buildIndex);

        private void SendToFlutterWebGL(string target, string method, string data)
        {
            SendMessageToFlutter(target, method, data);
        }
#endif

#if UNITY_STANDALONE_OSX && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void SendMessageToFlutter(string target, string method, string data);

        private void SendToFlutterMacOS(string target, string method, string data)
        {
            SendMessageToFlutter(target, method, data);
        }
#endif

        #region Binary Sending

        /// <summary>
        /// Send binary data to Flutter.
        /// </summary>
        /// <param name="target">Target component</param>
        /// <param name="method">Method name</param>
        /// <param name="data">Binary data to send</param>
        /// <param name="compress">Whether to compress the data</param>
        public void SendBinaryToFlutter(string target, string method, byte[] data, bool compress = false)
        {
            try
            {
                string envelope = BinaryMessageProtocol.CreateEnvelope(data, compress);
                SendToFlutter(target, method, envelope);
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterBridge] SendBinaryToFlutter failed: {e.Message}");
            }
        }

        /// <summary>
        /// Send large binary data in chunks.
        /// </summary>
        public void SendBinaryChunked(string target, string method, byte[] data, int chunkSize = 65536)
        {
            BinaryMessageProtocol.SendChunked(target, method, data, chunkSize);
        }

        #endregion

        #region Utility

        private string TruncateForLog(string message, int maxLength = 200)
        {
            if (string.IsNullOrEmpty(message)) return "";
            if (message.Length <= maxLength) return message;
            return message.Substring(0, maxLength) + "...";
        }

        #endregion

        #region Data Structures

        [Serializable]
        private class FlutterMessage
        {
            public string target;
            public string method;
            public string data;
            public string dataType; // "string", "json", "binary", "compressedBinary"
        }

        [Serializable]
        private class BatchMessage
        {
            public bool batch;
            public int count;
            public BatchItem[] messages;
        }

        [Serializable]
        private class BatchItem
        {
            public string t; // target (short key for batching)
            public string m; // method
            public string d; // data
            public string dt; // dataType
        }

        [Serializable]
        private class SceneLoadedData
        {
            public string name;
            public int buildIndex;
            public bool isLoaded;
            public bool isValid;
        }

        #endregion
    }
}
