using System;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Interactive rotating cube demo for Game Framework.
    /// 
    /// Features:
    /// - Rotating cube with controllable speed and direction
    /// - Real-time UI showing speed, messages, and communication direction
    /// - Bidirectional Flutter-Unity communication
    /// - Smooth animations and visual feedback
    /// 
    /// Attach this script to a GameObject named "GameFrameworkDemo" in your scene.
    /// The script will automatically create the cube and UI elements.
    /// </summary>
    public class GameFrameworkDemo : FlutterMonoBehaviour
    {
        #region Configuration

        [Header("Cube Configuration")]
        [Tooltip("Initial rotation speed")]
        [SerializeField] private float initialSpeed = 50f;

        [Tooltip("Cube color")]
        [SerializeField] private Color cubeColor = new Color(0.3f, 0.6f, 1f);

        [Header("UI Configuration")]
        [Tooltip("Enable verbose logging")]
        [SerializeField] private bool verboseLogging = true;

        #endregion

        #region FlutterMonoBehaviour Overrides

        protected override string TargetName => "GameFrameworkDemo";
        protected override bool IsSingleton => true;

        #endregion

        #region Private Fields

        private GameObject _cube;
        private GameObject _uiCanvas;
        private TextMeshProUGUI _speedText;
        private TextMeshProUGUI _messageText;
        private TextMeshProUGUI _directionText;
        
        private float _rotationSpeed = 50f;
        private Vector3 _rotationAxis = Vector3.up;
        private string _lastMessage = "Waiting for messages...";
        private string _lastDirection = "---";
        private int _messageCount = 0;
        
        private Color _fromFlutterColor = new Color(0.2f, 0.8f, 0.4f); // Green
        private Color _toFlutterColor = new Color(0.9f, 0.4f, 0.2f);   // Orange

        #endregion

        #region Unity Lifecycle

        protected override void Awake()
        {
            base.Awake();
            EnableDebugLogging = verboseLogging;
            _rotationSpeed = initialSpeed;
            
            Log("GameFrameworkDemo: Initialized");
        }

        void Start()
        {
            CreateCube();
            CreateUI();
            NotifyFlutterReady();
        }

        void Update()
        {
            // Rotate the cube
            if (_cube != null)
            {
                _cube.transform.Rotate(_rotationAxis, _rotationSpeed * Time.deltaTime);
            }
            
            // Update UI
            UpdateUI();
        }

        protected override void OnDestroy()
        {
            Log("GameFrameworkDemo: Destroyed");
            base.OnDestroy();
        }

        #endregion

        #region Scene Setup

        private void CreateCube()
        {
            // Create cube
            _cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            _cube.name = "RotatingCube";
            _cube.transform.position = Vector3.zero;
            _cube.transform.localScale = Vector3.one * 2f;
            
            // Add material
            var renderer = _cube.GetComponent<Renderer>();
            if (renderer != null)
            {
                renderer.material = new Material(Shader.Find("Standard"));
                renderer.material.color = cubeColor;
                renderer.material.SetFloat("_Metallic", 0.5f);
                renderer.material.SetFloat("_Glossiness", 0.8f);
            }
            
            // Position camera
            var camera = Camera.main;
            if (camera != null)
            {
                camera.transform.position = new Vector3(0, 2, -6);
                camera.transform.LookAt(_cube.transform);
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(0.1f, 0.1f, 0.15f);
            }
            
            // Add light
            var light = new GameObject("DirectionalLight");
            var lightComp = light.AddComponent<Light>();
            lightComp.type = LightType.Directional;
            lightComp.intensity = 1.2f;
            light.transform.rotation = Quaternion.Euler(50, -30, 0);
            
            Log("Cube created successfully");
        }

        private void CreateUI()
        {
            // Create canvas
            _uiCanvas = new GameObject("DemoCanvas");
            var canvas = _uiCanvas.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 100;
            
            var canvasScaler = _uiCanvas.AddComponent<CanvasScaler>();
            canvasScaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            canvasScaler.referenceResolution = new Vector2(1920, 1080);
            
            _uiCanvas.AddComponent<GraphicRaycaster>();
            
            // Create UI panel (top center)
            var panel = new GameObject("InfoPanel");
            panel.transform.SetParent(_uiCanvas.transform, false);
            
            var panelRect = panel.AddComponent<RectTransform>();
            panelRect.anchorMin = new Vector2(0.5f, 1f);
            panelRect.anchorMax = new Vector2(0.5f, 1f);
            panelRect.pivot = new Vector2(0.5f, 1f);
            panelRect.anchoredPosition = new Vector2(0, -20);
            panelRect.sizeDelta = new Vector2(600, 200);
            
            var panelImage = panel.AddComponent<Image>();
            panelImage.color = new Color(0, 0, 0, 0.85f);
            
            // Create text fields
            _speedText = CreateTextField(panel.transform, new Vector2(0, -30), "Speed: 0 rpm");
            _messageText = CreateTextField(panel.transform, new Vector2(0, -80), "Message: Waiting...");
            _directionText = CreateTextField(panel.transform, new Vector2(0, -130), "Direction: ---");
            
            // Style text fields
            _speedText.fontSize = 28;
            _speedText.fontStyle = FontStyles.Bold;
            _speedText.color = new Color(1f, 1f, 0.3f);
            
            _messageText.fontSize = 24;
            _messageText.color = new Color(0.9f, 0.9f, 0.9f);
            
            _directionText.fontSize = 26;
            _directionText.fontStyle = FontStyles.Bold;
            
            Log("UI created successfully");
        }

        private TextMeshProUGUI CreateTextField(Transform parent, Vector2 position, string text)
        {
            var textObj = new GameObject("TextField");
            textObj.transform.SetParent(parent, false);
            
            var rect = textObj.AddComponent<RectTransform>();
            rect.anchorMin = new Vector2(0.5f, 1f);
            rect.anchorMax = new Vector2(0.5f, 1f);
            rect.pivot = new Vector2(0.5f, 1f);
            rect.anchoredPosition = position;
            rect.sizeDelta = new Vector2(550, 40);
            
            var tmp = textObj.AddComponent<TextMeshProUGUI>();
            tmp.text = text;
            tmp.fontSize = 24;
            tmp.alignment = TextAlignmentOptions.Center;
            tmp.color = Color.white;
            
            // Add shadow for better visibility
            var shadow = textObj.AddComponent<UnityEngine.UI.Shadow>();
            shadow.effectColor = new Color(0, 0, 0, 0.8f);
            shadow.effectDistance = new Vector2(2, -2);
            
            return tmp;
        }

        private void UpdateUI()
        {
            if (_speedText != null)
            {
                float rpm = (_rotationSpeed / 360f) * 60f;
                _speedText.text = $"Speed: {rpm:F1} RPM ({_rotationSpeed:F0}°/s)";
            }
            
            if (_messageText != null)
            {
                _messageText.text = $"Message: {_lastMessage}";
            }
            
            if (_directionText != null)
            {
                _directionText.text = $"Direction: {_lastDirection}";
            }
        }

        #endregion

        #region Flutter Message Handlers

        /// <summary>
        /// Set the rotation speed of the cube.
        /// </summary>
        [FlutterMethod("setSpeed")]
        private void SetSpeed(string data)
        {
            try
            {
                float speed = float.Parse(data);
                _rotationSpeed = Mathf.Clamp(speed, -360f, 360f);
                _lastMessage = $"Speed changed to {_rotationSpeed:F0}°/s";
                _lastDirection = "← FROM FLUTTER";
                _messageCount++;
                
                if (_directionText != null)
                {
                    _directionText.color = _fromFlutterColor;
                }
                
                // Send acknowledgment
                SendToFlutter("onSpeedChanged", new SpeedData
                {
                    speed = _rotationSpeed,
                    rpm = (_rotationSpeed / 360f) * 60f
                });
                
                Log($"Speed set to: {_rotationSpeed}");
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
        private void SetAxis(string data)
        {
            var axisData = FlutterSerialization.Deserialize<AxisData>(data);
            if (axisData != null)
            {
                _rotationAxis = new Vector3(axisData.x, axisData.y, axisData.z).normalized;
                _lastMessage = $"Axis: ({axisData.x:F1}, {axisData.y:F1}, {axisData.z:F1})";
                _lastDirection = "← FROM FLUTTER";
                _messageCount++;
                
                if (_directionText != null)
                {
                    _directionText.color = _fromFlutterColor;
                }
                
                Log($"Rotation axis set to: {_rotationAxis}");
            }
        }

        /// <summary>
        /// Set the cube color.
        /// </summary>
        [FlutterMethod("setColor")]
        private void SetColor(string data)
        {
            var colorData = FlutterSerialization.Deserialize<ColorData>(data);
            if (colorData != null && _cube != null)
            {
                var renderer = _cube.GetComponent<Renderer>();
                if (renderer != null)
                {
                    Color newColor = new Color(colorData.r, colorData.g, colorData.b, colorData.a);
                    renderer.material.color = newColor;
                    _lastMessage = $"Color changed";
                    _lastDirection = "← FROM FLUTTER";
                    _messageCount++;
                    
                    if (_directionText != null)
                    {
                        _directionText.color = _fromFlutterColor;
                    }
                    
                    Log($"Cube color set to: {newColor}");
                }
            }
        }

        /// <summary>
        /// Reset the cube to default state.
        /// </summary>
        [FlutterMethod("reset")]
        private void Reset(string data)
        {
            _rotationSpeed = initialSpeed;
            _rotationAxis = Vector3.up;
            
            if (_cube != null)
            {
                _cube.transform.rotation = Quaternion.identity;
                var renderer = _cube.GetComponent<Renderer>();
                if (renderer != null)
                {
                    renderer.material.color = cubeColor;
                }
            }
            
            _lastMessage = "Reset to defaults";
            _lastDirection = "← FROM FLUTTER";
            _messageCount++;
            
            if (_directionText != null)
            {
                _directionText.color = _fromFlutterColor;
            }
            
            // Notify Flutter
            SendToFlutter("onReset", new ResetData { success = true });
            
            Log("Demo reset");
        }

        /// <summary>
        /// Get current cube state.
        /// </summary>
        [FlutterMethod("getState")]
        private void GetState(string data)
        {
            var state = new CubeState
            {
                speed = _rotationSpeed,
                rpm = (_rotationSpeed / 360f) * 60f,
                axis = new AxisData { x = _rotationAxis.x, y = _rotationAxis.y, z = _rotationAxis.z },
                rotation = new Vector3Data
                {
                    x = _cube.transform.eulerAngles.x,
                    y = _cube.transform.eulerAngles.y,
                    z = _cube.transform.eulerAngles.z
                },
                messageCount = _messageCount
            };
            
            SendToFlutter("onState", state);
            
            _lastMessage = "State sent";
            _lastDirection = "→ TO FLUTTER";
            
            if (_directionText != null)
            {
                _directionText.color = _toFlutterColor;
            }
            
            Log("State sent to Flutter");
        }

        #endregion

        #region Helper Methods

        private void NotifyFlutterReady()
        {
            SendToFlutter("onReady", new ReadyData
            {
                success = true,
                initialSpeed = _rotationSpeed,
                initialAxisX = _rotationAxis.x,
                initialAxisY = _rotationAxis.y,
                initialAxisZ = _rotationAxis.z,
                message = "Unity cube demo ready!"
            });
            
            _lastMessage = "Demo initialized";
            _lastDirection = "→ TO FLUTTER";
            
            if (_directionText != null)
            {
                _directionText.color = _toFlutterColor;
            }
            
            Log("Ready notification sent to Flutter");
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
            public float rpm;
            public AxisData axis;
            public Vector3Data rotation;
            public int messageCount;
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
