using System;
using System.Collections;
using System.Diagnostics;
using UnityEngine;
using Xraph.GameFramework.Unity;
using Debug = UnityEngine.Debug;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Demonstrates high-frequency messaging for performance testing.
    /// 
    /// Features:
    /// - Stress testing messaging throughput
    /// - Latency measurement
    /// - Batching effectiveness
    /// - Throttling demonstration
    /// 
    /// Flutter usage:
    /// ```dart
    /// // Start performance test
    /// await controller.sendJsonMessage('HighFrequency', 'startTest', {
    ///   'messagesPerSecond': 1000,
    ///   'durationSeconds': 10,
    ///   'useBatching': true,
    /// });
    /// 
    /// // Send burst of messages
    /// for (int i = 0; i < 100; i++) {
    ///   await controller.sendJsonMessage('HighFrequency', 'ping', {'id': i});
    /// }
    /// 
    /// // Listen for performance results
    /// controller.messageStream.listen((msg) {
    ///   if (msg.method == 'onTestComplete') {
    ///     final results = jsonDecode(msg.data);
    ///     print('Throughput: ${results['messagesPerSecond']} msg/s');
    ///     print('Avg latency: ${results['averageLatencyMs']} ms');
    ///   }
    /// });
    /// ```
    /// </summary>
    public class HighFrequencyDemo : FlutterMonoBehaviour
    {
        protected override string TargetName => "HighFrequency";
        protected override bool IsSingleton => true;

        [Header("Performance Settings")]
        [SerializeField] private bool enableLatencyTracking = true;
        [SerializeField] private int maxLatencySamples = 1000;

        // Test state
        private bool _testRunning = false;
        private TestConfig _currentConfig;
        private Stopwatch _testStopwatch;

        // Counters
        private int _messagesReceived = 0;
        private int _messagesSent = 0;
        private long _bytesReceived = 0;
        private long _bytesSent = 0;

        // Latency tracking
        private float[] _latencySamples;
        private int _latencyIndex = 0;
        private Stopwatch _latencyStopwatch;

        // Streaming
        private Coroutine _streamingCoroutine;

        protected override void Awake()
        {
            base.Awake();

            _testStopwatch = new Stopwatch();
            _latencyStopwatch = new Stopwatch();
            _latencySamples = new float[maxLatencySamples];

            EnableBatching = true;
        }

        #region Test Control

        /// <summary>
        /// Start a performance test.
        /// </summary>
        [FlutterMethod("startTest")]
        public void StartTest(TestConfig config)
        {
            if (_testRunning)
            {
                SendToFlutter("onTestError", new { error = "Test already running" });
                return;
            }

            _currentConfig = config;
            _testRunning = true;
            _messagesReceived = 0;
            _messagesSent = 0;
            _bytesReceived = 0;
            _bytesSent = 0;
            _latencyIndex = 0;

            Array.Clear(_latencySamples, 0, _latencySamples.Length);

            _testStopwatch.Restart();

            Debug.Log($"[HighFrequency] Starting test: {config.messagesPerSecond} msg/s for {config.durationSeconds}s");

            // Configure batching
            if (MessageBatcher.HasInstance)
            {
                MessageBatcher.Instance.EnableBatching = config.useBatching;
            }

            SendToFlutter("onTestStarted", new TestStartedEvent
            {
                messagesPerSecond = config.messagesPerSecond,
                durationSeconds = config.durationSeconds,
                useBatching = config.useBatching
            });

            // Start streaming if enabled
            if (config.enableStreaming)
            {
                _streamingCoroutine = StartCoroutine(StreamMessages(config));
            }

            // Auto-stop after duration
            StartCoroutine(AutoStopTest(config.durationSeconds));
        }

        /// <summary>
        /// Stop the current test.
        /// </summary>
        [FlutterMethod("stopTest")]
        public void StopTest()
        {
            if (!_testRunning)
            {
                return;
            }

            _testRunning = false;
            _testStopwatch.Stop();

            if (_streamingCoroutine != null)
            {
                StopCoroutine(_streamingCoroutine);
                _streamingCoroutine = null;
            }

            // Calculate results
            var results = CalculateResults();

            Debug.Log($"[HighFrequency] Test complete: {results.actualMessagesPerSecond:F1} msg/s");

            SendToFlutter("onTestComplete", results);
        }

        private IEnumerator AutoStopTest(float durationSeconds)
        {
            yield return new WaitForSeconds(durationSeconds);
            
            if (_testRunning)
            {
                StopTest();
            }
        }

        #endregion

        #region Message Handling

        /// <summary>
        /// High-frequency ping handler.
        /// Tracks latency and message count.
        /// </summary>
        [FlutterMethod("ping", Throttle = 0)] // No throttle for testing
        public void HandlePing(PingMessage ping)
        {
            _messagesReceived++;
            _bytesReceived += ping.payload?.Length ?? 0;

            if (enableLatencyTracking && ping.timestamp > 0)
            {
                float latency = (float)(DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() - ping.timestamp);
                RecordLatency(latency);
            }

            // Echo back for round-trip measurement
            if (ping.requiresResponse)
            {
                var response = new PongMessage
                {
                    id = ping.id,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    receivedAt = ping.timestamp
                };

                if (_currentConfig?.useBatching ?? false)
                {
                    SendToFlutterBatched("onPong", response);
                }
                else
                {
                    SendToFlutter("onPong", response);
                }

                _messagesSent++;
            }
        }

        /// <summary>
        /// Position update handler for simulating game input.
        /// </summary>
        [FlutterMethod("position", Throttle = 60, ThrottleStrategy = ThrottleStrategy.KeepLatest)]
        public void HandlePosition(PositionUpdate position)
        {
            _messagesReceived++;

            // In real game, would update game object position
            // transform.position = new Vector3(position.x, position.y, position.z);
        }

        /// <summary>
        /// Input handler for simulating touch/joystick.
        /// </summary>
        [FlutterMethod("input", Throttle = 120)]
        public void HandleInput(InputUpdate input)
        {
            _messagesReceived++;

            // Process input
        }

        /// <summary>
        /// Burst message handler.
        /// </summary>
        [FlutterMethod("burst")]
        public void HandleBurst(BurstMessage burst)
        {
            _messagesReceived += burst.count;
            _bytesReceived += burst.data?.Length ?? 0;
        }

        #endregion

        #region Streaming

        private IEnumerator StreamMessages(TestConfig config)
        {
            float interval = 1f / config.messagesPerSecond;
            float targetTime = 0f;
            int id = 0;

            while (_testRunning)
            {
                targetTime += interval;
                
                // Send message
                var msg = new StreamMessage
                {
                    id = id++,
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    value = UnityEngine.Random.value
                };

                if (config.useBatching)
                {
                    SendToFlutterBatched("onStream", msg);
                }
                else
                {
                    SendToFlutter("onStream", msg);
                }

                _messagesSent++;

                // Maintain rate
                float waitTime = targetTime - (float)_testStopwatch.Elapsed.TotalSeconds;
                if (waitTime > 0)
                {
                    yield return new WaitForSecondsRealtime(waitTime);
                }
                else
                {
                    yield return null;
                }
            }
        }

        #endregion

        #region Latency Tracking

        private void RecordLatency(float latencyMs)
        {
            if (_latencyIndex < _latencySamples.Length)
            {
                _latencySamples[_latencyIndex++] = latencyMs;
            }
        }

        private LatencyStats CalculateLatencyStats()
        {
            if (_latencyIndex == 0)
            {
                return new LatencyStats();
            }

            float sum = 0;
            float min = float.MaxValue;
            float max = float.MinValue;

            for (int i = 0; i < _latencyIndex; i++)
            {
                float sample = _latencySamples[i];
                sum += sample;
                min = Mathf.Min(min, sample);
                max = Mathf.Max(max, sample);
            }

            float avg = sum / _latencyIndex;

            // Calculate stddev
            float variance = 0;
            for (int i = 0; i < _latencyIndex; i++)
            {
                float diff = _latencySamples[i] - avg;
                variance += diff * diff;
            }
            float stddev = Mathf.Sqrt(variance / _latencyIndex);

            // Calculate percentiles
            float[] sorted = new float[_latencyIndex];
            Array.Copy(_latencySamples, sorted, _latencyIndex);
            Array.Sort(sorted);

            return new LatencyStats
            {
                samples = _latencyIndex,
                min = min,
                max = max,
                average = avg,
                stddev = stddev,
                p50 = sorted[_latencyIndex / 2],
                p95 = sorted[(int)(_latencyIndex * 0.95f)],
                p99 = sorted[(int)(_latencyIndex * 0.99f)]
            };
        }

        #endregion

        #region Results

        private TestResults CalculateResults()
        {
            float elapsedSeconds = (float)_testStopwatch.Elapsed.TotalSeconds;

            var latencyStats = CalculateLatencyStats();

            // Get pool/batcher stats
            var poolStats = MessagePool.HasInstance ? MessagePool.Instance.GetStatistics() : default;
            var batcherStats = MessageBatcher.HasInstance ? MessageBatcher.Instance.GetStatistics() : default;

            return new TestResults
            {
                // Timing
                durationSeconds = elapsedSeconds,

                // Message counts
                messagesReceived = _messagesReceived,
                messagesSent = _messagesSent,
                totalMessages = _messagesReceived + _messagesSent,

                // Throughput
                actualMessagesPerSecond = (_messagesReceived + _messagesSent) / elapsedSeconds,
                receivedPerSecond = _messagesReceived / elapsedSeconds,
                sentPerSecond = _messagesSent / elapsedSeconds,

                // Data transfer
                bytesReceived = _bytesReceived,
                bytesSent = _bytesSent,
                bytesPerSecond = (_bytesReceived + _bytesSent) / elapsedSeconds,

                // Latency
                averageLatencyMs = latencyStats.average,
                minLatencyMs = latencyStats.min,
                maxLatencyMs = latencyStats.max,
                latencyStdDev = latencyStats.stddev,
                latencyP50 = latencyStats.p50,
                latencyP95 = latencyStats.p95,
                latencyP99 = latencyStats.p99,
                latencySamples = latencyStats.samples,

                // Pool stats
                messagesPooled = poolStats.MessagesReturned,
                messagesCreated = poolStats.MessagesCreated,

                // Batcher stats
                messagesBatched = batcherStats.MessagesBatched,
                batchesSent = batcherStats.BatchesSent,
                messagesCoalesced = batcherStats.MessagesCoalesced
            };
        }

        #endregion

        #region Queries

        /// <summary>
        /// Get current test status.
        /// </summary>
        [FlutterMethod("getStatus")]
        public void GetStatus()
        {
            SendToFlutter("onStatus", new TestStatus
            {
                isRunning = _testRunning,
                elapsedSeconds = (float)_testStopwatch.Elapsed.TotalSeconds,
                messagesReceived = _messagesReceived,
                messagesSent = _messagesSent
            });
        }

        /// <summary>
        /// Get pool statistics.
        /// </summary>
        [FlutterMethod("getPoolStats")]
        public void GetPoolStats()
        {
            var stats = MessagePool.HasInstance 
                ? MessagePool.Instance.GetStatistics() 
                : default;

            SendToFlutter("onPoolStats", new
            {
                messagePoolSize = stats.MessagePoolSize,
                messagesRented = stats.MessagesRented,
                messagesReturned = stats.MessagesReturned,
                messagesCreated = stats.MessagesCreated,
                stringBuilderPoolSize = stats.StringBuilderPoolSize
            });
        }

        /// <summary>
        /// Get batcher statistics.
        /// </summary>
        [FlutterMethod("getBatcherStats")]
        public void GetBatcherStats()
        {
            var stats = MessageBatcher.HasInstance 
                ? MessageBatcher.Instance.GetStatistics() 
                : default;

            SendToFlutter("onBatcherStats", new
            {
                messagesBatched = stats.MessagesBatched,
                batchesSent = stats.BatchesSent,
                messagesCoalesced = stats.MessagesCoalesced,
                pendingMessages = stats.PendingMessages,
                averagePerBatch = stats.AverageMessagesPerBatch
            });
        }

        #endregion

        #region Data Types

        [Serializable]
        public class TestConfig
        {
            public int messagesPerSecond;
            public float durationSeconds;
            public bool useBatching;
            public bool enableStreaming;
        }

        [Serializable]
        public class TestStartedEvent
        {
            public int messagesPerSecond;
            public float durationSeconds;
            public bool useBatching;
        }

        [Serializable]
        public class TestResults
        {
            public float durationSeconds;
            public int messagesReceived;
            public int messagesSent;
            public int totalMessages;
            public float actualMessagesPerSecond;
            public float receivedPerSecond;
            public float sentPerSecond;
            public long bytesReceived;
            public long bytesSent;
            public float bytesPerSecond;
            public float averageLatencyMs;
            public float minLatencyMs;
            public float maxLatencyMs;
            public float latencyStdDev;
            public float latencyP50;
            public float latencyP95;
            public float latencyP99;
            public int latencySamples;
            public int messagesPooled;
            public int messagesCreated;
            public int messagesBatched;
            public int batchesSent;
            public int messagesCoalesced;
        }

        [Serializable]
        public class TestStatus
        {
            public bool isRunning;
            public float elapsedSeconds;
            public int messagesReceived;
            public int messagesSent;
        }

        [Serializable]
        public class PingMessage
        {
            public int id;
            public long timestamp;
            public string payload;
            public bool requiresResponse;
        }

        [Serializable]
        public class PongMessage
        {
            public int id;
            public long timestamp;
            public long receivedAt;
        }

        [Serializable]
        public class PositionUpdate
        {
            public float x;
            public float y;
            public float z;
            public long timestamp;
        }

        [Serializable]
        public class InputUpdate
        {
            public float dx;
            public float dy;
            public int pointerId;
        }

        [Serializable]
        public class BurstMessage
        {
            public int count;
            public string data;
        }

        [Serializable]
        public class StreamMessage
        {
            public int id;
            public long timestamp;
            public float value;
        }

        private struct LatencyStats
        {
            public int samples;
            public float min;
            public float max;
            public float average;
            public float stddev;
            public float p50;
            public float p95;
            public float p99;
        }

        #endregion
    }
}
