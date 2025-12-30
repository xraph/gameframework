using System;
using UnityEngine;
using UnityEngine.UI;

namespace Xraph.GameFramework.Unity.Examples
{
    /// <summary>
    /// Example demonstrating NativeAPI usage for Unity-Flutter communication
    /// 
    /// This example shows:
    /// - Sending messages to Flutter
    /// - Receiving messages from Flutter
    /// - Using callbacks for request-response patterns
    /// - Type-safe message handling
    /// - Lifecycle management
    /// </summary>
    public class NativeAPIExample : MonoBehaviour
    {
        [Header("UI References")]
        public Text statusText;
        public Text messageLogText;
        public Button sendMessageButton;
        public Button requestDataButton;
        public Button notifyReadyButton;

        private MessageHandler messageHandler;
        private int messageCount = 0;

        void Start()
        {
            InitializeComponents();
            RegisterMessageHandlers();
            SetupUIListeners();

            // Notify Flutter that Unity is ready
            NativeAPI.NotifyUnityReady();
            LogMessage("Unity initialized and ready");
        }

        void OnDestroy()
        {
            UnregisterMessageHandlers();
        }

        /// <summary>
        /// Initialize required components
        /// </summary>
        private void InitializeComponents()
        {
            // Get or create MessageHandler
            messageHandler = GetComponent<MessageHandler>();
            if (messageHandler == null)
            {
                messageHandler = gameObject.AddComponent<MessageHandler>();
            }
            messageHandler.enableDebugLogging = true;

            // Ensure UnityMessageManager exists
            var manager = UnityMessageManager.Instance;
            
            if (statusText != null)
            {
                statusText.text = "Status: Ready";
            }
        }

        /// <summary>
        /// Register message handlers for incoming Flutter messages
        /// </summary>
        private void RegisterMessageHandlers()
        {
            // Register typed message handlers
            messageHandler.RegisterHandler<PlayerActionMessage>("PlayerAction", HandlePlayerAction);
            messageHandler.RegisterHandler<ConfigMessage>("Config", HandleConfig);
            messageHandler.RegisterHandler<string>("SimpleMessage", HandleSimpleMessage);

            // Register event listeners via UnityMessageManager
            UnityMessageManager.Instance.AddEventListener("Flutter:Command", HandleFlutterCommand);
            UnityMessageManager.Instance.AddEventListener("Unity:Ready", (data) => 
            {
                LogMessage("Unity ready event triggered");
            });

            // Subscribe to NativeAPI events
            NativeAPI.OnMessageReceived += OnNativeMessageReceived;
            NativeAPI.OnUnityPaused += OnUnityPausedChanged;
            NativeAPI.OnSceneLoaded += OnUnitySceneLoaded;

            LogMessage("Message handlers registered");
        }

        /// <summary>
        /// Unregister message handlers
        /// </summary>
        private void UnregisterMessageHandlers()
        {
            UnityMessageManager.Instance.RemoveEventListener("Flutter:Command", HandleFlutterCommand);
            
            NativeAPI.OnMessageReceived -= OnNativeMessageReceived;
            NativeAPI.OnUnityPaused -= OnUnityPausedChanged;
            NativeAPI.OnSceneLoaded -= OnUnitySceneLoaded;
        }

        /// <summary>
        /// Setup UI button listeners
        /// </summary>
        private void SetupUIListeners()
        {
            if (sendMessageButton != null)
            {
                sendMessageButton.onClick.AddListener(OnSendMessageClicked);
            }

            if (requestDataButton != null)
            {
                requestDataButton.onClick.AddListener(OnRequestDataClicked);
            }

            if (notifyReadyButton != null)
            {
                notifyReadyButton.onClick.AddListener(OnNotifyReadyClicked);
            }
        }

        // ========== UI Button Handlers ==========

        private void OnSendMessageClicked()
        {
            messageCount++;

            // Example 1: Send simple message using NativeAPI
            NativeAPI.SendMessageToFlutter("Flutter", "onUnityEvent", 
                $"{{\"message\":\"Hello from Unity\",\"count\":{messageCount}}}");

            LogMessage($"Sent message #{messageCount} to Flutter");
        }

        private void OnRequestDataClicked()
        {
            // Example 2: Request data with callback using UnityMessageManager
            var requestData = new DataRequest
            {
                requestId = Guid.NewGuid().ToString(),
                dataType = "playerStats",
                timestamp = Time.time
            };

            messageHandler.SendMessageWithResponse<DataRequest, DataResponse>(
                "Flutter",
                "requestData",
                requestData,
                (response) =>
                {
                    if (response != null && response.success)
                    {
                        LogMessage($"Received data: {response.data}");
                        UpdateStatus($"Data received: {response.data}");
                    }
                    else
                    {
                        LogMessage($"Request failed: {response?.error}");
                    }
                }
            );

            LogMessage("Sent data request to Flutter");
        }

        private void OnNotifyReadyClicked()
        {
            // Example 3: Notify ready
            NativeAPI.NotifyUnityReady();
            LogMessage("Sent ready notification to Flutter");
        }

        // ========== Message Handlers ==========

        private void HandlePlayerAction(PlayerActionMessage action)
        {
            LogMessage($"Player action: {action.action} at ({action.x}, {action.y}, {action.z})");

            // Respond back to Flutter
            var response = new ActionResponse
            {
                success = true,
                actionId = action.actionId,
                result = $"Action '{action.action}' executed successfully"
            };

            messageHandler.SendMessage("Flutter", "onActionResponse", response);
        }

        private void HandleConfig(ConfigMessage config)
        {
            LogMessage($"Config received: Quality={config.graphicsQuality}, Volume={config.volume}");

            // Apply configuration
            QualitySettings.SetQualityLevel(config.graphicsQuality);
            AudioListener.volume = config.volume;

            UpdateStatus("Configuration applied");
        }

        private void HandleSimpleMessage(string message)
        {
            LogMessage($"Simple message: {message}");
        }

        private void HandleFlutterCommand(string data)
        {
            LogMessage($"Flutter command: {data}");

            try
            {
                var command = JsonUtility.FromJson<CommandMessage>(data);
                
                switch (command.command.ToLower())
                {
                    case "pause":
                        NativeAPI.Pause(true);
                        break;
                    case "resume":
                        NativeAPI.Pause(false);
                        break;
                    case "quit":
                        NativeAPI.QuitUnity();
                        break;
                    default:
                        LogMessage($"Unknown command: {command.command}");
                        break;
                }
            }
            catch (Exception e)
            {
                LogMessage($"Error parsing command: {e.Message}");
            }
        }

        // ========== NativeAPI Event Handlers ==========

        private void OnNativeMessageReceived(string message)
        {
            LogMessage($"[NativeAPI] Message received: {message}");
        }

        private void OnUnityPausedChanged(bool isPaused)
        {
            LogMessage($"[NativeAPI] Unity paused: {isPaused}");
            UpdateStatus(isPaused ? "Paused" : "Running");
        }

        private void OnUnitySceneLoaded(string sceneName, int buildIndex)
        {
            LogMessage($"[NativeAPI] Scene loaded: {sceneName} (index: {buildIndex})");
        }

        // ========== Helper Methods ==========

        private void LogMessage(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string logEntry = $"[{timestamp}] {message}";
            
            Debug.Log(logEntry);

            if (messageLogText != null)
            {
                messageLogText.text = logEntry + "\n" + messageLogText.text;
                
                // Keep only last 10 lines
                string[] lines = messageLogText.text.Split('\n');
                if (lines.Length > 10)
                {
                    messageLogText.text = string.Join("\n", lines, 0, 10);
                }
            }
        }

        private void UpdateStatus(string status)
        {
            if (statusText != null)
            {
                statusText.text = $"Status: {status}";
            }
        }

        // ========== Message Data Structures ==========

        [Serializable]
        public class PlayerActionMessage
        {
            public string actionId;
            public string action;
            public float x;
            public float y;
            public float z;
            public float timestamp;
        }

        [Serializable]
        public class ConfigMessage
        {
            public int graphicsQuality;
            public float volume;
            public bool enableVSync;
            public int targetFrameRate;
        }

        [Serializable]
        public class DataRequest
        {
            public string requestId;
            public string dataType;
            public float timestamp;
        }

        [Serializable]
        public class DataResponse
        {
            public bool success;
            public string data;
            public string error;
        }

        [Serializable]
        public class ActionResponse
        {
            public bool success;
            public string actionId;
            public string result;
        }

        [Serializable]
        public class CommandMessage
        {
            public string command;
            public string data;
        }

        // ========== Public API for Unity Scripts ==========

        /// <summary>
        /// Send a custom event to Flutter
        /// </summary>
        public void SendCustomEvent(string eventName, string eventData)
        {
            NativeAPI.SendMessageToFlutter("Flutter", eventName, eventData);
            LogMessage($"Sent custom event: {eventName}");
        }

        /// <summary>
        /// Send game state to Flutter
        /// </summary>
        public void SendGameState(int score, int level, float health)
        {
            var gameState = new GameStateMessage
            {
                score = score,
                level = level,
                health = health,
                timestamp = Time.time
            };

            messageHandler.SendMessage("Flutter", "onGameState", gameState);
            LogMessage($"Sent game state: Score={score}, Level={level}, Health={health}");
        }

        [Serializable]
        public class GameStateMessage
        {
            public int score;
            public int level;
            public float health;
            public float timestamp;
        }
    }
}

