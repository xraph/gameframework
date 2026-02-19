using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Serialization utilities for Flutter-Unity communication.
    /// 
    /// Provides JSON serialization with support for Unity types,
    /// delta compression, and generic type handling.
    /// </summary>
    public static class FlutterSerialization
    {
        #region Serialization

        /// <summary>
        /// Serialize an object to JSON string.
        /// </summary>
        /// <typeparam name="T">Type of object</typeparam>
        /// <param name="obj">Object to serialize</param>
        /// <returns>JSON string</returns>
        public static string Serialize<T>(T obj) where T : class
        {
            if (obj == null) return "null";

            try
            {
                return JsonUtility.ToJson(obj);
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterSerialization] Serialize failed: {e.Message}");
                return "{}";
            }
        }

        /// <summary>
        /// Serialize an object to JSON, with pretty printing option.
        /// </summary>
        public static string Serialize<T>(T obj, bool prettyPrint) where T : class
        {
            if (obj == null) return "null";

            try
            {
                return JsonUtility.ToJson(obj, prettyPrint);
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterSerialization] Serialize failed: {e.Message}");
                return "{}";
            }
        }

        #endregion

        #region Deserialization

        /// <summary>
        /// Deserialize JSON string to typed object.
        /// </summary>
        /// <typeparam name="T">Target type</typeparam>
        /// <param name="json">JSON string</param>
        /// <returns>Deserialized object</returns>
        public static T Deserialize<T>(string json) where T : class
        {
            if (string.IsNullOrEmpty(json) || json == "null") return null;

            try
            {
                return JsonUtility.FromJson<T>(json);
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterSerialization] Deserialize<{typeof(T).Name}> failed: {e.Message}");
                return null;
            }
        }

        /// <summary>
        /// Deserialize JSON string to object of specified type.
        /// </summary>
        /// <param name="json">JSON string</param>
        /// <param name="type">Target type</param>
        /// <returns>Deserialized object</returns>
        public static object Deserialize(string json, Type type)
        {
            if (string.IsNullOrEmpty(json) || json == "null") return null;
            if (type == null) return null;

            try
            {
                // Handle primitive types
                if (type == typeof(string)) return json;
                if (type == typeof(int)) return int.Parse(json);
                if (type == typeof(float)) return float.Parse(json);
                if (type == typeof(double)) return double.Parse(json);
                if (type == typeof(bool)) return bool.Parse(json);
                if (type == typeof(long)) return long.Parse(json);

                // Handle Unity types
                if (type == typeof(Vector3)) return DeserializeVector3(json);
                if (type == typeof(Vector2)) return DeserializeVector2(json);
                if (type == typeof(Quaternion)) return DeserializeQuaternion(json);
                if (type == typeof(Color)) return DeserializeColor(json);

                // Use JsonUtility for classes/structs
                return JsonUtility.FromJson(json, type);
            }
            catch (Exception e)
            {
                Debug.LogError($"[FlutterSerialization] Deserialize({type.Name}) failed: {e.Message}");
                return null;
            }
        }

        #endregion

        #region Unity Type Serialization

        /// <summary>
        /// Serialize Vector3 to compact JSON.
        /// </summary>
        public static string SerializeVector3(Vector3 v)
        {
            return $"{{\"x\":{v.x},\"y\":{v.y},\"z\":{v.z}}}";
        }

        /// <summary>
        /// Deserialize JSON to Vector3.
        /// </summary>
        public static Vector3 DeserializeVector3(string json)
        {
            var data = JsonUtility.FromJson<Vector3Data>(json);
            return new Vector3(data.x, data.y, data.z);
        }

        /// <summary>
        /// Serialize Vector2 to compact JSON.
        /// </summary>
        public static string SerializeVector2(Vector2 v)
        {
            return $"{{\"x\":{v.x},\"y\":{v.y}}}";
        }

        /// <summary>
        /// Deserialize JSON to Vector2.
        /// </summary>
        public static Vector2 DeserializeVector2(string json)
        {
            var data = JsonUtility.FromJson<Vector2Data>(json);
            return new Vector2(data.x, data.y);
        }

        /// <summary>
        /// Serialize Quaternion to compact JSON.
        /// </summary>
        public static string SerializeQuaternion(Quaternion q)
        {
            return $"{{\"x\":{q.x},\"y\":{q.y},\"z\":{q.z},\"w\":{q.w}}}";
        }

        /// <summary>
        /// Deserialize JSON to Quaternion.
        /// </summary>
        public static Quaternion DeserializeQuaternion(string json)
        {
            var data = JsonUtility.FromJson<QuaternionData>(json);
            return new Quaternion(data.x, data.y, data.z, data.w);
        }

        /// <summary>
        /// Serialize Color to compact JSON.
        /// </summary>
        public static string SerializeColor(Color c)
        {
            return $"{{\"r\":{c.r},\"g\":{c.g},\"b\":{c.b},\"a\":{c.a}}}";
        }

        /// <summary>
        /// Deserialize JSON to Color.
        /// </summary>
        public static Color DeserializeColor(string json)
        {
            var data = JsonUtility.FromJson<ColorData>(json);
            return new Color(data.r, data.g, data.b, data.a);
        }

        /// <summary>
        /// Serialize Transform data to JSON.
        /// </summary>
        public static string SerializeTransform(Transform t)
        {
            var data = new TransformData
            {
                position = new Vector3Data { x = t.position.x, y = t.position.y, z = t.position.z },
                rotation = new QuaternionData { x = t.rotation.x, y = t.rotation.y, z = t.rotation.z, w = t.rotation.w },
                scale = new Vector3Data { x = t.localScale.x, y = t.localScale.y, z = t.localScale.z }
            };
            return JsonUtility.ToJson(data);
        }

        #endregion

        #region Delta Compression

        /// <summary>
        /// Compute delta between two objects, returning JSON with only changed fields.
        /// </summary>
        /// <param name="previous">Previous state</param>
        /// <param name="current">Current state</param>
        /// <returns>JSON with only changed fields, or empty object if no changes</returns>
        public static string ComputeDelta(object previous, object current)
        {
            if (current == null) return "null";
            if (previous == null) return JsonUtility.ToJson(current);

            Type type = current.GetType();
            if (type != previous.GetType())
            {
                return JsonUtility.ToJson(current);
            }

            var sb = new StringBuilder();
            sb.Append("{");

            bool hasChanges = false;
            var fields = type.GetFields(BindingFlags.Public | BindingFlags.Instance);

            foreach (var field in fields)
            {
                object prevValue = field.GetValue(previous);
                object currValue = field.GetValue(current);

                if (!Equals(prevValue, currValue))
                {
                    if (hasChanges) sb.Append(",");
                    
                    sb.Append("\"");
                    sb.Append(field.Name);
                    sb.Append("\":");
                    
                    AppendValue(sb, currValue);
                    
                    hasChanges = true;
                }
            }

            sb.Append("}");

            return hasChanges ? sb.ToString() : "{}";
        }

        private static void AppendValue(StringBuilder sb, object value)
        {
            if (value == null)
            {
                sb.Append("null");
            }
            else if (value is string str)
            {
                sb.Append("\"");
                sb.Append(EscapeJson(str));
                sb.Append("\"");
            }
            else if (value is bool b)
            {
                sb.Append(b ? "true" : "false");
            }
            else if (value is int || value is float || value is double || value is long)
            {
                sb.Append(value);
            }
            else if (value is Vector3 v3)
            {
                sb.Append($"{{\"x\":{v3.x},\"y\":{v3.y},\"z\":{v3.z}}}");
            }
            else if (value is Vector2 v2)
            {
                sb.Append($"{{\"x\":{v2.x},\"y\":{v2.y}}}");
            }
            else if (value is Quaternion q)
            {
                sb.Append($"{{\"x\":{q.x},\"y\":{q.y},\"z\":{q.z},\"w\":{q.w}}}");
            }
            else if (value is Color c)
            {
                sb.Append($"{{\"r\":{c.r},\"g\":{c.g},\"b\":{c.b},\"a\":{c.a}}}");
            }
            else
            {
                // Fall back to JsonUtility
                sb.Append(JsonUtility.ToJson(value));
            }
        }

        private static string EscapeJson(string value)
        {
            if (string.IsNullOrEmpty(value)) return "";
            
            return value
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\n", "\\n")
                .Replace("\r", "\\r")
                .Replace("\t", "\\t");
        }

        #endregion

        #region Data Types

        [Serializable]
        public class Vector3Data
        {
            public float x;
            public float y;
            public float z;

            public Vector3 ToVector3() => new Vector3(x, y, z);
            
            public static Vector3Data FromVector3(Vector3 v) => new Vector3Data { x = v.x, y = v.y, z = v.z };
        }

        [Serializable]
        public class Vector2Data
        {
            public float x;
            public float y;

            public Vector2 ToVector2() => new Vector2(x, y);
            
            public static Vector2Data FromVector2(Vector2 v) => new Vector2Data { x = v.x, y = v.y };
        }

        [Serializable]
        public class QuaternionData
        {
            public float x;
            public float y;
            public float z;
            public float w;

            public Quaternion ToQuaternion() => new Quaternion(x, y, z, w);
            
            public static QuaternionData FromQuaternion(Quaternion q) => 
                new QuaternionData { x = q.x, y = q.y, z = q.z, w = q.w };
        }

        [Serializable]
        public class ColorData
        {
            public float r;
            public float g;
            public float b;
            public float a;

            public Color ToColor() => new Color(r, g, b, a);
            
            public static ColorData FromColor(Color c) => new ColorData { r = c.r, g = c.g, b = c.b, a = c.a };
        }

        [Serializable]
        public class TransformData
        {
            public Vector3Data position;
            public QuaternionData rotation;
            public Vector3Data scale;

            public void ApplyTo(Transform t)
            {
                t.position = position.ToVector3();
                t.rotation = rotation.ToQuaternion();
                t.localScale = scale.ToVector3();
            }

            public static TransformData FromTransform(Transform t)
            {
                return new TransformData
                {
                    position = Vector3Data.FromVector3(t.position),
                    rotation = QuaternionData.FromQuaternion(t.rotation),
                    scale = Vector3Data.FromVector3(t.localScale)
                };
            }
        }

        #endregion
    }
}
