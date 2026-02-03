using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Native API bridge for Unity-Flutter communication
    /// 
    /// Provides low-level platform-specific methods for bidirectional communication.
    /// Based on Unity as a Library architecture.
    /// </summary>
    public static class NativeAPI
    {
        /// <summary>
        /// Event triggered when a message is received from Flutter
        /// </summary>
        public static event Action<string> OnMessageReceived;

        /// <summary>
        /// Event triggered when Unity is ready
        /// </summary>
        public static event Action OnUnityReady;

        /// <summary>
        /// Event triggered when Unity is paused
        /// </summary>
        public static event Action<bool> OnUnityPaused;

        /// <summary>
        /// Event triggered when a scene is loaded
        /// </summary>
        public static event Action<string, int> OnSceneLoaded;

        private static bool isInitialized = false;
        private static bool isReady = false;

#if UNITY_IOS && !UNITY_EDITOR
        // iOS Native Methods
        [DllImport("__Internal")]
        private static extern void _sendMessageToFlutter(string message);

        [DllImport("__Internal")]
        private static extern void _showHostMainWindow();

        [DllImport("__Internal")]
        private static extern void _unloadUnity();

        [DllImport("__Internal")]
        private static extern void _quitUnity();

        [DllImport("__Internal")]
        private static extern void _notifyUnityReady();
#endif

        /// <summary>
        /// Initialize the native API
        /// Call this once at app startup
        /// </summary>
        public static void Initialize()
        {
            if (isInitialized)
            {
                Debug.LogWarning("NativeAPI: Already initialized");
                return;
            }

            isInitialized = true;
            Debug.Log("NativeAPI: Initialized");

            // Hook into Unity lifecycle events
            Application.focusChanged += OnApplicationFocus;
        }

        /// <summary>
        /// Notify Flutter that Unity is ready
        /// </summary>
        public static void NotifyUnityReady()
        {
            if (isReady)
            {
                Debug.LogWarning("NativeAPI: Unity already marked as ready");
                return;
            }

            isReady = true;
            Debug.Log("NativeAPI: Unity is ready");

#if UNITY_IOS && !UNITY_EDITOR
            _notifyUnityReady();
#elif UNITY_ANDROID && !UNITY_EDITOR
            SendToFlutterAndroid("Unity", "onReady", "");
#endif

            OnUnityReady?.Invoke();
        }

        /// <summary>
        /// Send a message to Flutter
        /// </summary>
        /// <param name="message">JSON-formatted message</param>
        public static void SendMessageToFlutter(string message)
        {
            if (string.IsNullOrEmpty(message))
            {
                Debug.LogWarning("NativeAPI: Attempted to send empty message");
                return;
            }

            Debug.Log($"NativeAPI: Sending message to Flutter: {message}");

#if UNITY_IOS && !UNITY_EDITOR
            _sendMessageToFlutter(message);
#elif UNITY_ANDROID && !UNITY_EDITOR
            SendToFlutterAndroid("Unity", "onMessage", message);
#elif UNITY_EDITOR
            Debug.Log($"NativeAPI [Editor]: Would send to Flutter: {message}");
#else
            Debug.LogWarning("NativeAPI: Platform not supported for sending messages");
#endif
        }

        /// <summary>
        /// Send a structured message to Flutter
        /// </summary>
        public static void SendMessageToFlutter(string target, string method, string data)
        {
            var message = new MessageData
            {
                target = target,
                method = method,
                data = data
            };

            string json = JsonUtility.ToJson(message);
            SendMessageToFlutter(json);
        }

        /// <summary>
        /// Show the Flutter host window (mainly for iOS)
        /// </summary>
        public static void ShowHostMainWindow()
        {
            Debug.Log("NativeAPI: Showing host main window");

#if UNITY_IOS && !UNITY_EDITOR
            _showHostMainWindow();
#elif UNITY_ANDROID && !UNITY_EDITOR
            // On Android, call the activity method
            SendToFlutterAndroid("Unity", "showHostWindow", "");
#endif
        }

        /// <summary>
        /// Unload Unity from memory
        /// </summary>
        public static void UnloadUnity()
        {
            Debug.Log("NativeAPI: Unloading Unity");

#if UNITY_IOS && !UNITY_EDITOR
            _unloadUnity();
#elif UNITY_ANDROID && !UNITY_EDITOR
            SendToFlutterAndroid("Unity", "unload", "");
#endif
        }

        /// <summary>
        /// Quit Unity application
        /// </summary>
        public static void QuitUnity()
        {
            Debug.Log("NativeAPI: Quitting Unity");

#if UNITY_IOS && !UNITY_EDITOR
            _quitUnity();
#elif UNITY_ANDROID && !UNITY_EDITOR
            SendToFlutterAndroid("Unity", "quit", "");
#endif

            Application.Quit();
        }

        /// <summary>
        /// Pause Unity
        /// </summary>
        public static void Pause(bool pause)
        {
            Debug.Log($"NativeAPI: Pause={pause}");
            Time.timeScale = pause ? 0 : 1;
            AudioListener.pause = pause;
            OnUnityPaused?.Invoke(pause);
        }

        /// <summary>
        /// Called from Flutter/Native to receive a message
        /// This method is invoked via UnitySendMessage
        /// </summary>
        /// <param name="message">JSON message from Flutter</param>
        public static void ReceiveMessage(string message)
        {
            try
            {
                Debug.Log($"NativeAPI: Received message: {message}");
                OnMessageReceived?.Invoke(message);
            }
            catch (Exception e)
            {
                Debug.LogError($"NativeAPI: Error receiving message: {e.Message}\n{e.StackTrace}");
            }
        }

        /// <summary>
        /// Notify when a scene is loaded
        /// </summary>
        internal static void NotifySceneLoaded(string sceneName, int buildIndex)
        {
            Debug.Log($"NativeAPI: Scene loaded - {sceneName} ({buildIndex})");
            OnSceneLoaded?.Invoke(sceneName, buildIndex);
            SendMessageToFlutter("Unity", "onSceneLoaded", $"{{\"name\":\"{sceneName}\",\"buildIndex\":{buildIndex}}}");
        }

        /// <summary>
        /// Handle application focus changes
        /// </summary>
        private static void OnApplicationFocus(bool hasFocus)
        {
            Debug.Log($"NativeAPI: Application focus changed: {hasFocus}");
            SendMessageToFlutter("Unity", "onFocusChanged", hasFocus.ToString().ToLower());
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        // Cached reference to FlutterBridgeRegistry class
        private static AndroidJavaClass _registryClass = null;
        private static bool _registryClassLoadAttempted = false;
        
        /// <summary>
        /// Android-specific method to send messages to Flutter
        /// Uses FlutterBridgeRegistry singleton which is accessible via JNI
        /// </summary>
        private static void SendToFlutterAndroid(string target, string method, string data)
        {
            Debug.Log($"NativeAPI Android: Sending - Target: {target}, Method: {method}");
            
            try
            {
                AndroidJavaClass registry = GetFlutterBridgeRegistryClass();
                
                if (registry == null)
                {
                    Debug.LogError("NativeAPI Android: Cannot find FlutterBridgeRegistry class!");
                    return;
                }
                
                bool success = registry.CallStatic<bool>("sendMessageToFlutter", target, method, data);
                if (success)
                {
                    Debug.Log("NativeAPI Android: Message sent successfully!");
                }
                else
                {
                    Debug.LogWarning("NativeAPI Android: sendMessageToFlutter returned false - controller may not be registered");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"NativeAPI Android: Exception sending message: {e.Message}");
                Debug.LogError($"NativeAPI Android: StackTrace: {e.StackTrace}");
            }
        }
        
        /// <summary>
        /// Get the FlutterBridgeRegistry class with caching
        /// </summary>
        private static AndroidJavaClass GetFlutterBridgeRegistryClass()
        {
            if (_registryClass != null)
            {
                return _registryClass;
            }
            
            if (_registryClassLoadAttempted)
            {
                return null;
            }
            
            _registryClassLoadAttempted = true;
            string className = "com.xraph.gameframework.unity.FlutterBridgeRegistry";
            
            // Try direct class loading
            try
            {
                Debug.Log("NativeAPI Android: Trying direct class loading...");
                _registryClass = new AndroidJavaClass(className);
                
                // Verify it works
                _registryClass.CallStatic<bool>("isReady");
                Debug.Log("NativeAPI Android: Direct class loading succeeded!");
                return _registryClass;
            }
            catch (Exception e)
            {
                Debug.Log($"NativeAPI Android: Direct loading failed: {e.Message}");
                _registryClass = null;
            }
            
            Debug.LogError("NativeAPI Android: Failed to load FlutterBridgeRegistry class!");
            return null;
        }
#endif

        /// <summary>
        /// Check if Unity is ready
        /// </summary>
        public static bool IsReady()
        {
            return isReady;
        }

        /// <summary>
        /// Message data structure
        /// </summary>
        [Serializable]
        private class MessageData
        {
            public string target;
            public string method;
            public string data;
        }
    }
}

