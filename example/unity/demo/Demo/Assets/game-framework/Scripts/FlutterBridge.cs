using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Bridge between Unity and Flutter
    ///
    /// This component enables bidirectional communication between Unity and Flutter.
    /// Add this to a GameObject in your Unity scene and mark it as DontDestroyOnLoad.
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
        /// Event triggered when a message is received from Flutter
        /// </summary>
        public static event Action<string, string, string> OnFlutterMessage;

        void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);
            Debug.Log("FlutterBridge initialized");
        }

        /// <summary>
        /// Called from Flutter to send a message to Unity
        /// This method is called via UnitySendMessage
        /// </summary>
        /// <param name="message">JSON message containing target, method, and data</param>
        public void ReceiveMessage(string message)
        {
            try
            {
                Debug.Log($"FlutterBridge: Received message: {message}");

                // Parse the message (expecting JSON format)
                var messageData = JsonUtility.FromJson<FlutterMessage>(message);

                if (messageData != null)
                {
                    // Trigger the event for listeners
                    OnFlutterMessage?.Invoke(messageData.target, messageData.method, messageData.data);

                    // Handle the message
                    HandleMessage(messageData.target, messageData.method, messageData.data);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"FlutterBridge: Error receiving message: {e.Message}");
                SendError($"Failed to receive message: {e.Message}");
            }
        }

        /// <summary>
        /// Handle incoming messages from Flutter
        /// Override this method to add custom message handling
        /// </summary>
        protected virtual void HandleMessage(string target, string method, string data)
        {
            Debug.Log($"FlutterBridge: Handling message - Target: {target}, Method: {method}, Data: {data}");

            // Default handling - find the target GameObject and send the message
            GameObject targetObject = GameObject.Find(target);
            if (targetObject != null)
            {
                targetObject.SendMessage(method, data, SendMessageOptions.DontRequireReceiver);
            }
            else
            {
                Debug.LogWarning($"FlutterBridge: Target GameObject '{target}' not found");
            }
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
#else
                Debug.LogWarning("FlutterBridge: SendToFlutter only works on Android/iOS builds");
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
        private void SendToFlutterAndroid(string target, string method, string data)
        {
            using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                using (AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
                {
                    currentActivity.Call("runOnUiThread", new AndroidJavaRunnable(() =>
                    {
                        try
                        {
                            // Get the UnityEngineController instance
                            AndroidJavaObject controller = currentActivity.Get<AndroidJavaObject>("unityEngineController");
                            if (controller != null)
                            {
                                controller.Call("onUnityMessage", target, method, data);
                            }
                            else
                            {
                                Debug.LogWarning("FlutterBridge: UnityEngineController not found on Android activity");
                            }
                        }
                        catch (Exception e)
                        {
                            Debug.LogError($"FlutterBridge Android: {e.Message}");
                        }
                    }));
                }
            }
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

        // Data structures for message passing

        [Serializable]
        private class FlutterMessage
        {
            public string target;
            public string method;
            public string data;
        }

        [Serializable]
        private class SceneLoadedData
        {
            public string name;
            public int buildIndex;
            public bool isLoaded;
            public bool isValid;
        }
    }
}
