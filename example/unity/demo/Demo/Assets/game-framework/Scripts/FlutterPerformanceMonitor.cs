using UnityEngine;
using System.Collections.Generic;
using System.Text;
using Xraph.GameFramework.Unity;

namespace FlutterUnity
{
    /// <summary>
    /// Advanced performance monitoring for Unity-Flutter integration
    /// Tracks FPS, memory, CPU/GPU times, and reports to Flutter
    /// </summary>
    [AddComponentMenu("Flutter/Flutter Performance Monitor")]
    public class FlutterPerformanceMonitor : MonoBehaviour
    {
        [Header("Monitoring Settings")]
        [Tooltip("Enable performance monitoring")]
        public bool enableMonitoring = true;

        [Tooltip("How often to report metrics to Flutter (seconds)")]
        [Range(0.5f, 10f)]
        public float reportInterval = 2f;

        [Tooltip("Enable detailed profiling (may impact performance)")]
        public bool enableDetailedProfiling = false;

        [Header("Thresholds")]
        [Tooltip("Warn if FPS drops below this value")]
        public int fpsWarningThreshold = 30;

        [Tooltip("Warn if memory exceeds this percentage")]
        [Range(0.5f, 1f)]
        public float memoryWarningThreshold = 0.8f;

        // Performance metrics
        private class PerformanceMetrics
        {
            public float fps;
            public float avgFps;
            public float minFps;
            public float maxFps;

            public long totalMemoryMB;
            public long usedMemoryMB;
            public long availableMemoryMB;
            public float memoryUsagePercent;

            public float cpuFrameTimeMs;
            public float gpuFrameTimeMs;

            public int drawCalls;
            public int triangles;
            public int vertices;

            public int activeGameObjects;
            public int totalGameObjects;
        }

        private float deltaTime = 0f;
        private float reportTimer = 0f;
        private List<float> fpsHistory = new List<float>();
        private const int FPS_HISTORY_SIZE = 60;

        private PerformanceMetrics currentMetrics = new PerformanceMetrics();

        private void Update()
        {
            if (!enableMonitoring) return;

            // Calculate FPS
            deltaTime += (Time.unscaledDeltaTime - deltaTime) * 0.1f;
            float fps = 1.0f / deltaTime;

            // Update FPS history
            fpsHistory.Add(fps);
            if (fpsHistory.Count > FPS_HISTORY_SIZE)
            {
                fpsHistory.RemoveAt(0);
            }

            // Update report timer
            reportTimer += Time.unscaledDeltaTime;
            if (reportTimer >= reportInterval)
            {
                CollectMetrics();
                ReportToFlutter();
                reportTimer = 0f;
            }
        }

        private void CollectMetrics()
        {
            // FPS metrics
            currentMetrics.fps = 1.0f / deltaTime;
            currentMetrics.avgFps = CalculateAverageFPS();
            currentMetrics.minFps = CalculateMinFPS();
            currentMetrics.maxFps = CalculateMaxFPS();

            // Memory metrics
            CollectMemoryMetrics();

            // Frame time metrics
            if (enableDetailedProfiling)
            {
                CollectFrameTimeMetrics();
            }

            // Rendering metrics
            CollectRenderingMetrics();

            // Scene metrics
            CollectSceneMetrics();
        }

        private void CollectMemoryMetrics()
        {
            currentMetrics.totalMemoryMB = UnityEngine.Profiling.Profiler.GetTotalReservedMemoryLong() / (1024 * 1024);
            currentMetrics.usedMemoryMB = UnityEngine.Profiling.Profiler.GetTotalAllocatedMemoryLong() / (1024 * 1024);
            currentMetrics.availableMemoryMB = currentMetrics.totalMemoryMB - currentMetrics.usedMemoryMB;
            currentMetrics.memoryUsagePercent = (float)currentMetrics.usedMemoryMB / currentMetrics.totalMemoryMB;
        }

        private void CollectFrameTimeMetrics()
        {
#if UNITY_2020_2_OR_NEWER
            UnityEngine.Profiling.Recorder cpuRecorder = UnityEngine.Profiling.Recorder.Get("Main Thread");
            UnityEngine.Profiling.Recorder gpuRecorder = UnityEngine.Profiling.Recorder.Get("GPU");

            if (cpuRecorder.isValid)
            {
                currentMetrics.cpuFrameTimeMs = (float)cpuRecorder.elapsedNanoseconds / 1000000f;
            }

            if (gpuRecorder.isValid)
            {
                currentMetrics.gpuFrameTimeMs = (float)gpuRecorder.elapsedNanoseconds / 1000000f;
            }
#endif
        }

        private void CollectRenderingMetrics()
        {
#if UNITY_EDITOR
            // In Unity Editor, use UnityEditor.UnityStats
            currentMetrics.drawCalls = UnityEditor.UnityStats.batches;
            currentMetrics.triangles = UnityEditor.UnityStats.triangles;
            currentMetrics.vertices = UnityEditor.UnityStats.vertices;
#elif DEVELOPMENT_BUILD
            // In development builds, rendering stats are not easily accessible
            // You would need to use custom profiler markers or frame debugger
            // For now, we'll leave these at 0 or use basic Unity stats if available
            currentMetrics.drawCalls = 0;
            currentMetrics.triangles = 0;
            152            currentMetrics.vertices = 0;

            UnityEngine.Profiling.Recorder drawCallRecorder = UnityEngine.Profiling.Recorder.Get("SetPass Calls Count");
            if (drawCallRecorder != null && drawCallRecorder.isValid)
            {
                drawCallRecorder.FilterToCurrentThread();
                drawCallRecorder.enabled = true;
                if (drawCallRecorder.sampleBlockCount > 0)
                {
                    currentMetrics.drawCalls = (int)drawCallRecorder.LastValue; 
                }
            }
            
            UnityEngine.Profiling.Recorder trianglesRecorder = UnityEngine.Profiling.Recorder.Get("Triangles Count");
            if (trianglesRecorder != null && trianglesRecorder.isValid)
            {
                trianglesRecorder.FilterToCurrentThread();
                trianglesRecorder.enabled = true;
                if (trianglesRecorder.sampleBlockCount > 0)
                {
                    currentMetrics.triangles = (int)trianglesRecorder.LastValue;
                }
            }

            UnityEngine.Profiling.Recorder verticesRecorder = UnityEngine.Profiling.Recorder.Get("Vertices Count");
            if (verticesRecorder != null && verticesRecorder.isValid)
            {
                verticesRecorder.FilterToCurrentThread();
                verticesRecorder.enabled = true;
                if (verticesRecorder.sampleBlockCount > 0)
                {
                    currentMetrics.vertices = (int)verticesRecorder.LastValue;
                }
            }
 #endif
        }

        private void CollectSceneMetrics()
        {
            GameObject[] allObjects = FindObjectsOfType<GameObject>();
            currentMetrics.totalGameObjects = allObjects.Length;
            currentMetrics.activeGameObjects = 0;

            foreach (GameObject obj in allObjects)
            {
                if (obj.activeInHierarchy)
                {
                    currentMetrics.activeGameObjects++;
                }
            }
        }

        private float CalculateAverageFPS()
        {
            if (fpsHistory.Count == 0) return 0f;

            float sum = 0f;
            foreach (float fps in fpsHistory)
            {
                sum += fps;
            }
            return sum / fpsHistory.Count;
        }

        private float CalculateMinFPS()
        {
            if (fpsHistory.Count == 0) return 0f;

            float min = float.MaxValue;
            foreach (float fps in fpsHistory)
            {
                if (fps < min) min = fps;
            }
            return min;
        }

        private float CalculateMaxFPS()
        {
            if (fpsHistory.Count == 0) return 0f;

            float max = 0f;
            foreach (float fps in fpsHistory)
            {
                if (fps > max) max = fps;
            }
            return max;
        }

        private void ReportToFlutter()
        {
            if (FlutterBridge.Instance == null) return;

            // Check for warnings
            bool hasWarnings = false;
            StringBuilder warnings = new StringBuilder();

            if (currentMetrics.avgFps < fpsWarningThreshold)
            {
                warnings.AppendLine($"Low FPS: {currentMetrics.avgFps:F1} (threshold: {fpsWarningThreshold})");
                hasWarnings = true;
            }

            if (currentMetrics.memoryUsagePercent > memoryWarningThreshold)
            {
                warnings.AppendLine($"High memory usage: {currentMetrics.memoryUsagePercent:P0} (threshold: {memoryWarningThreshold:P0})");
                hasWarnings = true;
            }

            // Create performance data object
            var perfData = new
            {
                // FPS
                fps = currentMetrics.fps,
                avgFps = currentMetrics.avgFps,
                minFps = currentMetrics.minFps,
                maxFps = currentMetrics.maxFps,

                // Memory
                totalMemoryMB = currentMetrics.totalMemoryMB,
                usedMemoryMB = currentMetrics.usedMemoryMB,
                availableMemoryMB = currentMetrics.availableMemoryMB,
                memoryUsagePercent = currentMetrics.memoryUsagePercent,

                // Frame timing
                cpuFrameTimeMs = currentMetrics.cpuFrameTimeMs,
                gpuFrameTimeMs = currentMetrics.gpuFrameTimeMs,

                // Rendering
                drawCalls = currentMetrics.drawCalls,
                triangles = currentMetrics.triangles,
                vertices = currentMetrics.vertices,

                // Scene
                activeGameObjects = currentMetrics.activeGameObjects,
                totalGameObjects = currentMetrics.totalGameObjects,

                // Warnings
                hasWarnings = hasWarnings,
                warnings = warnings.ToString()
            };

            string json = JsonUtility.ToJson(perfData);
            FlutterBridge.Instance.SendToFlutter("PerformanceMonitor", "onMetricsUpdate", json);
        }

        /// <summary>
        /// Get current performance snapshot
        /// </summary>
        public string GetPerformanceSnapshot()
        {
            CollectMetrics();

            StringBuilder sb = new StringBuilder();
            sb.AppendLine("=== Performance Snapshot ===");
            sb.AppendLine($"FPS: {currentMetrics.fps:F1} (Avg: {currentMetrics.avgFps:F1}, Min: {currentMetrics.minFps:F1}, Max: {currentMetrics.maxFps:F1})");
            sb.AppendLine($"Memory: {currentMetrics.usedMemoryMB}MB / {currentMetrics.totalMemoryMB}MB ({currentMetrics.memoryUsagePercent:P0})");
            sb.AppendLine($"CPU Frame Time: {currentMetrics.cpuFrameTimeMs:F2}ms");
            sb.AppendLine($"GPU Frame Time: {currentMetrics.gpuFrameTimeMs:F2}ms");
            sb.AppendLine($"Draw Calls: {currentMetrics.drawCalls}");
            sb.AppendLine($"Triangles: {currentMetrics.triangles:N0}");
            sb.AppendLine($"Vertices: {currentMetrics.vertices:N0}");
            sb.AppendLine($"Game Objects: {currentMetrics.activeGameObjects} / {currentMetrics.totalGameObjects}");

            return sb.ToString();
        }

        /// <summary>
        /// Reset performance metrics
        /// </summary>
        public void ResetMetrics()
        {
            fpsHistory.Clear();
            reportTimer = 0f;
            currentMetrics = new PerformanceMetrics();
        }

        private void OnGUI()
        {
            if (!enableMonitoring || !enableDetailedProfiling) return;

            // Draw overlay
            GUI.Box(new Rect(10, 10, 300, 200), "Performance Monitor");

            GUIStyle style = new GUIStyle();
            style.normal.textColor = Color.white;
            style.fontSize = 12;

            int y = 30;
            GUI.Label(new Rect(20, y, 280, 20), $"FPS: {currentMetrics.fps:F1} (Avg: {currentMetrics.avgFps:F1})", style);
            y += 20;
            GUI.Label(new Rect(20, y, 280, 20), $"Memory: {currentMetrics.usedMemoryMB}MB / {currentMetrics.totalMemoryMB}MB", style);
            y += 20;
            GUI.Label(new Rect(20, y, 280, 20), $"CPU: {currentMetrics.cpuFrameTimeMs:F2}ms | GPU: {currentMetrics.gpuFrameTimeMs:F2}ms", style);
            y += 20;
            GUI.Label(new Rect(20, y, 280, 20), $"Draw Calls: {currentMetrics.drawCalls}", style);
            y += 20;
            GUI.Label(new Rect(20, y, 280, 20), $"Triangles: {currentMetrics.triangles:N0}", style);
            y += 20;
            GUI.Label(new Rect(20, y, 280, 20), $"GameObjects: {currentMetrics.activeGameObjects}", style);

            // Warning indicator
            if (currentMetrics.avgFps < fpsWarningThreshold || currentMetrics.memoryUsagePercent > memoryWarningThreshold)
            {
                y += 30;
                GUI.color = Color.yellow;
                GUI.Box(new Rect(15, y, 270, 30), "⚠ Performance Warning");
                GUI.color = Color.white;
            }
        }
    }
}
