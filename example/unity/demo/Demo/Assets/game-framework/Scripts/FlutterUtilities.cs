using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Utility helpers for Flutter integration
    ///
    /// Provides common functionality and helper methods for working
    /// with the Flutter Game Framework.
    /// </summary>
    public static class FlutterUtilities
    {
        /// <summary>
        /// Convert Unity Vector3 to JSON-serializable format
        /// </summary>
        public static Vector3Data ToVector3Data(this Vector3 vector)
        {
            return new Vector3Data
            {
                x = vector.x,
                y = vector.y,
                z = vector.z
            };
        }

        /// <summary>
        /// Convert Unity Quaternion to JSON-serializable format
        /// </summary>
        public static QuaternionData ToQuaternionData(this Quaternion quaternion)
        {
            return new QuaternionData
            {
                x = quaternion.x,
                y = quaternion.y,
                z = quaternion.z,
                w = quaternion.w
            };
        }

        /// <summary>
        /// Convert Unity Color to JSON-serializable format
        /// </summary>
        public static ColorData ToColorData(this Color color)
        {
            return new ColorData
            {
                r = color.r,
                g = color.g,
                b = color.b,
                a = color.a
            };
        }

        /// <summary>
        /// Send a Vector3 to Flutter
        /// </summary>
        public static void SendVector3ToFlutter(string target, string method, Vector3 vector)
        {
            FlutterBridge.Instance.SendToFlutter(target, method, vector.ToVector3Data());
        }

        /// <summary>
        /// Send a transform's position and rotation to Flutter
        /// </summary>
        public static void SendTransformToFlutter(string target, string method, Transform transform)
        {
            var transformData = new TransformData
            {
                position = transform.position.ToVector3Data(),
                rotation = transform.rotation.ToQuaternionData(),
                scale = transform.localScale.ToVector3Data()
            };

            FlutterBridge.Instance.SendToFlutter(target, method, transformData);
        }

        /// <summary>
        /// Parse a JSON string to a Dictionary
        /// </summary>
        public static Dictionary<string, object> ParseJson(string json)
        {
            // Simple JSON parsing for basic objects
            // For complex JSON, consider using Unity's JsonUtility or a third-party library
            var dict = new Dictionary<string, object>();

            if (string.IsNullOrEmpty(json))
                return dict;

            try
            {
                // This is a basic implementation
                // Use JsonUtility or Newtonsoft.Json for production
                json = json.Trim('{', '}');
                var pairs = json.Split(',');

                foreach (var pair in pairs)
                {
                    var keyValue = pair.Split(':');
                    if (keyValue.Length == 2)
                    {
                        var key = keyValue[0].Trim(' ', '"');
                        var value = keyValue[1].Trim(' ', '"');
                        dict[key] = value;
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to parse JSON: {e.Message}");
            }

            return dict;
        }

        /// <summary>
        /// Safely invoke a method after a delay
        /// </summary>
        public static void DelayedInvoke(MonoBehaviour behaviour, Action action, float delay)
        {
            behaviour.StartCoroutine(DelayedInvokeCoroutine(action, delay));
        }

        private static IEnumerator DelayedInvokeCoroutine(Action action, float delay)
        {
            yield return new WaitForSeconds(delay);
            action?.Invoke();
        }

        /// <summary>
        /// Retry an action until it succeeds or max attempts reached
        /// </summary>
        public static void RetryAction(MonoBehaviour behaviour, Func<bool> action, int maxAttempts = 3, float retryDelay = 1f)
        {
            behaviour.StartCoroutine(RetryActionCoroutine(action, maxAttempts, retryDelay));
        }

        private static IEnumerator RetryActionCoroutine(Func<bool> action, int maxAttempts, float retryDelay)
        {
            int attempts = 0;

            while (attempts < maxAttempts)
            {
                attempts++;

                try
                {
                    if (action())
                    {
                        Debug.Log($"Action succeeded on attempt {attempts}");
                        yield break;
                    }
                }
                catch (Exception e)
                {
                    Debug.LogWarning($"Attempt {attempts} failed: {e.Message}");
                }

                if (attempts < maxAttempts)
                {
                    yield return new WaitForSeconds(retryDelay);
                }
            }

            Debug.LogError($"Action failed after {maxAttempts} attempts");
        }

        /// <summary>
        /// Convert screen coordinates to world coordinates
        /// </summary>
        public static Vector3 ScreenToWorldPoint(Vector2 screenPoint, float depth = 10f)
        {
            var worldPoint = Camera.main.ScreenToWorldPoint(new Vector3(screenPoint.x, screenPoint.y, depth));
            return worldPoint;
        }

        /// <summary>
        /// Convert world coordinates to screen coordinates
        /// </summary>
        public static Vector2 WorldToScreenPoint(Vector3 worldPoint)
        {
            var screenPoint = Camera.main.WorldToScreenPoint(worldPoint);
            return new Vector2(screenPoint.x, screenPoint.y);
        }

        /// <summary>
        /// Check if a point is within screen bounds
        /// </summary>
        public static bool IsPointOnScreen(Vector2 screenPoint)
        {
            return screenPoint.x >= 0 && screenPoint.x <= Screen.width &&
                   screenPoint.y >= 0 && screenPoint.y <= Screen.height;
        }

        /// <summary>
        /// Get a formatted timestamp for logging
        /// </summary>
        public static string GetTimestamp()
        {
            return DateTime.Now.ToString("HH:mm:ss.fff");
        }

        /// <summary>
        /// Log a message with timestamp and send to Flutter
        /// </summary>
        public static void LogToFlutter(string message, LogType logType = LogType.Log)
        {
            var timestampedMessage = $"[{GetTimestamp()}] {message}";

            switch (logType)
            {
                case LogType.Log:
                    Debug.Log(timestampedMessage);
                    break;
                case LogType.Warning:
                    Debug.LogWarning(timestampedMessage);
                    break;
                case LogType.Error:
                    Debug.LogError(timestampedMessage);
                    break;
            }

            var logData = new LogData
            {
                message = message,
                type = logType.ToString(),
                timestamp = GetTimestamp()
            };

            FlutterBridge.Instance.SendToFlutter("Logger", "onLog", logData);
        }
    }

    // Data structures for serialization

    [Serializable]
    public class Vector3Data
    {
        public float x;
        public float y;
        public float z;

        public Vector3 ToVector3()
        {
            return new Vector3(x, y, z);
        }
    }

    [Serializable]
    public class QuaternionData
    {
        public float x;
        public float y;
        public float z;
        public float w;

        public Quaternion ToQuaternion()
        {
            return new Quaternion(x, y, z, w);
        }
    }

    [Serializable]
    public class ColorData
    {
        public float r;
        public float g;
        public float b;
        public float a;

        public Color ToColor()
        {
            return new Color(r, g, b, a);
        }
    }

    [Serializable]
    public class TransformData
    {
        public Vector3Data position;
        public QuaternionData rotation;
        public Vector3Data scale;
    }

    [Serializable]
    public class LogData
    {
        public string message;
        public string type;
        public string timestamp;
    }

    /// <summary>
    /// Performance monitoring helper
    /// </summary>
    public class FlutterPerformanceMonitor : MonoBehaviour
    {
        [Header("Settings")]
        public float updateInterval = 1.0f;
        public bool sendToFlutter = true;

        private float lastUpdateTime;
        private int frameCount;
        private float fps;

        void Update()
        {
            frameCount++;

            if (Time.time - lastUpdateTime >= updateInterval)
            {
                fps = frameCount / (Time.time - lastUpdateTime);
                frameCount = 0;
                lastUpdateTime = Time.time;

                if (sendToFlutter)
                {
                    SendPerformanceData();
                }
            }
        }

        private void SendPerformanceData()
        {
            int drawCalls = 0;
#if UNITY_EDITOR
            // Draw calls are only available in the Unity Editor
            drawCalls = UnityEditor.UnityStats.batches;
#endif

            var perfData = new PerformanceData
            {
                fps = Mathf.RoundToInt(fps),
                memoryUsage = (int)(UnityEngine.Profiling.Profiler.GetTotalAllocatedMemoryLong() / 1048576), // MB
                drawCalls = drawCalls
            };

            FlutterBridge.Instance.SendToFlutter("Performance", "onUpdate", perfData);
        }

        [Serializable]
        private class PerformanceData
        {
            public int fps;
            public int memoryUsage;
            public int drawCalls;
        }
    }

    /// <summary>
    /// Touch input helper for Flutter integration
    /// </summary>
    public class FlutterTouchHandler : MonoBehaviour
    {
        public event Action<Vector2> OnTouchDown;
        public event Action<Vector2> OnTouchUp;
        public event Action<Vector2, Vector2> OnTouchMove;

        private Vector2 lastTouchPosition;
        private bool isTouching;

        void Update()
        {
            HandleTouch();
        }

        private void HandleTouch()
        {
#if UNITY_EDITOR || UNITY_STANDALONE
            HandleMouseInput();
#else
            HandleTouchInput();
#endif
        }

        private void HandleMouseInput()
        {
            if (Input.GetMouseButtonDown(0))
            {
                var touchPos = Input.mousePosition;
                lastTouchPosition = touchPos;
                isTouching = true;
                OnTouchDown?.Invoke(touchPos);

                FlutterBridge.Instance.SendToFlutter("Touch", "onTouchDown",
                    new { x = touchPos.x, y = touchPos.y });
            }
            else if (Input.GetMouseButtonUp(0))
            {
                var touchPos = Input.mousePosition;
                isTouching = false;
                OnTouchUp?.Invoke(touchPos);

                FlutterBridge.Instance.SendToFlutter("Touch", "onTouchUp",
                    new { x = touchPos.x, y = touchPos.y });
            }
            else if (isTouching && Input.GetMouseButton(0))
            {
                var touchPos = Input.mousePosition;
                OnTouchMove?.Invoke(lastTouchPosition, touchPos);
                lastTouchPosition = touchPos;

                FlutterBridge.Instance.SendToFlutter("Touch", "onTouchMove",
                    new { x = touchPos.x, y = touchPos.y });
            }
        }

        private void HandleTouchInput()
        {
            if (Input.touchCount > 0)
            {
                Touch touch = Input.GetTouch(0);
                Vector2 touchPos = touch.position;

                switch (touch.phase)
                {
                    case TouchPhase.Began:
                        lastTouchPosition = touchPos;
                        isTouching = true;
                        OnTouchDown?.Invoke(touchPos);

                        FlutterBridge.Instance.SendToFlutter("Touch", "onTouchDown",
                            new { x = touchPos.x, y = touchPos.y });
                        break;

                    case TouchPhase.Ended:
                    case TouchPhase.Canceled:
                        isTouching = false;
                        OnTouchUp?.Invoke(touchPos);

                        FlutterBridge.Instance.SendToFlutter("Touch", "onTouchUp",
                            new { x = touchPos.x, y = touchPos.y });
                        break;

                    case TouchPhase.Moved:
                        OnTouchMove?.Invoke(lastTouchPosition, touchPos);
                        lastTouchPosition = touchPos;

                        FlutterBridge.Instance.SendToFlutter("Touch", "onTouchMove",
                            new { x = touchPos.x, y = touchPos.y });
                        break;
                }
            }
        }
    }
}
