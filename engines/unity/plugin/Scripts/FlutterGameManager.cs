using System;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Example game manager that demonstrates Flutter integration
    ///
    /// This is a sample component showing how to interact with Flutter.
    /// Uses singleton pattern to ensure only one instance exists.
    /// Customize this for your game's needs.
    /// 
    /// Usage:
    /// <code>
    /// FlutterGameManager.Instance.StartGame("level1");
    /// FlutterGameManager.Instance.UpdateScore("100");
    /// </code>
    /// </summary>
    public class FlutterGameManager : SingletonMonoBehaviour<FlutterGameManager>
    {
        [Header("Settings")]
        [Tooltip("Send game state updates to Flutter")]
        public bool sendGameStateUpdates = true;

        [Tooltip("Interval for game state updates (seconds)")]
        public float updateInterval = 1.0f;

        private float lastUpdateTime;
        private GameState currentState;

        /// <summary>
        /// Initialize the singleton instance
        /// Called automatically by SingletonMonoBehaviour
        /// </summary>
        protected override void SingletonAwake()
        {
            base.SingletonAwake();
            
            // Subscribe to Flutter messages
            FlutterBridge.OnFlutterMessage += HandleFlutterMessage;

            // Initialize game state
            currentState = new GameState
            {
                isPlaying = false,
                isPaused = false,
                score = 0,
                level = 1,
                lives = 3
            };

            Debug.Log("FlutterGameManager singleton initialized");
        }

        void Start()
        {
            // Notify Flutter that the game is ready
            NotifyGameReady();
        }

        protected override void OnDestroy()
        {
            base.OnDestroy();
            FlutterBridge.OnFlutterMessage -= HandleFlutterMessage;
        }

        void Update()
        {
            if (sendGameStateUpdates && Time.time - lastUpdateTime >= updateInterval)
            {
                SendGameState();
                lastUpdateTime = Time.time;
            }
        }

        /// <summary>
        /// Handle messages from Flutter
        /// </summary>
        private void HandleFlutterMessage(string target, string method, string data)
        {
            if (target != "GameManager") return;

            Debug.Log($"GameManager received: {method} - {data}");

            switch (method)
            {
                case "StartGame":
                    StartGame(data);
                    break;

                case "PauseGame":
                    PauseGame();
                    break;

                case "ResumeGame":
                    ResumeGame();
                    break;

                case "StopGame":
                    StopGame();
                    break;

                case "UpdateScore":
                    UpdateScore(data);
                    break;

                case "SetLevel":
                    SetLevel(data);
                    break;

                default:
                    Debug.LogWarning($"Unknown method: {method}");
                    break;
            }
        }

        /// <summary>
        /// Notify Flutter that the game is ready
        /// </summary>
        private void NotifyGameReady()
        {
            FlutterBridge.Instance.SendToFlutter("GameManager", "onGameReady", "true");
        }

        /// <summary>
        /// Start the game
        /// </summary>
        public void StartGame(string levelData)
        {
            Debug.Log($"Starting game with data: {levelData}");
            currentState.isPlaying = true;
            currentState.isPaused = false;

            FlutterBridge.Instance.SendToFlutter("GameManager", "onGameStarted", levelData);
        }

        /// <summary>
        /// Pause the game
        /// </summary>
        public void PauseGame()
        {
            Debug.Log("Pausing game");
            currentState.isPaused = true;
            Time.timeScale = 0;

            FlutterBridge.Instance.SendToFlutter("GameManager", "onGamePaused", "true");
        }

        /// <summary>
        /// Resume the game
        /// </summary>
        public void ResumeGame()
        {
            Debug.Log("Resuming game");
            currentState.isPaused = false;
            Time.timeScale = 1;

            FlutterBridge.Instance.SendToFlutter("GameManager", "onGameResumed", "true");
        }

        /// <summary>
        /// Stop the game
        /// </summary>
        public void StopGame()
        {
            Debug.Log("Stopping game");
            currentState.isPlaying = false;
            currentState.isPaused = false;
            Time.timeScale = 1;

            FlutterBridge.Instance.SendToFlutter("GameManager", "onGameStopped", "true");
        }

        /// <summary>
        /// Update the score
        /// </summary>
        public void UpdateScore(string scoreData)
        {
            try
            {
                var data = JsonUtility.FromJson<ScoreData>(scoreData);
                currentState.score = data.score;

                Debug.Log($"Score updated: {currentState.score}");
                SendGameState();
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to update score: {e.Message}");
            }
        }

        /// <summary>
        /// Set the current level
        /// </summary>
        public void SetLevel(string levelData)
        {
            if (int.TryParse(levelData, out int level))
            {
                currentState.level = level;
                Debug.Log($"Level set to: {level}");
                SendGameState();
            }
        }

        /// <summary>
        /// Send game state to Flutter
        /// </summary>
        private void SendGameState()
        {
            string stateJson = JsonUtility.ToJson(currentState);
            FlutterBridge.Instance.SendToFlutter("GameManager", "onGameStateUpdate", stateJson);
        }

        /// <summary>
        /// Trigger game over
        /// </summary>
        public void GameOver(int finalScore)
        {
            currentState.isPlaying = false;

            var gameOverData = new GameOverData
            {
                score = finalScore,
                level = currentState.level,
                success = finalScore > 0
            };

            string dataJson = JsonUtility.ToJson(gameOverData);
            FlutterBridge.Instance.SendToFlutter("GameManager", "onGameOver", dataJson);
        }

        /// <summary>
        /// Send a custom event to Flutter
        /// </summary>
        public void SendCustomEvent(string eventName, string eventData)
        {
            FlutterBridge.Instance.SendToFlutter("GameManager", eventName, eventData);
        }

        // Data structures

        [Serializable]
        private class GameState
        {
            public bool isPlaying;
            public bool isPaused;
            public int score;
            public int level;
            public int lives;
        }

        [Serializable]
        private class ScoreData
        {
            public int score;
            public int stars;
        }

        [Serializable]
        private class GameOverData
        {
            public int score;
            public int level;
            public bool success;
        }
    }
}
