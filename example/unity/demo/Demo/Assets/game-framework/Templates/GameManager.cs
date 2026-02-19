using System;
using UnityEngine;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Example GameManager demonstrating FlutterMonoBehaviour usage.
    /// 
    /// This is a simplified example showing the basic pattern for
    /// Flutter-Unity communication using the Game Framework.
    /// 
    /// Features demonstrated:
    /// - Inheriting from FlutterMonoBehaviour
    /// - Using [FlutterMethod] attribute for message routing
    /// - Sending typed messages to Flutter
    /// - Handling game commands
    /// 
    /// Flutter usage:
    /// ```dart
    /// // Send command to start game
    /// await controller.sendJsonMessage('GameManager', 'startGame', {
    ///   'level': 1,
    ///   'difficulty': 'normal',
    /// });
    /// 
    /// // Listen for game events
    /// controller.messageStream.listen((msg) {
    ///   if (msg.target == 'GameManager') {
    ///     switch (msg.method) {
    ///       case 'onGameStarted':
    ///         print('Game started!');
    ///         break;
    ///       case 'onScoreUpdate':
    ///         final score = jsonDecode(msg.data)['score'];
    ///         break;
    ///     }
    ///   }
    /// });
    /// ```
    /// </summary>
    public class GameManager : FlutterMonoBehaviour
    {
        #region FlutterMonoBehaviour Configuration

        /// <summary>
        /// Target name for Flutter message routing.
        /// Messages sent to "GameManager" target will be routed here.
        /// </summary>
        protected override string TargetName => "GameManager";

        /// <summary>
        /// Run in singleton mode - only one instance handles messages.
        /// </summary>
        protected override bool IsSingleton => true;

        #endregion

        #region Game State

        [Header("Game Settings")]
        [SerializeField] private int startingScore = 0;
        [SerializeField] private int startingLives = 3;

        private bool _isPlaying = false;
        private bool _isPaused = false;
        private int _score = 0;
        private int _lives = 3;
        private int _level = 1;

        #endregion

        #region Unity Lifecycle

        protected override void Awake()
        {
            base.Awake();
            
            // Enable debug logging during development
            EnableDebugLogging = true;
        }

        void Start()
        {
            Debug.Log("[GameManager] Game started!");
            
            // Notify Flutter that scene is ready
            SendToFlutter("onSceneReady", new SceneReadyEvent
            {
                sceneName = gameObject.scene.name,
                isPlaying = _isPlaying,
                timestamp = DateTime.UtcNow.ToString("o")
            });
        }

        void Update()
        {
            // Game update logic here
        }

        protected override void OnDestroy()
        {
            Debug.Log("[GameManager] Game destroyed");
            base.OnDestroy();
        }

        #endregion

        #region Flutter Message Handlers

        /// <summary>
        /// Start the game with configuration from Flutter.
        /// </summary>
        [FlutterMethod("startGame")]
        public void StartGame(GameStartConfig config)
        {
            Debug.Log($"[GameManager] Starting game - Level: {config.level}, Difficulty: {config.difficulty}");

            _isPlaying = true;
            _isPaused = false;
            _score = startingScore;
            _lives = startingLives;
            _level = config.level > 0 ? config.level : 1;

            // Notify Flutter
            SendToFlutter("onGameStarted", new GameStartedEvent
            {
                level = _level,
                difficulty = config.difficulty ?? "normal",
                lives = _lives,
                score = _score
            });
        }

        /// <summary>
        /// Pause the game.
        /// </summary>
        [FlutterMethod("pauseGame")]
        public void PauseGame()
        {
            if (!_isPlaying || _isPaused) return;

            Debug.Log("[GameManager] Game paused");
            _isPaused = true;
            Time.timeScale = 0f;

            SendToFlutter("onGamePaused", new { });
        }

        /// <summary>
        /// Resume the game.
        /// </summary>
        [FlutterMethod("resumeGame")]
        public void ResumeGame()
        {
            if (!_isPlaying || !_isPaused) return;

            Debug.Log("[GameManager] Game resumed");
            _isPaused = false;
            Time.timeScale = 1f;

            SendToFlutter("onGameResumed", new { });
        }

        /// <summary>
        /// Stop/end the game.
        /// </summary>
        [FlutterMethod("stopGame")]
        public void StopGame()
        {
            if (!_isPlaying) return;

            Debug.Log("[GameManager] Game stopped");
            _isPlaying = false;
            _isPaused = false;
            Time.timeScale = 1f;

            SendToFlutter("onGameStopped", new GameStoppedEvent
            {
                finalScore = _score,
                level = _level,
                reason = "user_stopped"
            });
        }

        /// <summary>
        /// Handle generic command from Flutter.
        /// </summary>
        [FlutterMethod("command")]
        public void HandleCommand(CommandMessage command)
        {
            Debug.Log($"[GameManager] Command received: {command.action}");

            switch (command.action)
            {
                case "addScore":
                    AddScore(int.Parse(command.value ?? "10"));
                    break;
                case "setLives":
                    _lives = int.Parse(command.value ?? "3");
                    break;
                case "nextLevel":
                    NextLevel();
                    break;
                case "restart":
                    RestartGame();
                    break;
                default:
                    Debug.LogWarning($"[GameManager] Unknown command: {command.action}");
                    break;
            }
        }

        /// <summary>
        /// Get current game state.
        /// </summary>
        [FlutterMethod("getState")]
        public void GetState()
        {
            SendToFlutter("onState", new GameStateResponse
            {
                isPlaying = _isPlaying,
                isPaused = _isPaused,
                score = _score,
                lives = _lives,
                level = _level
            });
        }

        #endregion

        #region Game Logic

        /// <summary>
        /// Add points to score and notify Flutter.
        /// </summary>
        public void AddScore(int points)
        {
            _score += points;
            
            SendToFlutter("onScoreUpdate", new ScoreUpdateEvent
            {
                score = _score,
                pointsAdded = points
            });
        }

        /// <summary>
        /// Player takes damage.
        /// </summary>
        public void TakeDamage()
        {
            _lives--;

            SendToFlutter("onLivesUpdate", new { lives = _lives });

            if (_lives <= 0)
            {
                GameOver();
            }
        }

        /// <summary>
        /// Advance to next level.
        /// </summary>
        public void NextLevel()
        {
            _level++;

            SendToFlutter("onLevelComplete", new LevelCompleteEvent
            {
                completedLevel = _level - 1,
                nextLevel = _level,
                score = _score
            });
        }

        /// <summary>
        /// Restart the current game.
        /// </summary>
        public void RestartGame()
        {
            _score = startingScore;
            _lives = startingLives;
            _isPaused = false;
            Time.timeScale = 1f;

            SendToFlutter("onGameRestarted", new { level = _level });
        }

        /// <summary>
        /// Handle game over.
        /// </summary>
        private void GameOver()
        {
            _isPlaying = false;
            Time.timeScale = 0f;

            SendToFlutter("onGameOver", new GameOverEvent
            {
                finalScore = _score,
                level = _level,
                reason = "no_lives"
            });
        }

        #endregion

        #region Data Types

        [Serializable]
        public class GameStartConfig
        {
            public int level;
            public string difficulty;
        }

        [Serializable]
        public class CommandMessage
        {
            public string action;
            public string value;
        }

        [Serializable]
        public class SceneReadyEvent
        {
            public string sceneName;
            public bool isPlaying;
            public string timestamp;
        }

        [Serializable]
        public class GameStartedEvent
        {
            public int level;
            public string difficulty;
            public int lives;
            public int score;
        }

        [Serializable]
        public class GameStoppedEvent
        {
            public int finalScore;
            public int level;
            public string reason;
        }

        [Serializable]
        public class GameStateResponse
        {
            public bool isPlaying;
            public bool isPaused;
            public int score;
            public int lives;
            public int level;
        }

        [Serializable]
        public class ScoreUpdateEvent
        {
            public int score;
            public int pointsAdded;
        }

        [Serializable]
        public class LevelCompleteEvent
        {
            public int completedLevel;
            public int nextLevel;
            public int score;
        }

        [Serializable]
        public class GameOverEvent
        {
            public int finalScore;
            public int level;
            public string reason;
        }

        #endregion
    }
}
