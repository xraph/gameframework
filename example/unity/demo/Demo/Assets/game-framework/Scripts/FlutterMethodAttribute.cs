using System;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Attribute to mark methods that can receive messages from Flutter.
    /// Methods decorated with this attribute will be automatically discovered
    /// and registered with the MessageRouter for efficient dispatch.
    /// </summary>
    /// <example>
    /// <code>
    /// [FlutterMethod("startGame")]
    /// public void OnStartGame(GameConfig config)
    /// {
    ///     // config is auto-deserialized from JSON
    /// }
    /// 
    /// [FlutterMethod("loadAsset", AcceptsBinary = true)]
    /// public void OnLoadAsset(byte[] data)
    /// {
    ///     // Binary data auto-decoded from base64
    /// }
    /// </code>
    /// </example>
    [AttributeUsage(AttributeTargets.Method, AllowMultiple = false, Inherited = true)]
    public class FlutterMethodAttribute : Attribute
    {
        /// <summary>
        /// The method name used for routing messages from Flutter.
        /// This is the name Flutter will use when calling SendMessage.
        /// </summary>
        public string MethodName { get; }

        /// <summary>
        /// If true, the method accepts binary data (byte[]) instead of JSON.
        /// Binary data will be automatically decoded from base64.
        /// Default: false
        /// </summary>
        public bool AcceptsBinary { get; set; } = false;

        /// <summary>
        /// Maximum rate (in Hz) at which this method can be called.
        /// Messages exceeding this rate will be throttled according to ThrottleStrategy.
        /// Set to 0 for unlimited. Default: 0 (unlimited)
        /// </summary>
        public int Throttle { get; set; } = 0;

        /// <summary>
        /// Strategy for handling messages that exceed the throttle rate.
        /// Default: KeepLatest
        /// </summary>
        public ThrottleStrategy ThrottleStrategy { get; set; } = ThrottleStrategy.KeepLatest;

        /// <summary>
        /// If true, automatically chunks large binary data during transfer.
        /// Useful for large assets. Default: false
        /// </summary>
        public bool Chunked { get; set; } = false;

        /// <summary>
        /// Priority level for message processing.
        /// Higher priority messages are processed first.
        /// Default: Normal
        /// </summary>
        public MessagePriority Priority { get; set; } = MessagePriority.Normal;

        /// <summary>
        /// If true, executes on a background thread instead of main Unity thread.
        /// Use for CPU-intensive operations that don't need Unity API access.
        /// Default: false
        /// </summary>
        public bool RunOnBackground { get; set; } = false;

        /// <summary>
        /// Create a FlutterMethod attribute with the specified method name.
        /// </summary>
        /// <param name="methodName">The method name Flutter will use to call this method</param>
        public FlutterMethodAttribute(string methodName)
        {
            if (string.IsNullOrEmpty(methodName))
            {
                throw new ArgumentException("Method name cannot be null or empty", nameof(methodName));
            }
            MethodName = methodName;
        }
    }

    /// <summary>
    /// Strategy for handling messages that exceed the throttle rate.
    /// </summary>
    public enum ThrottleStrategy
    {
        /// <summary>
        /// Drop excess messages entirely.
        /// Best for: Fire-and-forget events where old data is irrelevant
        /// </summary>
        Drop,

        /// <summary>
        /// Queue excess messages for later processing.
        /// Best for: Commands that must all be processed eventually
        /// </summary>
        Queue,

        /// <summary>
        /// Coalesce excess messages, keeping only the latest value.
        /// Best for: Continuous state updates like position/rotation
        /// </summary>
        KeepLatest,

        /// <summary>
        /// Coalesce excess messages, keeping only the first value.
        /// Best for: Input events where the first input matters most
        /// </summary>
        KeepFirst
    }

    /// <summary>
    /// Priority level for message processing order.
    /// </summary>
    public enum MessagePriority
    {
        /// <summary>Lowest priority, processed last</summary>
        Low = 0,

        /// <summary>Default priority</summary>
        Normal = 1,

        /// <summary>High priority, processed before normal</summary>
        High = 2,

        /// <summary>Critical priority, processed immediately</summary>
        Critical = 3
    }

    /// <summary>
    /// Data type indicator for message payloads.
    /// </summary>
    public enum MessageDataType
    {
        /// <summary>Plain string data</summary>
        String,

        /// <summary>JSON serialized object</summary>
        Json,

        /// <summary>Base64 encoded binary data</summary>
        Binary,

        /// <summary>Compressed binary data</summary>
        CompressedBinary
    }
}
