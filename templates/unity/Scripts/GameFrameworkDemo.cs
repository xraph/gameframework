using System;
using UnityEngine;
using UnityEngine.SceneManagement;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Main demo orchestrator for Game Framework features.
    /// 
    /// This script demonstrates all the features available in the
    /// Flutter Game Framework Unity integration:
    /// - Automatic message routing via FlutterMonoBehaviour
    /// - Typed message handling with [FlutterMethod] attribute
    /// - Binary data transfer
    /// - High-frequency messaging with batching and throttling
    /// - State synchronization with delta compression
    /// - Scene management
    /// - Performance monitoring
    /// 
    /// Attach this script to a GameObject named "GameFrameworkDemo" in your scene.
    /// </summary>
    public class GameFrameworkDemo : FlutterMonoBehaviour
    {
        #region Configuration

        [Header("Demo Configuration")]
        [Tooltip("Enable verbose logging")]
        [SerializeField] private bool verboseLogging = true;

        [Tooltip("Auto-start demo features on scene load")]
        [SerializeField] private bool autoStart = true;

        #endregion

        #region FlutterMonoBehaviour Overrides

        /// <summary>
        /// Target name for message routing.
        /// Flutter will send messages to "GameFrameworkDemo" target.
        /// </summary>
        protected override string TargetName => "GameFrameworkDemo";

        /// <summary>
        /// Run in singleton mode - only one instance handles messages.
        /// </summary>
        protected override bool IsSingleton => true;

        #endregion

        #region State

        private bool _isInitialized = false;
        private DemoStats _stats;

        #endregion

        #region Unity Lifecycle

        protected override void Awake()
        {
            base.Awake();

            // Initialize stats
            _stats = new DemoStats();

            EnableDebugLogging = verboseLogging;
            EnableBatching = true;
            EnableDeltaCompression = true;

            Log("GameFrameworkDemo: Initialized");
        }

        void Start()
        {
            if (autoStart)
            {
                Initialize();
            }
        }

        void Update()
        {
            // Update runtime stats
            _stats.frameCount++;
            _stats.deltaTime = Time.deltaTime;
            _stats.fps = 1f / Time.deltaTime;
        }

        protected override void OnDestroy()
        {
            Log("GameFrameworkDemo: Destroyed");
            base.OnDestroy();
        }

        #endregion

        #region Initialization

        /// <summary>
        /// Initialize the demo and notify Flutter.
        /// </summary>
        [FlutterMethod("initialize")]
        public void Initialize()
        {
            if (_isInitialized)
            {
                Log("GameFrameworkDemo: Already initialized");
                return;
            }

            _isInitialized = true;
            _stats.startTime = Time.time;

            // Notify Flutter that demo is ready
            SendToFlutter("onInitialized", new InitializedEvent
            {
                success = true,
                version = "1.0.0",
                features = new[] { "messaging", "binary", "batching", "throttling", "delta", "scenes" },
                timestamp = DateTime.UtcNow.ToString("o")
            });

            Log("GameFrameworkDemo: Initialized and ready");
        }

        /// <summary>
        /// Shutdown the demo.
        /// </summary>
        [FlutterMethod("shutdown")]
        public void Shutdown()
        {
            _isInitialized = false;

            SendToFlutter("onShutdown", new { success = true });

            Log("GameFrameworkDemo: Shutdown");
        }

        #endregion

        #region Basic Messaging

        /// <summary>
        /// Echo a string message back to Flutter.
        /// Demonstrates basic string messaging.
        /// </summary>
        [FlutterMethod("echo")]
        public void Echo(string message)
        {
            _stats.messagesReceived++;

            Log($"GameFrameworkDemo: Echo received: {message}");

            SendToFlutter("onEcho", message);
        }

        /// <summary>
        /// Process a typed command from Flutter.
        /// Demonstrates automatic JSON deserialization.
        /// </summary>
        [FlutterMethod("command")]
        public void ProcessCommand(CommandMessage command)
        {
            _stats.messagesReceived++;

            Log($"GameFrameworkDemo: Command received: {command.action}, params: {command.parameters?.Length ?? 0}");

            // Process command
            var result = new CommandResult
            {
                action = command.action,
                success = true,
                timestamp = DateTime.UtcNow.ToString("o")
            };

            switch (command.action)
            {
                case "ping":
                    result.data = "pong";
                    break;
                case "getStats":
                    result.data = JsonUtility.ToJson(_stats);
                    break;
                case "getScenes":
                    result.data = GetSceneList();
                    break;
                default:
                    result.data = $"Processed: {command.action}";
                    break;
            }

            SendToFlutter("onCommandResult", result);
        }

        /// <summary>
        /// No-parameter method demonstrating simple notification.
        /// </summary>
        [FlutterMethod("ping")]
        public void Ping()
        {
            _stats.messagesReceived++;
            SendToFlutter("onPong", "pong");
        }

        #endregion

        #region Binary Data

        /// <summary>
        /// Receive binary data from Flutter.
        /// Demonstrates binary data transfer with automatic base64 decoding.
        /// </summary>
        [FlutterMethod("receiveBinary", AcceptsBinary = true)]
        public void ReceiveBinary(byte[] data)
        {
            _stats.messagesReceived++;
            _stats.bytesReceived += data?.Length ?? 0;

            Log($"GameFrameworkDemo: Received binary data: {data?.Length ?? 0} bytes");

            // Acknowledge receipt
            SendToFlutter("onBinaryReceived", new BinaryReceivedEvent
            {
                size = data?.Length ?? 0,
                checksum = ComputeChecksum(data),
                timestamp = DateTime.UtcNow.ToString("o")
            });
        }

        /// <summary>
        /// Send binary data to Flutter.
        /// </summary>
        [FlutterMethod("requestBinary")]
        public void RequestBinary(BinaryRequest request)
        {
            _stats.messagesReceived++;

            Log($"GameFrameworkDemo: Binary request: {request.size} bytes");

            // Generate test binary data
            byte[] data = new byte[request.size];
            for (int i = 0; i < data.Length; i++)
            {
                data[i] = (byte)(i % 256);
            }

            // Send binary data (with optional compression)
            SendBinaryToFlutter("onBinaryData", data, request.compress);

            _stats.bytesSent += data.Length;
        }

        private long ComputeChecksum(byte[] data)
        {
            if (data == null || data.Length == 0) return 0;
            long sum = 0;
            for (int i = 0; i < data.Length; i++)
            {
                sum = (sum + data[i]) * 31;
            }
            return sum;
        }

        #endregion

        #region High-Frequency Messaging

        /// <summary>
        /// Handle high-frequency position updates from Flutter.
        /// Demonstrates throttled message handling.
        /// </summary>
        [FlutterMethod("position", Throttle = 60, ThrottleStrategy = ThrottleStrategy.KeepLatest)]
        public void OnPositionUpdate(PositionData position)
        {
            _stats.messagesReceived++;
            _stats.positionUpdates++;

            // Process position update (e.g., move a game object)
            // In a real game, this would update player position
        }

        /// <summary>
        /// Handle high-frequency input from Flutter.
        /// </summary>
        [FlutterMethod("input", Throttle = 120)]
        public void OnInputUpdate(InputData input)
        {
            _stats.messagesReceived++;
            _stats.inputUpdates++;

            // Process input (e.g., joystick, touch)
        }

        /// <summary>
        /// Start sending high-frequency updates to Flutter.
        /// </summary>
        [FlutterMethod("startStreaming")]
        public void StartStreaming(StreamingConfig config)
        {
            Log($"GameFrameworkDemo: Start streaming at {config.rateHz}Hz");

            // In a real implementation, start a coroutine or update loop
            // to send position/state updates at the configured rate
            SendToFlutter("onStreamingStarted", new { rateHz = config.rateHz });
        }

        /// <summary>
        /// Stop streaming updates.
        /// </summary>
        [FlutterMethod("stopStreaming")]
        public void StopStreaming()
        {
            Log("GameFrameworkDemo: Stop streaming");
            SendToFlutter("onStreamingStopped", new { });
        }

        #endregion

        #region State Synchronization

        /// <summary>
        /// Get current game state.
        /// Demonstrates state serialization.
        /// </summary>
        [FlutterMethod("getState")]
        public void GetState()
        {
            _stats.messagesReceived++;

            var state = new GameState
            {
                isInitialized = _isInitialized,
                currentScene = SceneManager.GetActiveScene().name,
                frameCount = _stats.frameCount,
                fps = _stats.fps,
                messagesReceived = _stats.messagesReceived,
                bytesSent = _stats.bytesSent,
                bytesReceived = _stats.bytesReceived,
                uptime = Time.time - _stats.startTime
            };

            SendToFlutter("onState", state);
        }

        /// <summary>
        /// Set game state from Flutter.
        /// </summary>
        [FlutterMethod("setState")]
        public void SetState(GameState state)
        {
            _stats.messagesReceived++;

            Log($"GameFrameworkDemo: Set state - scene: {state.currentScene}");

            // Apply state changes
            if (!string.IsNullOrEmpty(state.currentScene) && 
                state.currentScene != SceneManager.GetActiveScene().name)
            {
                LoadScene(state.currentScene);
            }

            SendToFlutter("onStateApplied", new { success = true });
        }

        #endregion

        #region Scene Management

        /// <summary>
        /// Load a scene by name.
        /// </summary>
        [FlutterMethod("loadScene")]
        public void LoadScene(string sceneName)
        {
            _stats.messagesReceived++;

            Log($"GameFrameworkDemo: Loading scene: {sceneName}");

            try
            {
                SceneManager.LoadScene(sceneName);
                
                // Notification will be sent by FlutterSceneManager
                SendToFlutter("onSceneLoading", new { scene = sceneName });
            }
            catch (Exception e)
            {
                SendToFlutter("onSceneError", new { scene = sceneName, error = e.Message });
            }
        }

        private string GetSceneList()
        {
            var scenes = new string[SceneManager.sceneCountInBuildSettings];
            for (int i = 0; i < scenes.Length; i++)
            {
                string path = SceneUtility.GetScenePathByBuildIndex(i);
                scenes[i] = System.IO.Path.GetFileNameWithoutExtension(path);
            }
            return string.Join(",", scenes);
        }

        #endregion

        #region Performance

        /// <summary>
        /// Get performance statistics.
        /// </summary>
        [FlutterMethod("getPerformance")]
        public void GetPerformance()
        {
            _stats.messagesReceived++;

            var perf = new PerformanceStats
            {
                fps = _stats.fps,
                frameCount = _stats.frameCount,
                deltaTime = _stats.deltaTime,
                messagesReceived = _stats.messagesReceived,
                messagesSent = _stats.messagesSent,
                bytesReceived = _stats.bytesReceived,
                bytesSent = _stats.bytesSent,
                positionUpdates = _stats.positionUpdates,
                inputUpdates = _stats.inputUpdates,
                uptime = Time.time - _stats.startTime,
                memoryUsage = GC.GetTotalMemory(false),
                poolStats = MessagePool.Instance?.GetStatistics().ToString() ?? "",
                batcherStats = MessageBatcher.Instance?.GetStatistics().ToString() ?? ""
            };

            SendToFlutter("onPerformance", perf);
        }

        /// <summary>
        /// Reset performance counters.
        /// </summary>
        [FlutterMethod("resetPerformance")]
        public void ResetPerformance()
        {
            _stats = new DemoStats();
            _stats.startTime = Time.time;

            MessagePool.Instance?.ResetStatistics();
            MessageBatcher.Instance?.ResetStatistics();

            SendToFlutter("onPerformanceReset", new { success = true });
        }

        #endregion

        #region Utility

        private void Log(string message)
        {
            if (verboseLogging)
            {
                Debug.Log(message);
            }
        }

        #endregion

        #region Data Types

        [Serializable]
        private class DemoStats
        {
            public float startTime;
            public int frameCount;
            public float deltaTime;
            public float fps;
            public int messagesReceived;
            public int messagesSent;
            public long bytesReceived;
            public long bytesSent;
            public int positionUpdates;
            public int inputUpdates;
        }

        [Serializable]
        public class InitializedEvent
        {
            public bool success;
            public string version;
            public string[] features;
            public string timestamp;
        }

        [Serializable]
        public class CommandMessage
        {
            public string action;
            public string[] parameters;
        }

        [Serializable]
        public class CommandResult
        {
            public string action;
            public bool success;
            public string data;
            public string timestamp;
        }

        [Serializable]
        public class BinaryRequest
        {
            public int size;
            public bool compress;
        }

        [Serializable]
        public class BinaryReceivedEvent
        {
            public int size;
            public long checksum;
            public string timestamp;
        }

        [Serializable]
        public class PositionData
        {
            public float x;
            public float y;
            public float z;
            public float timestamp;
        }

        [Serializable]
        public class InputData
        {
            public float dx;
            public float dy;
            public float pressure;
            public int pointerId;
        }

        [Serializable]
        public class StreamingConfig
        {
            public int rateHz;
            public bool enableDelta;
        }

        [Serializable]
        public class GameState
        {
            public bool isInitialized;
            public string currentScene;
            public int frameCount;
            public float fps;
            public int messagesReceived;
            public long bytesSent;
            public long bytesReceived;
            public float uptime;
        }

        [Serializable]
        public class PerformanceStats
        {
            public float fps;
            public int frameCount;
            public float deltaTime;
            public int messagesReceived;
            public int messagesSent;
            public long bytesReceived;
            public long bytesSent;
            public int positionUpdates;
            public int inputUpdates;
            public float uptime;
            public long memoryUsage;
            public string poolStats;
            public string batcherStats;
        }

        #endregion
    }
}
