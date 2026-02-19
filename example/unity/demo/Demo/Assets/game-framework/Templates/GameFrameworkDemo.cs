using System;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Interactive rotating cube demo for Game Framework with physics-based touch controls.
    /// 
    /// FEATURES:
    /// - Swipe/touch to spin the cube with physics-based momentum
    /// - Speed gradually decays back to the Flutter-set target speed
    /// - Real-time speed feedback sent to Flutter
    /// - Compact HUD showing current state
    /// 
    /// SETUP OPTIONS (choose one):
    /// 
    /// 1. AUTOMATIC (Recommended):
    ///    - GameFrameworkBootstrapper auto-creates this at runtime
    ///    - Messages from Flutter routed via MessageRouter
    /// 
    /// 2. MANUAL:
    ///    - Create empty GameObject, attach this script
    ///    - Routing uses TargetName property, not GameObject name
    /// 
    /// 3. EDITOR TOOLS:
    ///    - "Game Framework > Quick Fix > Add Demo Object" menu
    ///    - "Game Framework > Validate Scene" to check config
    /// </summary>
    public class GameFrameworkDemo : FlutterMonoBehaviour
    {
        #region Configuration

        [Header("Cube Configuration")]
        [Tooltip("Initial rotation speed")]
        [SerializeField] private float initialSpeed = 50f;

        [Tooltip("Cube color")]
        [SerializeField] private Color cubeColor = new Color(0.3f, 0.6f, 1f);

        [Header("Physics Configuration")]
        [Tooltip("How much swipe velocity affects rotation (multiplier)")]
        [SerializeField] private float swipeSensitivity = 0.5f;

        [Tooltip("Maximum speed from swipe")]
        [SerializeField] private float maxSwipeSpeed = 720f;

        [Tooltip("How fast the speed decays back to target (per second)")]
        [SerializeField] private float speedDecayRate = 60f;

        [Tooltip("Send speed updates to Flutter at this rate (Hz)")]
        [SerializeField] private float speedUpdateRate = 10f;

        [Header("UI Configuration")]
        [Tooltip("Enable verbose logging")]
        [SerializeField] private bool verboseLogging = true;

        [Tooltip("Show compact HUD")]
        [SerializeField] private bool showHud = true;

        #endregion

        #region FlutterMonoBehaviour Overrides

        protected override string TargetName => "GameFrameworkDemo";
        protected override bool IsSingleton => true;

        #endregion

        #region Private Fields

        private GameObject _cube;
        private GameObject _uiCanvas;
        
        // Compact HUD elements
        private TextMeshProUGUI _hudSpeedText;
        private TextMeshProUGUI _hudStatusText;
        private Image _hudBackground;
        private Image _touchIndicator;
        
        // Rotation state
        private float _targetSpeed = 50f;      // Speed set by Flutter slider
        private float _currentSpeed = 50f;     // Actual current speed (affected by touch)
        private Vector3 _rotationAxis = Vector3.up;
        private string _lastMessage = "Ready";
        private string _lastDirection = "---";
        private int _messageCount = 0;
        
        // Touch/Swipe state
        private Vector2 _touchStartPos;
        private Vector2 _lastTouchPos;
        private float _touchStartTime;
        private bool _isTouching = false;
        private float _swipeVelocity = 0f;
        private bool _isDecaying = false;
        
        // Speed reporting
        private float _lastSpeedUpdateTime;
        private float _lastReportedSpeed;
        
        // Colors
        private Color _fromFlutterColor = new Color(0.2f, 0.8f, 0.4f);
        private Color _toFlutterColor = new Color(0.9f, 0.4f, 0.2f);

        #endregion

        #region Unity Lifecycle

        protected override void Awake()
        {
            EnableDebugLogging = verboseLogging;
            base.Awake();
            
            _targetSpeed = initialSpeed;
            _currentSpeed = initialSpeed;
            
            Log("GameFrameworkDemo: Initialized");
            LogToAndroid("GameFrameworkDemo", "Awake() called");
        }

        void Start()
        {
            LogToAndroid("GameFrameworkDemo", "Start() called - creating cube and HUD");
            CreateCube();
            CreateCompactHUD();
            LogToAndroid("GameFrameworkDemo", "Calling NotifyFlutterReady()");
            NotifyFlutterReady();
        }
        
        /// <summary>
        /// Log directly to Android logcat, bypassing Unity's Debug.Log
        /// </summary>
        private void LogToAndroid(string tag, string message)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using (AndroidJavaClass logClass = new AndroidJavaClass("android.util.Log"))
                {
                    logClass.CallStatic<int>("d", "Unity_" + tag, message);
                }
            }
            catch { }
#endif
        }

        void Update()
        {
            // Handle touch input
            HandleTouchInput();
            
            // Handle speed decay back to target
            HandleSpeedDecay();
            
            // Rotate the cube
            if (_cube != null)
            {
                _cube.transform.Rotate(_rotationAxis, _currentSpeed * Time.deltaTime);
            }
            
            // Update HUD
            UpdateHUD();
            
            // Send speed updates to Flutter
            SendSpeedUpdateToFlutter();
        }

        protected override void OnDestroy()
        {
            Log("GameFrameworkDemo: Destroyed");
            base.OnDestroy();
        }

        #endregion

        #region Touch Input Handling

        private void HandleTouchInput()
        {
            // Handle mouse input (for editor testing) and touch
            bool touchBegan = false;
            bool touchMoved = false;
            bool touchEnded = false;
            Vector2 touchPosition = Vector2.zero;

#if UNITY_EDITOR
            // Mouse input for editor
            if (Input.GetMouseButtonDown(0))
            {
                touchBegan = true;
                touchPosition = Input.mousePosition;
            }
            else if (Input.GetMouseButton(0))
            {
                touchMoved = true;
                touchPosition = Input.mousePosition;
            }
            else if (Input.GetMouseButtonUp(0))
            {
                touchEnded = true;
                touchPosition = Input.mousePosition;
            }
#else
            // Touch input for device
            if (Input.touchCount > 0)
            {
                Touch touch = Input.GetTouch(0);
                touchPosition = touch.position;
                
                switch (touch.phase)
                {
                    case TouchPhase.Began:
                        touchBegan = true;
                        break;
                    case TouchPhase.Moved:
                    case TouchPhase.Stationary:
                        touchMoved = true;
                        break;
                    case TouchPhase.Ended:
                    case TouchPhase.Canceled:
                        touchEnded = true;
                        break;
                }
            }
#endif

            if (touchBegan)
            {
                OnTouchBegan(touchPosition);
            }
            else if (touchMoved && _isTouching)
            {
                OnTouchMoved(touchPosition);
            }
            else if (touchEnded && _isTouching)
            {
                OnTouchEnded(touchPosition);
            }
        }

        private void OnTouchBegan(Vector2 position)
        {
            _touchStartPos = position;
            _lastTouchPos = position;
            _touchStartTime = Time.time;
            _isTouching = true;
            _isDecaying = false;
            
            // Show touch indicator
            if (_touchIndicator != null)
            {
                _touchIndicator.color = new Color(0.3f, 0.7f, 1f, 0.8f);
            }
        }

        private void OnTouchMoved(Vector2 position)
        {
            Vector2 delta = position - _lastTouchPos;
            _lastTouchPos = position;
            
            // Calculate swipe velocity based on horizontal movement
            // Positive = clockwise (when looking down Y axis)
            float swipeSpeed = delta.x * swipeSensitivity;
            
            // Apply directly to current speed for immediate feedback
            _currentSpeed = Mathf.Clamp(_currentSpeed + swipeSpeed, -maxSwipeSpeed, maxSwipeSpeed);
        }

        private void OnTouchEnded(Vector2 position)
        {
            // Calculate final swipe velocity
            float duration = Time.time - _touchStartTime;
            if (duration > 0.01f)
            {
                Vector2 totalDelta = position - _touchStartPos;
                _swipeVelocity = (totalDelta.x / duration) * swipeSensitivity * 0.1f;
                
                // Apply momentum
                _currentSpeed = Mathf.Clamp(_currentSpeed + _swipeVelocity, -maxSwipeSpeed, maxSwipeSpeed);
            }
            
            _isTouching = false;
            _isDecaying = true;
            
            // Update UI to show touch ended
            if (_touchIndicator != null)
            {
                _touchIndicator.color = new Color(0.5f, 0.5f, 0.5f, 0.3f);
            }
            
            _lastMessage = "Spin!";
            _lastDirection = "TOUCH";
            
            Log($"Touch ended: velocity={_swipeVelocity:F1}, speed={_currentSpeed:F1}");
        }

        private void HandleSpeedDecay()
        {
            if (!_isTouching && _isDecaying)
            {
                // Smoothly decay current speed back to target speed
                float diff = _targetSpeed - _currentSpeed;
                
                if (Mathf.Abs(diff) < 0.5f)
                {
                    // Close enough, snap to target
                    _currentSpeed = _targetSpeed;
                    _isDecaying = false;
                }
                else
                {
                    // Decay towards target
                    float decayAmount = speedDecayRate * Time.deltaTime;
                    _currentSpeed = Mathf.MoveTowards(_currentSpeed, _targetSpeed, decayAmount);
                }
            }
        }

        #endregion

        #region Speed Reporting to Flutter

        private void SendSpeedUpdateToFlutter()
        {
            // Throttle updates
            if (Time.time - _lastSpeedUpdateTime < (1f / speedUpdateRate))
                return;
                
            // Only send if speed changed significantly
            if (Mathf.Abs(_currentSpeed - _lastReportedSpeed) < 0.5f)
                return;
            
            _lastSpeedUpdateTime = Time.time;
            _lastReportedSpeed = _currentSpeed;
            
            // Send current speed to Flutter
            SendToFlutter("onCurrentSpeed", new CurrentSpeedData
            {
                speed = _currentSpeed,
                rpm = (_currentSpeed / 360f) * 60f,
                targetSpeed = _targetSpeed,
                isTouch = _isDecaying || _isTouching
            });
        }

        #endregion

        #region Scene Setup

        private void CreateCube()
        {
            _cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            _cube.name = "RotatingCube";
            _cube.transform.position = Vector3.zero;
            _cube.transform.localScale = Vector3.one * 2f;
            
            var renderer = _cube.GetComponent<Renderer>();
            if (renderer != null)
            {
                var shader = Shader.Find("Standard") ?? Shader.Find("Unlit/Color") ?? Shader.Find("Diffuse");
                if (shader == null)
                {
                    LogError("Could not find any shader!");
                }
                else
                {
                    renderer.material = new Material(shader);
                    renderer.material.color = cubeColor;
                    
                    if (shader.name == "Standard")
                    {
                        renderer.material.SetFloat("_Metallic", 0.5f);
                        renderer.material.SetFloat("_Glossiness", 0.8f);
                    }
                }
            }
            
            var camera = Camera.main;
            if (camera != null)
            {
                camera.transform.position = new Vector3(0, 2, -6);
                camera.transform.LookAt(_cube.transform);
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(0.1f, 0.1f, 0.15f);
            }
            
            var light = new GameObject("DirectionalLight");
            var lightComp = light.AddComponent<Light>();
            lightComp.type = LightType.Directional;
            lightComp.intensity = 1.2f;
            light.transform.rotation = Quaternion.Euler(50, -30, 0);
            
            Log("Cube created successfully");
        }

        private void CreateCompactHUD()
        {
            if (!showHud) return;
            
            _uiCanvas = new GameObject("DemoCanvas");
            var canvas = _uiCanvas.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 100;
            
            var canvasScaler = _uiCanvas.AddComponent<CanvasScaler>();
            canvasScaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            canvasScaler.referenceResolution = new Vector2(1920, 1080);
            
            _uiCanvas.AddComponent<GraphicRaycaster>();
            
            // Create compact HUD panel (bottom-left corner)
            var hudPanel = new GameObject("HudPanel");
            hudPanel.transform.SetParent(_uiCanvas.transform, false);
            
            var panelRect = hudPanel.AddComponent<RectTransform>();
            panelRect.anchorMin = new Vector2(0f, 0f);
            panelRect.anchorMax = new Vector2(0f, 0f);
            panelRect.pivot = new Vector2(0f, 0f);
            panelRect.anchoredPosition = new Vector2(20, 120); // Above Flutter's panel
            panelRect.sizeDelta = new Vector2(200, 70);
            
            _hudBackground = hudPanel.AddComponent<Image>();
            _hudBackground.color = new Color(0, 0, 0, 0.6f);
            
            // Add rounded corners effect via child
            var cornerMask = hudPanel.AddComponent<UnityEngine.UI.Outline>();
            cornerMask.effectColor = new Color(1, 1, 1, 0.1f);
            cornerMask.effectDistance = new Vector2(1, 1);
            
            // Speed text
            _hudSpeedText = CreateHudText(hudPanel.transform, new Vector2(10, -12), "0°/s", 22, TextAlignmentOptions.Left);
            _hudSpeedText.fontStyle = FontStyles.Bold;
            _hudSpeedText.color = new Color(1f, 0.9f, 0.3f);
            
            // Status text  
            _hudStatusText = CreateHudText(hudPanel.transform, new Vector2(10, -42), "Ready", 14, TextAlignmentOptions.Left);
            _hudStatusText.color = new Color(0.8f, 0.8f, 0.8f);
            
            // Touch indicator (right side of HUD)
            var touchIndicatorObj = new GameObject("TouchIndicator");
            touchIndicatorObj.transform.SetParent(hudPanel.transform, false);
            
            var touchRect = touchIndicatorObj.AddComponent<RectTransform>();
            touchRect.anchorMin = new Vector2(1f, 0.5f);
            touchRect.anchorMax = new Vector2(1f, 0.5f);
            touchRect.pivot = new Vector2(1f, 0.5f);
            touchRect.anchoredPosition = new Vector2(-15, 0);
            touchRect.sizeDelta = new Vector2(40, 40);
            
            _touchIndicator = touchIndicatorObj.AddComponent<Image>();
            _touchIndicator.color = new Color(0.5f, 0.5f, 0.5f, 0.3f);
            
            // Add touch icon text
            var touchIcon = CreateHudText(touchIndicatorObj.transform, Vector2.zero, "👆", 20, TextAlignmentOptions.Center);
            touchIcon.rectTransform.anchorMin = Vector2.zero;
            touchIcon.rectTransform.anchorMax = Vector2.one;
            touchIcon.rectTransform.offsetMin = Vector2.zero;
            touchIcon.rectTransform.offsetMax = Vector2.zero;
            
            Log("Compact HUD created");
        }

        private TextMeshProUGUI CreateHudText(Transform parent, Vector2 position, string text, float fontSize, TextAlignmentOptions alignment)
        {
            var textObj = new GameObject("HudText");
            textObj.transform.SetParent(parent, false);
            
            var rect = textObj.AddComponent<RectTransform>();
            rect.anchorMin = new Vector2(0f, 1f);
            rect.anchorMax = new Vector2(1f, 1f);
            rect.pivot = new Vector2(0f, 1f);
            rect.anchoredPosition = position;
            rect.sizeDelta = new Vector2(-20, 30);
            
            var tmp = textObj.AddComponent<TextMeshProUGUI>();
            tmp.text = text;
            tmp.fontSize = fontSize;
            tmp.alignment = alignment;
            tmp.color = Color.white;
            
            return tmp;
        }

        private void UpdateHUD()
        {
            if (!showHud) return;
            
            if (_hudSpeedText != null)
            {
                float rpm = Mathf.Abs(_currentSpeed / 360f) * 60f;
                string direction = _currentSpeed >= 0 ? "→" : "←";
                _hudSpeedText.text = $"{direction} {Mathf.Abs(_currentSpeed):F0}°/s";
                
                // Color based on whether touch is active
                if (_isTouching || _isDecaying)
                {
                    _hudSpeedText.color = new Color(0.3f, 0.8f, 1f); // Cyan when touch active
                }
                else
                {
                    _hudSpeedText.color = new Color(1f, 0.9f, 0.3f); // Yellow normally
                }
            }
            
            if (_hudStatusText != null)
            {
                if (_isTouching)
                {
                    _hudStatusText.text = "Dragging...";
                    _hudStatusText.color = new Color(0.3f, 0.8f, 1f);
                }
                else if (_isDecaying)
                {
                    _hudStatusText.text = $"Decaying → {_targetSpeed:F0}°";
                    _hudStatusText.color = new Color(1f, 0.6f, 0.3f);
                }
                else
                {
                    _hudStatusText.text = _lastMessage;
                    _hudStatusText.color = _lastDirection.Contains("FLUTTER") ? _fromFlutterColor : 
                                          _lastDirection.Contains("UNITY") ? _toFlutterColor : 
                                          new Color(0.8f, 0.8f, 0.8f);
                }
            }
            
            // Update touch indicator
            if (_touchIndicator != null)
            {
                if (_isTouching)
                {
                    _touchIndicator.color = new Color(0.3f, 0.8f, 1f, 0.8f);
                }
                else if (_isDecaying)
                {
                    float pulse = (Mathf.Sin(Time.time * 4f) + 1f) * 0.3f + 0.2f;
                    _touchIndicator.color = new Color(1f, 0.6f, 0.3f, pulse);
                }
                else
                {
                    _touchIndicator.color = new Color(0.5f, 0.5f, 0.5f, 0.3f);
                }
            }
        }

        #endregion

        #region Flutter Message Handlers

        /// <summary>
        /// Set the target rotation speed (from Flutter slider).
        /// </summary>
        [FlutterMethod("setSpeed")]
        public void SetSpeed(string data)
        {
            try
            {
                float speed = float.Parse(data);
                _targetSpeed = Mathf.Clamp(speed, -360f, 360f);
                
                // If not currently affected by touch, apply immediately
                if (!_isTouching && !_isDecaying)
                {
                    _currentSpeed = _targetSpeed;
                }
                
                _lastMessage = $"Target: {_targetSpeed:F0}°/s";
                _lastDirection = "← FLUTTER";
                _messageCount++;
                
                // Send acknowledgment
                SendToFlutter("onSpeedChanged", new SpeedData
                {
                    speed = _currentSpeed,
                    rpm = (_currentSpeed / 360f) * 60f
                });
                
                Log($"Target speed set to: {_targetSpeed}");
            }
            catch (Exception e)
            {
                LogError($"Failed to parse speed: {e.Message}");
            }
        }

        /// <summary>
        /// Set the rotation axis.
        /// </summary>
        [FlutterMethod("setAxis")]
        public void SetAxis(string data)
        {
            var axisData = FlutterSerialization.Deserialize<AxisData>(data);
            if (axisData != null)
            {
                _rotationAxis = new Vector3(axisData.x, axisData.y, axisData.z).normalized;
                _lastMessage = $"Axis: ({axisData.x:F0},{axisData.y:F0},{axisData.z:F0})";
                _lastDirection = "← FLUTTER";
                _messageCount++;
                
                Log($"Rotation axis set to: {_rotationAxis}");
            }
        }

        /// <summary>
        /// Set the cube color.
        /// </summary>
        [FlutterMethod("setColor")]
        public void SetColor(string data)
        {
            var colorData = FlutterSerialization.Deserialize<ColorData>(data);
            if (colorData != null && _cube != null)
            {
                var renderer = _cube.GetComponent<Renderer>();
                if (renderer != null)
                {
                    Color newColor = new Color(colorData.r, colorData.g, colorData.b, colorData.a);
                    renderer.material.color = newColor;
                    _lastMessage = "Color changed";
                    _lastDirection = "← FLUTTER";
                    _messageCount++;
                    
                    Log($"Cube color set to: {newColor}");
                }
            }
        }

        /// <summary>
        /// Reset the cube to default state.
        /// </summary>
        [FlutterMethod("reset")]
        public void Reset(string data)
        {
            _targetSpeed = initialSpeed;
            _currentSpeed = initialSpeed;
            _rotationAxis = Vector3.up;
            _isDecaying = false;
            
            if (_cube != null)
            {
                _cube.transform.rotation = Quaternion.identity;
                var renderer = _cube.GetComponent<Renderer>();
                if (renderer != null)
                {
                    renderer.material.color = cubeColor;
                }
            }
            
            _lastMessage = "Reset";
            _lastDirection = "← FLUTTER";
            _messageCount++;
            
            SendToFlutter("onReset", new ResetData { success = true });
            
            Log("Demo reset");
        }

        /// <summary>
        /// Get current cube state.
        /// </summary>
        [FlutterMethod("getState")]
        public void GetState(string data)
        {
            var state = new CubeState
            {
                speed = _currentSpeed,
                targetSpeed = _targetSpeed,
                rpm = (_currentSpeed / 360f) * 60f,
                axis = new AxisData { x = _rotationAxis.x, y = _rotationAxis.y, z = _rotationAxis.z },
                rotation = new Vector3Data
                {
                    x = _cube.transform.eulerAngles.x,
                    y = _cube.transform.eulerAngles.y,
                    z = _cube.transform.eulerAngles.z
                },
                messageCount = _messageCount,
                isDecaying = _isDecaying
            };
            
            SendToFlutter("onState", state);
            
            _lastMessage = "State sent";
            _lastDirection = "→ FLUTTER";
            
            Log("State sent to Flutter");
        }

        #endregion

        #region Helper Methods

        private void NotifyFlutterReady()
        {
            LogToAndroid("GameFrameworkDemo", "NotifyFlutterReady: Sending onReady to Flutter");
            SendToFlutter("onReady", new ReadyData
            {
                success = true,
                initialSpeed = _targetSpeed,
                initialAxisX = _rotationAxis.x,
                initialAxisY = _rotationAxis.y,
                initialAxisZ = _rotationAxis.z,
                message = "Unity cube demo ready! Swipe to spin!"
            });
            
            _lastMessage = "Ready";
            _lastDirection = "→ FLUTTER";
            
            Log("Ready notification sent to Flutter");
            LogToAndroid("GameFrameworkDemo", "NotifyFlutterReady: Done");
        }

        private void Log(string message)
        {
            if (verboseLogging)
            {
                Debug.Log($"[GameFrameworkDemo] {message}");
            }
        }

        private void LogError(string message)
        {
            Debug.LogError($"[GameFrameworkDemo] {message}");
        }

        #endregion

        #region Data Classes

        [Serializable]
        public class SpeedData
        {
            public float speed;
            public float rpm;
        }

        [Serializable]
        public class CurrentSpeedData
        {
            public float speed;
            public float rpm;
            public float targetSpeed;
            public bool isTouch;
        }

        [Serializable]
        public class AxisData
        {
            public float x;
            public float y;
            public float z;
        }

        [Serializable]
        public class ColorData
        {
            public float r;
            public float g;
            public float b;
            public float a = 1f;
        }

        [Serializable]
        public class Vector3Data
        {
            public float x;
            public float y;
            public float z;
        }

        [Serializable]
        public class CubeState
        {
            public float speed;
            public float targetSpeed;
            public float rpm;
            public AxisData axis;
            public Vector3Data rotation;
            public int messageCount;
            public bool isDecaying;
        }

        [Serializable]
        public class ResetData
        {
            public bool success;
        }

        [Serializable]
        public class ReadyData
        {
            public bool success;
            public float initialSpeed;
            public float initialAxisX;
            public float initialAxisY;
            public float initialAxisZ;
            public string message;
        }

        #endregion
    }
}
