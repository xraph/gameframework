using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// High-performance message router for Flutter-Unity communication.
    /// 
    /// Provides automatic message routing to FlutterMonoBehaviour instances
    /// with cached delegates for zero-reflection dispatch in hot paths.
    /// </summary>
    public class MessageRouter : SingletonMonoBehaviour<MessageRouter>
    {
        #region Configuration

        [Header("Configuration")]
        [Tooltip("Enable detailed logging for debugging")]
        public bool enableDebugLogging = false;

        [Tooltip("Default throttle rate in Hz (0 = unlimited)")]
        public int defaultThrottleRate = 0;

        #endregion

        #region State

        // Target -> List of handlers (multiple objects can share a target name)
        private readonly Dictionary<string, List<RegisteredBehaviour>> _targetHandlers = 
            new Dictionary<string, List<RegisteredBehaviour>>();

        // Target:Method -> Cached handler for fast dispatch
        private readonly Dictionary<string, CachedHandler> _cachedHandlers = 
            new Dictionary<string, CachedHandler>();

        // Singleton targets -> Single handler
        private readonly Dictionary<string, RegisteredBehaviour> _singletonHandlers = 
            new Dictionary<string, RegisteredBehaviour>();

        // Throttle configurations
        private readonly Dictionary<string, ThrottleConfig> _throttleConfigs = 
            new Dictionary<string, ThrottleConfig>();

        // Throttle state (last call time)
        private readonly Dictionary<string, float> _lastCallTimes = 
            new Dictionary<string, float>();

        // Coalesced messages for throttled handlers
        private readonly Dictionary<string, CoalescedMessage> _coalescedMessages = 
            new Dictionary<string, CoalescedMessage>();

        // Lock for thread safety
        private readonly object _lock = new object();

        #endregion

        #region Initialization

        protected override void SingletonAwake()
        {
            base.SingletonAwake();

            // Subscribe to FlutterBridge messages
            FlutterBridge.OnFlutterMessage += OnFlutterMessage;

            Debug.Log("[MessageRouter] Initialized");
        }

        protected override void OnDestroy()
        {
            FlutterBridge.OnFlutterMessage -= OnFlutterMessage;
            base.OnDestroy();
        }

        void Update()
        {
            // Process coalesced messages
            ProcessCoalescedMessages();
        }

        #endregion

        #region Registration

        /// <summary>
        /// Register a FlutterMonoBehaviour for message routing.
        /// </summary>
        /// <param name="behaviour">The behaviour to register</param>
        /// <param name="targetName">Target name for routing</param>
        /// <param name="isSingleton">If true, only one instance handles messages</param>
        public void Register(FlutterMonoBehaviour behaviour, string targetName, bool isSingleton = false)
        {
            if (behaviour == null || string.IsNullOrEmpty(targetName))
            {
                Debug.LogError("[MessageRouter] Cannot register null behaviour or empty target name");
                return;
            }

            lock (_lock)
            {
                var registered = new RegisteredBehaviour
                {
                    Behaviour = behaviour,
                    TargetName = targetName,
                    IsSingleton = isSingleton
                };

                // Discover and cache FlutterMethod attributes
                CacheMethodHandlers(registered);

                if (isSingleton)
                {
                    if (_singletonHandlers.ContainsKey(targetName))
                    {
                        Debug.LogWarning($"[MessageRouter] Singleton '{targetName}' already registered, replacing");
                    }
                    _singletonHandlers[targetName] = registered;
                }
                else
                {
                    if (!_targetHandlers.TryGetValue(targetName, out var handlers))
                    {
                        handlers = new List<RegisteredBehaviour>();
                        _targetHandlers[targetName] = handlers;
                    }
                    handlers.Add(registered);
                }

                if (enableDebugLogging)
                {
                    Debug.Log($"[MessageRouter] Registered '{targetName}' with {registered.MethodHandlers.Count} methods");
                }
            }
        }

        /// <summary>
        /// Unregister a FlutterMonoBehaviour.
        /// </summary>
        public void Unregister(FlutterMonoBehaviour behaviour, string targetName)
        {
            if (behaviour == null || string.IsNullOrEmpty(targetName)) return;

            lock (_lock)
            {
                // Remove from singleton handlers
                if (_singletonHandlers.TryGetValue(targetName, out var singleton))
                {
                    if (singleton.Behaviour == behaviour)
                    {
                        _singletonHandlers.Remove(targetName);
                    }
                }

                // Remove from target handlers
                if (_targetHandlers.TryGetValue(targetName, out var handlers))
                {
                    handlers.RemoveAll(r => r.Behaviour == behaviour);
                    if (handlers.Count == 0)
                    {
                        _targetHandlers.Remove(targetName);
                    }
                }

                // Remove cached handlers for this behaviour
                var keysToRemove = new List<string>();
                foreach (var kvp in _cachedHandlers)
                {
                    if (kvp.Key.StartsWith(targetName + ":"))
                    {
                        // Check if any remaining behaviours handle this
                        bool hasHandler = _singletonHandlers.ContainsKey(targetName) ||
                                         (_targetHandlers.TryGetValue(targetName, out var remaining) && remaining.Count > 0);
                        if (!hasHandler)
                        {
                            keysToRemove.Add(kvp.Key);
                        }
                    }
                }
                foreach (var key in keysToRemove)
                {
                    _cachedHandlers.Remove(key);
                }

                if (enableDebugLogging)
                {
                    Debug.Log($"[MessageRouter] Unregistered '{targetName}'");
                }
            }
        }

        #endregion

        #region Method Caching

        private void CacheMethodHandlers(RegisteredBehaviour registered)
        {
            registered.MethodHandlers = new Dictionary<string, MethodHandler>();

            var type = registered.Behaviour.GetType();
            var methods = type.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);

            foreach (var method in methods)
            {
                var attr = method.GetCustomAttribute<FlutterMethodAttribute>();
                if (attr == null) continue;

                var handler = CreateMethodHandler(registered.Behaviour, method, attr);
                if (handler != null)
                {
                    registered.MethodHandlers[attr.MethodName] = handler;

                    // Also add to global cache for fast lookup
                    string cacheKey = $"{registered.TargetName}:{attr.MethodName}";
                    _cachedHandlers[cacheKey] = new CachedHandler
                    {
                        Handler = handler,
                        Registered = registered
                    };

                    // Apply throttle if specified
                    if (attr.Throttle > 0)
                    {
                        SetThrottle(registered.TargetName, attr.MethodName, attr.Throttle, attr.ThrottleStrategy);
                    }
                }
            }
        }

        private MethodHandler CreateMethodHandler(FlutterMonoBehaviour behaviour, MethodInfo method, FlutterMethodAttribute attr)
        {
            var parameters = method.GetParameters();

            // Determine handler type based on parameters
            if (parameters.Length == 0)
            {
                // No parameters - simple invocation
                var action = (Action)Delegate.CreateDelegate(typeof(Action), behaviour, method);
                return new MethodHandler
                {
                    Attribute = attr,
                    ParameterType = null,
                    InvokeNoParam = action
                };
            }
            else if (parameters.Length == 1)
            {
                var paramType = parameters[0].ParameterType;

                if (paramType == typeof(string))
                {
                    // String parameter
                    var action = (Action<string>)Delegate.CreateDelegate(typeof(Action<string>), behaviour, method);
                    return new MethodHandler
                    {
                        Attribute = attr,
                        ParameterType = typeof(string),
                        InvokeString = action
                    };
                }
                else if (paramType == typeof(byte[]))
                {
                    // Binary parameter
                    var action = (Action<byte[]>)Delegate.CreateDelegate(typeof(Action<byte[]>), behaviour, method);
                    return new MethodHandler
                    {
                        Attribute = attr,
                        ParameterType = typeof(byte[]),
                        InvokeBinary = action
                    };
                }
                else if (paramType.IsClass || paramType.IsValueType)
                {
                    // Typed parameter - needs deserialization
                    return new MethodHandler
                    {
                        Attribute = attr,
                        ParameterType = paramType,
                        Target = behaviour,
                        Method = method
                    };
                }
            }

            Debug.LogWarning($"[MessageRouter] Unsupported method signature for '{attr.MethodName}': {method}");
            return null;
        }

        #endregion

        #region Message Dispatch

        private void OnFlutterMessage(string target, string method, string data)
        {
            try
            {
                Dispatch(target, method, data);
            }
            catch (Exception e)
            {
                Debug.LogError($"[MessageRouter] Error dispatching message to {target}:{method}: {e.Message}\n{e.StackTrace}");
            }
        }

        /// <summary>
        /// Dispatch a message to the appropriate handler.
        /// </summary>
        public void Dispatch(string target, string method, string data)
        {
            string cacheKey = $"{target}:{method}";

            // Check throttle
            if (!ShouldDispatch(cacheKey, data))
            {
                return;
            }

            // Fast path: check cached handlers first
            if (_cachedHandlers.TryGetValue(cacheKey, out var cached))
            {
                InvokeHandler(cached.Handler, data);
                return;
            }

            // Slow path: find handler from registered behaviours
            bool foundHandler = false;
            lock (_lock)
            {
                // Check singleton handlers
                if (_singletonHandlers.TryGetValue(target, out var singleton))
                {
                    if (singleton.MethodHandlers.TryGetValue(method, out var handler))
                    {
                        InvokeHandler(handler, data);
                        return;
                    }
                }

                // Check multi-instance handlers
                if (_targetHandlers.TryGetValue(target, out var handlers))
                {
                    foreach (var registered in handlers)
                    {
                        if (registered.MethodHandlers.TryGetValue(method, out var handler))
                        {
                            InvokeHandler(handler, data);
                            foundHandler = true;
                            // Don't return - broadcast to all handlers
                        }
                    }
                    if (foundHandler) return;
                }
            }

            // NEW: Try type-based discovery as fallback
            if (TryDiscoverAndRoute(target, method, data))
            {
                return;
            }

            // Fallback: try direct SendMessage to GameObject
            FallbackToGameObject(target, method, data);
        }

        /// <summary>
        /// Attempt to discover and route message to a FlutterMonoBehaviour by type name.
        /// This handles cases where the target wasn't registered yet or registration failed.
        /// </summary>
        private bool TryDiscoverAndRoute(string target, string method, string data)
        {
            // Find any FlutterMonoBehaviour with matching type name or TargetName
            var allBehaviours = FindObjectsOfType<FlutterMonoBehaviour>();
            
            foreach (var behaviour in allBehaviours)
            {
                var type = behaviour.GetType();
                
                // Match by type name or by the behaviour's TargetName property
                // Use reflection to get TargetName since it's protected
                string behaviourTargetName = GetTargetName(behaviour);
                
                if (type.Name == target || behaviourTargetName == target)
                {
                    // Found a matching behaviour - auto-register it
                    bool isSingleton = GetIsSingleton(behaviour);
                    
                    lock (_lock)
                    {
                        if (!_targetHandlers.ContainsKey(target) && !_singletonHandlers.ContainsKey(target))
                        {
                            Debug.LogWarning($"[MessageRouter] Auto-registering discovered target: '{target}' " +
                                $"(GameObject: '{behaviour.gameObject.name}', Type: {type.Name})");
                            
                            var registered = new RegisteredBehaviour
                            {
                                Behaviour = behaviour,
                                TargetName = target,
                                IsSingleton = isSingleton
                            };
                            
                            CacheMethodHandlers(registered);
                            
                            if (isSingleton)
                            {
                                _singletonHandlers[target] = registered;
                            }
                            else
                            {
                                if (!_targetHandlers.TryGetValue(target, out var handlers))
                                {
                                    handlers = new List<RegisteredBehaviour>();
                                    _targetHandlers[target] = handlers;
                                }
                                handlers.Add(registered);
                            }
                        }
                    }
                    
                    // Try to dispatch again now that it's registered
                    string cacheKey = $"{target}:{method}";
                    if (_cachedHandlers.TryGetValue(cacheKey, out var cached))
                    {
                        InvokeHandler(cached.Handler, data);
                        return true;
                    }
                    
                    // Check the registered handlers
                    lock (_lock)
                    {
                        if (_singletonHandlers.TryGetValue(target, out var singleton))
                        {
                            if (singleton.MethodHandlers.TryGetValue(method, out var handler))
                            {
                                InvokeHandler(handler, data);
                                return true;
                            }
                        }
                        
                        if (_targetHandlers.TryGetValue(target, out var handlers))
                        {
                            foreach (var registered in handlers)
                            {
                                if (registered.MethodHandlers.TryGetValue(method, out var handler))
                                {
                                    InvokeHandler(handler, data);
                                    return true;
                                }
                            }
                        }
                    }
                }
            }
            
            return false;
        }

        /// <summary>
        /// Get the TargetName property from a FlutterMonoBehaviour using reflection.
        /// </summary>
        private string GetTargetName(FlutterMonoBehaviour behaviour)
        {
            try
            {
                var property = behaviour.GetType().GetProperty("TargetName", 
                    System.Reflection.BindingFlags.Instance | 
                    System.Reflection.BindingFlags.NonPublic | 
                    System.Reflection.BindingFlags.Public);
                
                if (property != null)
                {
                    return property.GetValue(behaviour) as string ?? behaviour.gameObject.name;
                }
            }
            catch { }
            
            return behaviour.gameObject.name;
        }

        /// <summary>
        /// Get the IsSingleton property from a FlutterMonoBehaviour using reflection.
        /// </summary>
        private bool GetIsSingleton(FlutterMonoBehaviour behaviour)
        {
            try
            {
                var property = behaviour.GetType().GetProperty("IsSingleton", 
                    System.Reflection.BindingFlags.Instance | 
                    System.Reflection.BindingFlags.NonPublic | 
                    System.Reflection.BindingFlags.Public);
                
                if (property != null)
                {
                    return (bool)(property.GetValue(behaviour) ?? false);
                }
            }
            catch { }
            
            return false;
        }

        private void InvokeHandler(MethodHandler handler, string data)
        {
            try
            {
                if (handler.InvokeNoParam != null)
                {
                    handler.InvokeNoParam();
                }
                else if (handler.InvokeString != null)
                {
                    handler.InvokeString(data);
                }
                else if (handler.InvokeBinary != null)
                {
                    byte[] binary = DecodeBinaryData(data, handler.Attribute.AcceptsBinary);
                    if (binary != null)
                    {
                        handler.InvokeBinary(binary);
                    }
                }
                else if (handler.Method != null && handler.Target != null)
                {
                    // Typed parameter - deserialize and invoke
                    object param = FlutterSerialization.Deserialize(data, handler.ParameterType);
                    handler.Method.Invoke(handler.Target, new[] { param });
                }

                if (enableDebugLogging)
                {
                    Debug.Log($"[MessageRouter] Dispatched: {handler.Attribute.MethodName}");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[MessageRouter] Handler invocation failed: {e.Message}\n{e.StackTrace}");
            }
        }

        private byte[] DecodeBinaryData(string data, bool expectBinary)
        {
            if (string.IsNullOrEmpty(data)) return null;

            try
            {
                // Try to parse as JSON envelope first
                if (data.StartsWith("{"))
                {
                    var envelope = JsonUtility.FromJson<BinaryEnvelope>(data);
                    if (envelope != null && !string.IsNullOrEmpty(envelope.data))
                    {
                        byte[] decoded = Convert.FromBase64String(envelope.data);

                        if (envelope.dataType == "compressedBinary")
                        {
                            decoded = BinaryMessageProtocol.Decompress(decoded);
                        }

                        return decoded;
                    }
                }

                // Try direct base64 decode
                if (expectBinary)
                {
                    return Convert.FromBase64String(data);
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[MessageRouter] Binary decode failed: {e.Message}");
            }

            return null;
        }

        private void FallbackToGameObject(string target, string method, string data)
        {
            GameObject targetObject = GameObject.Find(target);
            if (targetObject != null)
            {
                targetObject.SendMessage(method, data, SendMessageOptions.DontRequireReceiver);

                if (enableDebugLogging)
                {
                    Debug.Log($"[MessageRouter] Fallback SendMessage to GameObject '{target}'");
                }
            }
            else
            {
                // Provide helpful error message with suggestions
                LogRoutingError(target, method);
            }
        }

        /// <summary>
        /// Log a helpful error message when message routing fails.
        /// </summary>
        private void LogRoutingError(string target, string method)
        {
            // Build helpful error message
            var message = new System.Text.StringBuilder();
            message.AppendLine($"[MessageRouter] Target '{target}' not found for method '{method}'!");
            message.AppendLine();
            message.AppendLine("Possible fixes:");
            message.AppendLine($"  1. Create a GameObject with a script that has TargetName = \"{target}\"");
            message.AppendLine($"  2. Create a GameObject named \"{target}\" with the appropriate script");
            message.AppendLine($"  3. Ensure your FlutterMonoBehaviour registers before messages are sent");
            message.AppendLine($"  4. Add \"{target}\" to GameFrameworkBootstrapper.autoCreateTargets");
            message.AppendLine();
            
            // Find similar targets that might be a typo
            var registeredTargets = new List<string>();
            lock (_lock)
            {
                registeredTargets.AddRange(_singletonHandlers.Keys);
                registeredTargets.AddRange(_targetHandlers.Keys);
            }
            
            if (registeredTargets.Count > 0)
            {
                message.AppendLine($"Registered targets: {string.Join(", ", registeredTargets)}");
            }
            else
            {
                message.AppendLine("No targets are currently registered.");
            }
            
            // Try to find GameObjects with scripts that have similar names
            var allBehaviours = FindObjectsOfType<FlutterMonoBehaviour>();
            if (allBehaviours.Length > 0)
            {
                message.AppendLine();
                message.AppendLine("Found FlutterMonoBehaviour instances in scene:");
                foreach (var behaviour in allBehaviours)
                {
                    string behaviourTarget = GetTargetName(behaviour);
                    message.AppendLine($"  - GameObject '{behaviour.gameObject.name}' with TargetName '{behaviourTarget}' ({behaviour.GetType().Name})");
                }
            }
            else
            {
                message.AppendLine();
                message.AppendLine("No FlutterMonoBehaviour instances found in scene.");
                message.AppendLine("Did you forget to add a script to a GameObject?");
            }
            
            Debug.LogError(message.ToString());
        }

        #endregion

        #region Throttling

        /// <summary>
        /// Set throttle configuration for a specific method.
        /// </summary>
        public void SetThrottle(string target, string method, int rateHz, ThrottleStrategy strategy = ThrottleStrategy.KeepLatest)
        {
            string key = $"{target}:{method}";
            _throttleConfigs[key] = new ThrottleConfig
            {
                RateHz = rateHz,
                Strategy = strategy,
                IntervalSeconds = rateHz > 0 ? 1f / rateHz : 0f
            };

            if (enableDebugLogging)
            {
                Debug.Log($"[MessageRouter] Set throttle for {key}: {rateHz}Hz, Strategy: {strategy}");
            }
        }

        private bool ShouldDispatch(string key, string data)
        {
            if (!_throttleConfigs.TryGetValue(key, out var config))
            {
                return true; // No throttle configured
            }

            if (config.RateHz <= 0)
            {
                return true; // Unlimited
            }

            float now = Time.unscaledTime;

            if (!_lastCallTimes.TryGetValue(key, out float lastCall))
            {
                _lastCallTimes[key] = now;
                return true;
            }

            float elapsed = now - lastCall;

            if (elapsed >= config.IntervalSeconds)
            {
                _lastCallTimes[key] = now;
                return true;
            }

            // Apply throttle strategy
            switch (config.Strategy)
            {
                case ThrottleStrategy.Drop:
                    return false;

                case ThrottleStrategy.KeepLatest:
                    _coalescedMessages[key] = new CoalescedMessage
                    {
                        Key = key,
                        Data = data,
                        Timestamp = now
                    };
                    return false;

                case ThrottleStrategy.KeepFirst:
                    if (!_coalescedMessages.ContainsKey(key))
                    {
                        _coalescedMessages[key] = new CoalescedMessage
                        {
                            Key = key,
                            Data = data,
                            Timestamp = now
                        };
                    }
                    return false;

                case ThrottleStrategy.Queue:
                    // Queue strategy would need a different implementation
                    // For now, treat as KeepLatest
                    _coalescedMessages[key] = new CoalescedMessage
                    {
                        Key = key,
                        Data = data,
                        Timestamp = now
                    };
                    return false;
            }

            return false;
        }

        private void ProcessCoalescedMessages()
        {
            if (_coalescedMessages.Count == 0) return;

            float now = Time.unscaledTime;
            var toProcess = new List<string>();

            foreach (var kvp in _coalescedMessages)
            {
                string key = kvp.Key;
                if (!_throttleConfigs.TryGetValue(key, out var config)) continue;
                if (!_lastCallTimes.TryGetValue(key, out float lastCall)) continue;

                float elapsed = now - lastCall;
                if (elapsed >= config.IntervalSeconds)
                {
                    toProcess.Add(key);
                }
            }

            foreach (var key in toProcess)
            {
                if (_coalescedMessages.TryGetValue(key, out var msg))
                {
                    _coalescedMessages.Remove(key);
                    _lastCallTimes[key] = now;

                    // Dispatch the coalesced message
                    var parts = key.Split(':');
                    if (parts.Length == 2)
                    {
                        if (_cachedHandlers.TryGetValue(key, out var cached))
                        {
                            InvokeHandler(cached.Handler, msg.Data);
                        }
                    }
                }
            }
        }

        #endregion

        #region Internal Types

        private class RegisteredBehaviour
        {
            public FlutterMonoBehaviour Behaviour;
            public string TargetName;
            public bool IsSingleton;
            public Dictionary<string, MethodHandler> MethodHandlers;
        }

        private class MethodHandler
        {
            public FlutterMethodAttribute Attribute;
            public Type ParameterType;

            // Cached delegates for fast invocation
            public Action InvokeNoParam;
            public Action<string> InvokeString;
            public Action<byte[]> InvokeBinary;

            // Fallback for typed parameters
            public object Target;
            public MethodInfo Method;
        }

        private class CachedHandler
        {
            public MethodHandler Handler;
            public RegisteredBehaviour Registered;
        }

        private class ThrottleConfig
        {
            public int RateHz;
            public ThrottleStrategy Strategy;
            public float IntervalSeconds;
        }

        private class CoalescedMessage
        {
            public string Key;
            public string Data;
            public float Timestamp;
        }

        [Serializable]
        private class BinaryEnvelope
        {
            public string dataType;
            public string data;
        }

        #endregion
    }
}
