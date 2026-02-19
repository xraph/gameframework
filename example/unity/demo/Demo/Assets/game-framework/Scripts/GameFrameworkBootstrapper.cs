using System;
using System.Collections.Generic;
using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Automatic bootstrapper for Game Framework components.
    /// 
    /// This component ensures required GameObjects exist at runtime, even if 
    /// developers forget to add them to the scene. It runs early in Unity's
    /// script execution order to set up components before other scripts need them.
    /// 
    /// USAGE:
    /// 1. Add this script to any GameObject in your scene (usually an empty "Bootstrap" object)
    /// 2. Configure which components to auto-create in the Inspector
    /// 3. OR - Enable RuntimeInitializeOnLoad for fully automatic setup (no scene setup required)
    /// 
    /// The bootstrapper will:
    /// - Auto-create missing FlutterBridge if needed
    /// - Auto-create missing MessageRouter if needed  
    /// - Auto-create custom FlutterMonoBehaviour targets (configurable)
    /// - Log helpful messages about what was created
    /// </summary>
    [DefaultExecutionOrder(-1000)]
    public class GameFrameworkBootstrapper : MonoBehaviour
    {
        #region Configuration

        [Header("Auto-Create Settings")]
        [Tooltip("Automatically create FlutterBridge if not found in scene")]
        [SerializeField] private bool autoCreateFlutterBridge = true;

        [Tooltip("Automatically create MessageRouter if not found in scene")]
        [SerializeField] private bool autoCreateMessageRouter = true;

        [Tooltip("List of FlutterMonoBehaviour types to auto-create (by type name)")]
        [SerializeField] private List<string> autoCreateTargets = new List<string> { "GameFrameworkDemo" };

        [Header("Logging")]
        [Tooltip("Enable verbose logging of bootstrap actions")]
        [SerializeField] private bool verboseLogging = true;

        #endregion

        #region Static Bootstrap (RuntimeInitializeOnLoad)

        /// <summary>
        /// Static flag to enable/disable automatic bootstrap without scene setup.
        /// Set this to true before scene load to enable fully automatic setup.
        /// </summary>
        public static bool EnableAutoBootstrap { get; set; } = true;

        /// <summary>
        /// List of target type names to auto-create when using RuntimeInitializeOnLoad.
        /// Add type names here before scene load.
        /// </summary>
        public static List<string> StaticAutoCreateTargets { get; } = new List<string> { "GameFrameworkDemo" };

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void OnRuntimeInitialize()
        {
            if (!EnableAutoBootstrap) return;

            // Check if a bootstrapper already exists in the scene
            var existingBootstrapper = FindObjectOfType<GameFrameworkBootstrapper>();
            if (existingBootstrapper != null)
            {
                // Let the scene bootstrapper handle it
                return;
            }

            // Create a runtime bootstrapper
            var go = new GameObject("[GameFramework Bootstrap]");
            var bootstrapper = go.AddComponent<GameFrameworkBootstrapper>();
            bootstrapper.autoCreateTargets = new List<string>(StaticAutoCreateTargets);
            DontDestroyOnLoad(go);

            Debug.Log("[GameFrameworkBootstrapper] Auto-initialized via RuntimeInitializeOnLoad");
        }

        #endregion

        #region Unity Lifecycle

        void Awake()
        {
            Bootstrap();
        }

        #endregion

        #region Bootstrap Logic

        private void Bootstrap()
        {
            Log("Starting bootstrap process...");

            // 1. Ensure FlutterBridge exists
            if (autoCreateFlutterBridge)
            {
                EnsureFlutterBridge();
            }

            // 2. Ensure MessageRouter exists
            if (autoCreateMessageRouter)
            {
                EnsureMessageRouter();
            }

            // 3. Auto-create configured targets
            foreach (var targetTypeName in autoCreateTargets)
            {
                EnsureTarget(targetTypeName);
            }

            Log("Bootstrap complete");
        }

        private void EnsureFlutterBridge()
        {
            if (FlutterBridge.Instance != null)
            {
                Log("FlutterBridge already exists");
                return;
            }

            // FlutterBridge.Instance auto-creates if missing, but we log it
            var bridge = FlutterBridge.Instance;
            Log("FlutterBridge auto-created");
        }

        private void EnsureMessageRouter()
        {
            if (MessageRouter.Instance != null)
            {
                Log("MessageRouter already exists");
                return;
            }

            // MessageRouter.Instance auto-creates if missing
            var router = MessageRouter.Instance;
            Log("MessageRouter auto-created");
        }

        private void EnsureTarget(string typeName)
        {
            if (string.IsNullOrEmpty(typeName)) return;

            // First, try to find existing instance by type name
            var existingBehaviour = FindFlutterMonoBehaviourByTypeName(typeName);
            if (existingBehaviour != null)
            {
                Log($"Target '{typeName}' already exists on GameObject '{existingBehaviour.gameObject.name}'");
                return;
            }

            // Try to find the type
            Type targetType = FindType(typeName);
            if (targetType == null)
            {
                Debug.LogWarning($"[GameFrameworkBootstrapper] Could not find type '{typeName}'. " +
                    $"Make sure the script exists and the namespace is correct.");
                return;
            }

            // Verify it's a FlutterMonoBehaviour
            if (!typeof(FlutterMonoBehaviour).IsAssignableFrom(targetType))
            {
                Debug.LogWarning($"[GameFrameworkBootstrapper] Type '{typeName}' is not a FlutterMonoBehaviour. Skipping.");
                return;
            }

            // Create the GameObject with the component
            var go = new GameObject(typeName);
            go.AddComponent(targetType);
            Log($"Auto-created GameObject '{typeName}' with {typeName} component");
        }

        private FlutterMonoBehaviour FindFlutterMonoBehaviourByTypeName(string typeName)
        {
            var allBehaviours = FindObjectsOfType<FlutterMonoBehaviour>();
            foreach (var behaviour in allBehaviours)
            {
                if (behaviour.GetType().Name == typeName)
                {
                    return behaviour;
                }
            }
            return null;
        }

        private Type FindType(string typeName)
        {
            // Search in all loaded assemblies
            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                // Try direct type name
                var type = assembly.GetType(typeName);
                if (type != null) return type;

                // Try with common namespaces
                type = assembly.GetType($"GameFrameworkTemplate.{typeName}");
                if (type != null) return type;

                type = assembly.GetType($"Xraph.GameFramework.Unity.{typeName}");
                if (type != null) return type;

                // Search all types in assembly
                foreach (var t in assembly.GetTypes())
                {
                    if (t.Name == typeName)
                    {
                        return t;
                    }
                }
            }

            return null;
        }

        #endregion

        #region Logging

        private void Log(string message)
        {
            if (verboseLogging)
            {
                Debug.Log($"[GameFrameworkBootstrapper] {message}");
            }
        }

        #endregion
    }
}
