using System;
using UnityEngine;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Demonstrates various messaging patterns with Flutter.
    /// 
    /// Features:
    /// - String messaging
    /// - JSON/typed messaging with automatic deserialization
    /// - Request-response pattern
    /// - Event broadcasting
    /// 
    /// Flutter usage:
    /// ```dart
    /// // Send string message
    /// await controller.sendMessage('Messaging', 'sendString', 'Hello Unity!');
    /// 
    /// // Send typed message
    /// await controller.sendJsonMessage('Messaging', 'sendTyped', {
    ///   'action': 'greet',
    ///   'value': 42,
    ///   'enabled': true,
    /// });
    /// 
    /// // Listen for responses
    /// controller.messageStream.listen((msg) {
    ///   if (msg.target == 'Messaging') {
    ///     print('Method: ${msg.method}, Data: ${msg.data}');
    ///   }
    /// });
    /// ```
    /// </summary>
    public class MessagingExample : FlutterMonoBehaviour
    {
        protected override string TargetName => "Messaging";

        #region String Messaging

        /// <summary>
        /// Receive a plain string message.
        /// </summary>
        [FlutterMethod("sendString")]
        public void ReceiveString(string message)
        {
            Debug.Log($"[Messaging] String received: {message}");

            // Echo back with modification
            SendToFlutter("onStringReceived", $"Echo: {message}");
        }

        /// <summary>
        /// Send a string to Flutter.
        /// </summary>
        public void SendStringToFlutter(string message)
        {
            SendToFlutter("onString", message);
        }

        #endregion

        #region Typed Messaging

        /// <summary>
        /// Receive a typed message with automatic deserialization.
        /// </summary>
        [FlutterMethod("sendTyped")]
        public void ReceiveTyped(TypedMessage message)
        {
            Debug.Log($"[Messaging] Typed received: action={message.action}, value={message.value}");

            // Process based on action
            var response = new TypedResponse
            {
                originalAction = message.action,
                processedValue = message.value * 2,
                timestamp = DateTime.UtcNow.ToString("o")
            };

            SendToFlutter("onTypedReceived", response);
        }

        /// <summary>
        /// Send typed data to Flutter.
        /// </summary>
        public void SendTypedToFlutter(string action, int value)
        {
            SendToFlutter("onTyped", new TypedMessage
            {
                action = action,
                value = value,
                enabled = true
            });
        }

        #endregion

        #region Request-Response Pattern

        /// <summary>
        /// Handle a request and send response.
        /// Demonstrates request-response pattern.
        /// </summary>
        [FlutterMethod("request")]
        public void HandleRequest(RequestMessage request)
        {
            Debug.Log($"[Messaging] Request: {request.requestId} - {request.operation}");

            // Process request
            var response = new ResponseMessage
            {
                requestId = request.requestId,
                success = true,
                result = ProcessOperation(request.operation, request.parameters)
            };

            // Send response
            SendToFlutter("onResponse", response);
        }

        private string ProcessOperation(string operation, string[] parameters)
        {
            switch (operation)
            {
                case "add":
                    if (parameters?.Length >= 2)
                    {
                        int a = int.Parse(parameters[0]);
                        int b = int.Parse(parameters[1]);
                        return (a + b).ToString();
                    }
                    return "0";

                case "concat":
                    return string.Join("", parameters ?? Array.Empty<string>());

                case "time":
                    return DateTime.UtcNow.ToString("o");

                default:
                    return $"Unknown operation: {operation}";
            }
        }

        #endregion

        #region Event Broadcasting

        /// <summary>
        /// Subscribe to events.
        /// </summary>
        [FlutterMethod("subscribe")]
        public void Subscribe(SubscriptionRequest request)
        {
            Debug.Log($"[Messaging] Subscribe to: {request.eventType}");

            // Store subscription (in real app, would track active subscriptions)
            SendToFlutter("onSubscribed", new { eventType = request.eventType, success = true });
        }

        /// <summary>
        /// Unsubscribe from events.
        /// </summary>
        [FlutterMethod("unsubscribe")]
        public void Unsubscribe(SubscriptionRequest request)
        {
            Debug.Log($"[Messaging] Unsubscribe from: {request.eventType}");
            SendToFlutter("onUnsubscribed", new { eventType = request.eventType, success = true });
        }

        /// <summary>
        /// Broadcast an event to Flutter.
        /// </summary>
        public void BroadcastEvent(string eventType, object data)
        {
            SendToFlutter("onEvent", new EventMessage
            {
                eventType = eventType,
                data = JsonUtility.ToJson(data),
                timestamp = DateTime.UtcNow.ToString("o")
            });
        }

        #endregion

        #region Array/Collection Handling

        /// <summary>
        /// Receive array data.
        /// </summary>
        [FlutterMethod("sendArray")]
        public void ReceiveArray(ArrayMessage message)
        {
            Debug.Log($"[Messaging] Array received: {message.items?.Length ?? 0} items");

            // Process array
            var result = new ArrayResponse
            {
                count = message.items?.Length ?? 0,
                sum = 0
            };

            if (message.items != null)
            {
                foreach (var item in message.items)
                {
                    if (int.TryParse(item, out int value))
                    {
                        result.sum += value;
                    }
                }
            }

            SendToFlutter("onArrayProcessed", result);
        }

        #endregion

        #region Data Types

        [Serializable]
        public class TypedMessage
        {
            public string action;
            public int value;
            public bool enabled;
        }

        [Serializable]
        public class TypedResponse
        {
            public string originalAction;
            public int processedValue;
            public string timestamp;
        }

        [Serializable]
        public class RequestMessage
        {
            public string requestId;
            public string operation;
            public string[] parameters;
        }

        [Serializable]
        public class ResponseMessage
        {
            public string requestId;
            public bool success;
            public string result;
        }

        [Serializable]
        public class SubscriptionRequest
        {
            public string eventType;
        }

        [Serializable]
        public class EventMessage
        {
            public string eventType;
            public string data;
            public string timestamp;
        }

        [Serializable]
        public class ArrayMessage
        {
            public string[] items;
        }

        [Serializable]
        public class ArrayResponse
        {
            public int count;
            public int sum;
        }

        #endregion
    }
}
