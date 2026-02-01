using System;
using System.Collections.Generic;
using UnityEngine;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Demonstrates state synchronization patterns with Flutter.
    /// 
    /// Features:
    /// - Full state synchronization
    /// - Delta compression (only send changed fields)
    /// - Periodic state broadcasting
    /// - State versioning
    /// 
    /// Flutter usage:
    /// ```dart
    /// // Request full state
    /// await controller.sendJsonMessage('StateManager', 'requestState', {});
    /// 
    /// // Subscribe to state updates
    /// await controller.sendJsonMessage('StateManager', 'subscribe', {
    ///   'deltaOnly': true,
    ///   'intervalMs': 100,
    /// });
    /// 
    /// // Update state from Flutter
    /// await controller.sendJsonMessage('StateManager', 'updateState', {
    ///   'playerHealth': 75,
    ///   'score': 1500,
    /// });
    /// 
    /// // Listen for state updates
    /// controller.messageStream.listen((msg) {
    ///   if (msg.method == 'onStateUpdate') {
    ///     final state = jsonDecode(msg.data);
    ///     // state may be full or delta depending on subscription
    ///   }
    /// });
    /// ```
    /// </summary>
    public class StateManager : FlutterMonoBehaviour
    {
        protected override string TargetName => "StateManager";
        protected override bool IsSingleton => true;

        [Header("State Settings")]
        [SerializeField] private float defaultSyncInterval = 0.1f; // 10Hz default
        [SerializeField] private bool autoStartSync = false;

        // Current game state
        private GameStateData _currentState;
        private int _stateVersion = 0;

        // Subscription management
        private bool _isSubscribed = false;
        private bool _deltaOnly = true;
        private float _syncInterval = 0.1f;
        private float _lastSyncTime = 0f;

        // Previous state for delta computation
        private GameStateData _previousState;

        protected override void Awake()
        {
            base.Awake();

            // Initialize state
            _currentState = new GameStateData
            {
                playerId = Guid.NewGuid().ToString().Substring(0, 8),
                playerName = "Player",
                playerHealth = 100,
                playerMaxHealth = 100,
                playerPosition = Vector3.zero,
                playerRotation = Quaternion.identity,
                score = 0,
                level = 1,
                isAlive = true,
                isPaused = false
            };

            EnableDeltaCompression = true;
        }

        void Start()
        {
            if (autoStartSync)
            {
                StartSyncBroadcast(defaultSyncInterval);
            }
        }

        void Update()
        {
            // Update position/rotation from transform
            _currentState.playerPosition = transform.position;
            _currentState.playerRotation = transform.rotation;
            _currentState.gameTime = Time.time;

            // Periodic sync broadcast
            if (_isSubscribed && Time.time - _lastSyncTime >= _syncInterval)
            {
                BroadcastState();
                _lastSyncTime = Time.time;
            }
        }

        #region State Queries

        /// <summary>
        /// Get full current state.
        /// </summary>
        [FlutterMethod("requestState")]
        public void RequestState()
        {
            _stateVersion++;
            _currentState.version = _stateVersion;

            SendToFlutter("onState", _currentState);
        }

        /// <summary>
        /// Get specific state property.
        /// </summary>
        [FlutterMethod("getProperty")]
        public void GetProperty(PropertyRequest request)
        {
            object value = GetPropertyValue(request.property);

            SendToFlutter("onProperty", new PropertyResponse
            {
                property = request.property,
                value = value?.ToString() ?? "null",
                type = value?.GetType().Name ?? "null"
            });
        }

        private object GetPropertyValue(string property)
        {
            switch (property)
            {
                case "health": return _currentState.playerHealth;
                case "maxHealth": return _currentState.playerMaxHealth;
                case "score": return _currentState.score;
                case "level": return _currentState.level;
                case "position": return _currentState.playerPosition;
                case "isAlive": return _currentState.isAlive;
                case "isPaused": return _currentState.isPaused;
                default: return null;
            }
        }

        #endregion

        #region State Updates

        /// <summary>
        /// Update state from Flutter.
        /// </summary>
        [FlutterMethod("updateState")]
        public void UpdateState(StateUpdateMessage update)
        {
            Debug.Log($"[StateManager] Update received: {update.updates?.Length ?? 0} updates");

            if (update.updates == null) return;

            foreach (var u in update.updates)
            {
                ApplyUpdate(u.property, u.value);
            }

            _stateVersion++;
            _currentState.version = _stateVersion;

            // Confirm update
            SendToFlutter("onStateUpdated", new { version = _stateVersion, success = true });
        }

        /// <summary>
        /// Set a single property.
        /// </summary>
        [FlutterMethod("setProperty")]
        public void SetProperty(PropertyUpdate update)
        {
            ApplyUpdate(update.property, update.value);

            _stateVersion++;
            _currentState.version = _stateVersion;

            SendToFlutter("onPropertySet", new { property = update.property, success = true });
        }

        private void ApplyUpdate(string property, string value)
        {
            try
            {
                switch (property)
                {
                    case "health":
                    case "playerHealth":
                        _currentState.playerHealth = int.Parse(value);
                        break;
                    case "score":
                        _currentState.score = int.Parse(value);
                        break;
                    case "level":
                        _currentState.level = int.Parse(value);
                        break;
                    case "playerName":
                        _currentState.playerName = value;
                        break;
                    case "isAlive":
                        _currentState.isAlive = bool.Parse(value);
                        break;
                    case "isPaused":
                        _currentState.isPaused = bool.Parse(value);
                        break;
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[StateManager] Failed to apply update {property}={value}: {e.Message}");
            }
        }

        #endregion

        #region Subscription & Broadcasting

        /// <summary>
        /// Subscribe to state updates.
        /// </summary>
        [FlutterMethod("subscribe")]
        public void Subscribe(SubscriptionConfig config)
        {
            _isSubscribed = true;
            _deltaOnly = config.deltaOnly;
            _syncInterval = config.intervalMs > 0 ? config.intervalMs / 1000f : defaultSyncInterval;
            _lastSyncTime = Time.time;

            // Store current state as baseline for delta
            _previousState = CloneState(_currentState);

            Debug.Log($"[StateManager] Subscribed: delta={_deltaOnly}, interval={_syncInterval}s");

            SendToFlutter("onSubscribed", new { success = true, intervalMs = _syncInterval * 1000 });
        }

        /// <summary>
        /// Unsubscribe from state updates.
        /// </summary>
        [FlutterMethod("unsubscribe")]
        public void Unsubscribe()
        {
            _isSubscribed = false;
            Debug.Log("[StateManager] Unsubscribed");

            SendToFlutter("onUnsubscribed", new { success = true });
        }

        private void BroadcastState()
        {
            if (_deltaOnly)
            {
                // Send only changed fields
                var delta = ComputeDelta();
                if (!string.IsNullOrEmpty(delta) && delta != "{}")
                {
                    _stateVersion++;
                    SendToFlutter("onStateDelta", new DeltaMessage
                    {
                        version = _stateVersion,
                        delta = delta
                    });
                }

                // Update previous state
                _previousState = CloneState(_currentState);
            }
            else
            {
                // Send full state
                _stateVersion++;
                _currentState.version = _stateVersion;
                SendToFlutter("onStateUpdate", _currentState);
            }
        }

        private string ComputeDelta()
        {
            if (_previousState == null) return FlutterSerialization.Serialize(_currentState);
            return FlutterSerialization.ComputeDelta(_previousState, _currentState);
        }

        private GameStateData CloneState(GameStateData state)
        {
            return new GameStateData
            {
                version = state.version,
                playerId = state.playerId,
                playerName = state.playerName,
                playerHealth = state.playerHealth,
                playerMaxHealth = state.playerMaxHealth,
                playerPosition = state.playerPosition,
                playerRotation = state.playerRotation,
                score = state.score,
                level = state.level,
                isAlive = state.isAlive,
                isPaused = state.isPaused,
                gameTime = state.gameTime
            };
        }

        #endregion

        #region Manual Control

        /// <summary>
        /// Start periodic state broadcasting.
        /// </summary>
        public void StartSyncBroadcast(float intervalSeconds)
        {
            _isSubscribed = true;
            _syncInterval = intervalSeconds;
            _lastSyncTime = Time.time;
            _previousState = CloneState(_currentState);
        }

        /// <summary>
        /// Stop state broadcasting.
        /// </summary>
        public void StopSyncBroadcast()
        {
            _isSubscribed = false;
        }

        /// <summary>
        /// Force immediate state broadcast.
        /// </summary>
        public void ForceBroadcast()
        {
            BroadcastState();
        }

        #endregion

        #region Game State Helpers

        /// <summary>
        /// Apply damage to player.
        /// </summary>
        public void TakeDamage(int amount)
        {
            _currentState.playerHealth = Mathf.Max(0, _currentState.playerHealth - amount);
            if (_currentState.playerHealth <= 0)
            {
                _currentState.isAlive = false;
            }
        }

        /// <summary>
        /// Heal player.
        /// </summary>
        public void Heal(int amount)
        {
            _currentState.playerHealth = Mathf.Min(_currentState.playerMaxHealth, _currentState.playerHealth + amount);
        }

        /// <summary>
        /// Add score.
        /// </summary>
        public void AddScore(int points)
        {
            _currentState.score += points;
        }

        /// <summary>
        /// Level up.
        /// </summary>
        public void LevelUp()
        {
            _currentState.level++;
        }

        #endregion

        #region Data Types

        [Serializable]
        public class GameStateData
        {
            public int version;
            public string playerId;
            public string playerName;
            public int playerHealth;
            public int playerMaxHealth;
            public Vector3 playerPosition;
            public Quaternion playerRotation;
            public int score;
            public int level;
            public bool isAlive;
            public bool isPaused;
            public float gameTime;
        }

        [Serializable]
        public class PropertyRequest
        {
            public string property;
        }

        [Serializable]
        public class PropertyResponse
        {
            public string property;
            public string value;
            public string type;
        }

        [Serializable]
        public class PropertyUpdate
        {
            public string property;
            public string value;
        }

        [Serializable]
        public class StateUpdateMessage
        {
            public PropertyUpdate[] updates;
        }

        [Serializable]
        public class SubscriptionConfig
        {
            public bool deltaOnly;
            public int intervalMs;
        }

        [Serializable]
        public class DeltaMessage
        {
            public int version;
            public string delta;
        }

        #endregion
    }
}
