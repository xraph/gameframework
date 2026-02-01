using System;
using System.Collections.Concurrent;
using System.Text;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Object pool for message-related objects to minimize GC pressure.
    /// 
    /// Provides pooling for PooledMessage objects and StringBuilders
    /// to enable zero-allocation hot paths in high-frequency messaging.
    /// </summary>
    public class MessagePool : SingletonMonoBehaviour<MessagePool>
    {
        #region Configuration

        [Header("Pool Configuration")]
        [Tooltip("Initial pool size for messages")]
        [SerializeField] private int initialMessagePoolSize = 50;

        [Tooltip("Maximum pool size for messages")]
        [SerializeField] private int maxMessagePoolSize = 200;

        [Tooltip("Initial pool size for StringBuilders")]
        [SerializeField] private int initialStringBuilderPoolSize = 20;

        [Tooltip("Maximum pool size for StringBuilders")]
        [SerializeField] private int maxStringBuilderPoolSize = 50;

        [Tooltip("Default StringBuilder capacity")]
        [SerializeField] private int defaultStringBuilderCapacity = 512;

        [Tooltip("Enable pool statistics tracking")]
        [SerializeField] private bool enableStatistics = false;

        #endregion

        #region State

        private readonly ConcurrentQueue<PooledMessage> _messagePool = new ConcurrentQueue<PooledMessage>();
        private readonly ConcurrentQueue<StringBuilder> _stringBuilderPool = new ConcurrentQueue<StringBuilder>();
        private readonly ConcurrentQueue<byte[]> _byteArrayPool = new ConcurrentQueue<byte[]>();

        private int _messagePoolCount = 0;
        private int _stringBuilderPoolCount = 0;

        // Statistics
        private int _messagesRented = 0;
        private int _messagesReturned = 0;
        private int _messagesCreated = 0;
        private int _stringBuildersRented = 0;
        private int _stringBuildersReturned = 0;
        private int _stringBuildersCreated = 0;

        #endregion

        #region Initialization

        protected override void SingletonAwake()
        {
            base.SingletonAwake();

            // Pre-warm pools
            PreWarmMessagePool();
            PreWarmStringBuilderPool();

            Debug.Log($"[MessagePool] Initialized with {_messagePoolCount} messages, {_stringBuilderPoolCount} StringBuilders");
        }

        private void PreWarmMessagePool()
        {
            for (int i = 0; i < initialMessagePoolSize; i++)
            {
                _messagePool.Enqueue(new PooledMessage());
                _messagePoolCount++;
            }
        }

        private void PreWarmStringBuilderPool()
        {
            for (int i = 0; i < initialStringBuilderPoolSize; i++)
            {
                _stringBuilderPool.Enqueue(new StringBuilder(defaultStringBuilderCapacity));
                _stringBuilderPoolCount++;
            }
        }

        #endregion

        #region PooledMessage Operations

        /// <summary>
        /// Rent a pooled message object.
        /// </summary>
        /// <returns>A PooledMessage instance (either from pool or newly created)</returns>
        public PooledMessage RentMessage()
        {
            PooledMessage message;

            if (_messagePool.TryDequeue(out message))
            {
                _messagePoolCount--;
                message.Reset();
            }
            else
            {
                message = new PooledMessage();
                if (enableStatistics) _messagesCreated++;
            }

            if (enableStatistics) _messagesRented++;

            return message;
        }

        /// <summary>
        /// Return a pooled message to the pool.
        /// </summary>
        /// <param name="message">The message to return</param>
        public void ReturnMessage(PooledMessage message)
        {
            if (message == null) return;

            if (_messagePoolCount < maxMessagePoolSize)
            {
                message.Reset();
                _messagePool.Enqueue(message);
                _messagePoolCount++;

                if (enableStatistics) _messagesReturned++;
            }
            // If pool is full, message will be garbage collected
        }

        #endregion

        #region StringBuilder Operations

        /// <summary>
        /// Rent a pooled StringBuilder.
        /// </summary>
        /// <returns>A StringBuilder instance (cleared and ready for use)</returns>
        public StringBuilder RentStringBuilder()
        {
            StringBuilder sb;

            if (_stringBuilderPool.TryDequeue(out sb))
            {
                _stringBuilderPoolCount--;
                sb.Clear();
            }
            else
            {
                sb = new StringBuilder(defaultStringBuilderCapacity);
                if (enableStatistics) _stringBuildersCreated++;
            }

            if (enableStatistics) _stringBuildersRented++;

            return sb;
        }

        /// <summary>
        /// Return a StringBuilder to the pool.
        /// </summary>
        /// <param name="sb">The StringBuilder to return</param>
        public void ReturnStringBuilder(StringBuilder sb)
        {
            if (sb == null) return;

            if (_stringBuilderPoolCount < maxStringBuilderPoolSize)
            {
                // Don't shrink capacity if it grew, just clear
                sb.Clear();

                // But if it grew too large, create a new one
                if (sb.Capacity > defaultStringBuilderCapacity * 4)
                {
                    sb = new StringBuilder(defaultStringBuilderCapacity);
                }

                _stringBuilderPool.Enqueue(sb);
                _stringBuilderPoolCount++;

                if (enableStatistics) _stringBuildersReturned++;
            }
        }

        #endregion

        #region Byte Array Operations

        /// <summary>
        /// Rent a byte array of at least the specified size.
        /// </summary>
        /// <param name="minSize">Minimum required size</param>
        /// <returns>A byte array (may be larger than requested)</returns>
        public byte[] RentByteArray(int minSize)
        {
            // Try to find a suitable array in the pool
            // For simplicity, just create new arrays and rely on ArrayPool in .NET
            // Unity doesn't have ArrayPool built-in, so we use a simple approach
            return new byte[minSize];
        }

        /// <summary>
        /// Return a byte array to the pool.
        /// </summary>
        /// <param name="array">The array to return</param>
        public void ReturnByteArray(byte[] array)
        {
            // For simplicity, let GC handle byte arrays
            // In production, could implement size-based bucketing
        }

        #endregion

        #region Statistics

        /// <summary>
        /// Get pool statistics for debugging.
        /// </summary>
        public PoolStatistics GetStatistics()
        {
            return new PoolStatistics
            {
                MessagePoolSize = _messagePoolCount,
                MessagesRented = _messagesRented,
                MessagesReturned = _messagesReturned,
                MessagesCreated = _messagesCreated,
                StringBuilderPoolSize = _stringBuilderPoolCount,
                StringBuildersRented = _stringBuildersRented,
                StringBuildersReturned = _stringBuildersReturned,
                StringBuildersCreated = _stringBuildersCreated
            };
        }

        /// <summary>
        /// Reset statistics counters.
        /// </summary>
        public void ResetStatistics()
        {
            _messagesRented = 0;
            _messagesReturned = 0;
            _messagesCreated = 0;
            _stringBuildersRented = 0;
            _stringBuildersReturned = 0;
            _stringBuildersCreated = 0;
        }

        #endregion
    }

    /// <summary>
    /// Pooled message object for efficient message passing.
    /// </summary>
    public class PooledMessage : IDisposable
    {
        /// <summary>Target component name</summary>
        public string Target;

        /// <summary>Method name to invoke</summary>
        public string Method;

        /// <summary>String data payload</summary>
        public string Data;

        /// <summary>Binary data payload</summary>
        public byte[] BinaryData;

        /// <summary>Type of data in this message</summary>
        public MessageDataType DataType;

        /// <summary>Priority for processing order</summary>
        public MessagePriority Priority;

        /// <summary>Timestamp when message was created</summary>
        public float Timestamp;

        /// <summary>Optional callback ID for request-response pattern</summary>
        public int CallbackId;

        /// <summary>
        /// Reset the message for reuse.
        /// </summary>
        public void Reset()
        {
            Target = null;
            Method = null;
            Data = null;
            BinaryData = null;
            DataType = MessageDataType.String;
            Priority = MessagePriority.Normal;
            Timestamp = 0;
            CallbackId = -1;
        }

        /// <summary>
        /// Set message properties in one call (reduces allocations).
        /// </summary>
        public PooledMessage Set(string target, string method, string data, 
            MessageDataType dataType = MessageDataType.String,
            MessagePriority priority = MessagePriority.Normal)
        {
            Target = target;
            Method = method;
            Data = data;
            DataType = dataType;
            Priority = priority;
            Timestamp = Time.unscaledTime;
            return this;
        }

        /// <summary>
        /// Set binary message properties.
        /// </summary>
        public PooledMessage SetBinary(string target, string method, byte[] data,
            bool compressed = false,
            MessagePriority priority = MessagePriority.Normal)
        {
            Target = target;
            Method = method;
            BinaryData = data;
            DataType = compressed ? MessageDataType.CompressedBinary : MessageDataType.Binary;
            Priority = priority;
            Timestamp = Time.unscaledTime;
            return this;
        }

        /// <summary>
        /// Dispose and return to pool.
        /// </summary>
        public void Dispose()
        {
            MessagePool.Instance?.ReturnMessage(this);
        }
    }

    /// <summary>
    /// Pool statistics for monitoring.
    /// </summary>
    [Serializable]
    public struct PoolStatistics
    {
        public int MessagePoolSize;
        public int MessagesRented;
        public int MessagesReturned;
        public int MessagesCreated;
        public int StringBuilderPoolSize;
        public int StringBuildersRented;
        public int StringBuildersReturned;
        public int StringBuildersCreated;

        public override string ToString()
        {
            return $"Messages: Pool={MessagePoolSize}, Rented={MessagesRented}, Returned={MessagesReturned}, Created={MessagesCreated}\n" +
                   $"StringBuilders: Pool={StringBuilderPoolSize}, Rented={StringBuildersRented}, Returned={StringBuildersReturned}, Created={StringBuildersCreated}";
        }
    }
}
