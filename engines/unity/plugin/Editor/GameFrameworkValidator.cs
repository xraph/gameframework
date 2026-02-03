using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Automatic validation for Game Framework components.
    /// 
    /// Runs automatically when entering play mode to catch configuration issues early.
    /// Also provides editor window for manual validation.
    /// 
    /// Checks:
    /// - FlutterMonoBehaviour instances exist and are properly configured
    /// - MessageRouter is present for message routing
    /// - GameFrameworkBootstrapper is present for auto-creation
    /// - Required GameObjects exist in the scene
    /// </summary>
    [InitializeOnLoad]
    public class GameFrameworkValidator
    {
        private static bool _enablePlayModeValidation = true;
        private static bool _showWarningsInConsole = true;

        static GameFrameworkValidator()
        {
            EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
        }

        /// <summary>
        /// Enable/disable automatic validation when entering play mode.
        /// </summary>
        public static bool EnablePlayModeValidation
        {
            get => _enablePlayModeValidation;
            set
            {
                _enablePlayModeValidation = value;
                EditorPrefs.SetBool("GameFramework.EnablePlayModeValidation", value);
            }
        }

        /// <summary>
        /// Enable/disable warning messages in console.
        /// </summary>
        public static bool ShowWarningsInConsole
        {
            get => _showWarningsInConsole;
            set
            {
                _showWarningsInConsole = value;
                EditorPrefs.SetBool("GameFramework.ShowWarningsInConsole", value);
            }
        }

        [InitializeOnLoadMethod]
        private static void Initialize()
        {
            _enablePlayModeValidation = EditorPrefs.GetBool("GameFramework.EnablePlayModeValidation", true);
            _showWarningsInConsole = EditorPrefs.GetBool("GameFramework.ShowWarningsInConsole", true);
        }

        private static void OnPlayModeStateChanged(PlayModeStateChange state)
        {
            if (!_enablePlayModeValidation) return;

            if (state == PlayModeStateChange.ExitingEditMode)
            {
                ValidateScene();
            }
        }

        /// <summary>
        /// Validate the current scene for Game Framework configuration.
        /// </summary>
        [MenuItem("Game Framework/Validate Scene", priority = 20)]
        public static void ValidateScene()
        {
            var issues = new List<string>();
            var warnings = new List<string>();
            var info = new List<string>();

            var activeScene = SceneManager.GetActiveScene();
            var allMonoBehaviours = Object.FindObjectsOfType<MonoBehaviour>();

            // Check for FlutterBridge
            var flutterBridge = Object.FindObjectOfType<FlutterBridge>();
            if (flutterBridge == null)
            {
                // FlutterBridge auto-creates, but warn if not in scene for explicit setup
                info.Add("FlutterBridge not in scene (will be auto-created at runtime)");
            }

            // Check for MessageRouter
            var messageRouter = Object.FindObjectOfType<MessageRouter>();
            if (messageRouter == null)
            {
                // MessageRouter auto-creates, but warn if not in scene for explicit setup
                info.Add("MessageRouter not in scene (will be auto-created at runtime)");
            }

            // Check for GameFrameworkBootstrapper
            var bootstrapper = Object.FindObjectOfType<GameFrameworkBootstrapper>();
            if (bootstrapper == null)
            {
                // Check if GameFrameworkBootstrapper.EnableAutoBootstrap is set
                if (GameFrameworkBootstrapper.EnableAutoBootstrap)
                {
                    info.Add("GameFrameworkBootstrapper not in scene (RuntimeInitializeOnLoad will auto-create)");
                }
                else
                {
                    warnings.Add("GameFrameworkBootstrapper not in scene and auto-bootstrap is disabled. " +
                        "Message targets may not be auto-created.");
                }
            }

            // Check for FlutterMonoBehaviour instances
            var flutterBehaviours = allMonoBehaviours.OfType<FlutterMonoBehaviour>().ToList();
            if (flutterBehaviours.Count == 0)
            {
                // Check if bootstrapper will create them
                if (bootstrapper != null || GameFrameworkBootstrapper.EnableAutoBootstrap)
                {
                    // Check static auto-create targets
                    var autoTargets = GameFrameworkBootstrapper.StaticAutoCreateTargets;
                    if (autoTargets.Count > 0)
                    {
                        info.Add($"No FlutterMonoBehaviour instances in scene. " +
                            $"Bootstrapper will auto-create: {string.Join(", ", autoTargets)}");
                    }
                }
                else
                {
                    warnings.Add("No FlutterMonoBehaviour instances found in scene. " +
                        "Flutter messages may not be received. " +
                        "Add a script that extends FlutterMonoBehaviour to a GameObject.");
                }
            }
            else
            {
                info.Add($"Found {flutterBehaviours.Count} FlutterMonoBehaviour instance(s):");
                foreach (var fb in flutterBehaviours)
                {
                    info.Add($"  - {fb.GetType().Name} on '{fb.gameObject.name}'");
                }
            }

            // Check for specific demo object (GameFrameworkDemo)
            var gameFrameworkDemo = allMonoBehaviours
                .FirstOrDefault(mb => mb.GetType().Name == "GameFrameworkDemo");
            
            if (gameFrameworkDemo == null)
            {
                // Check if it will be auto-created
                if (bootstrapper != null || 
                    (GameFrameworkBootstrapper.EnableAutoBootstrap && 
                     GameFrameworkBootstrapper.StaticAutoCreateTargets.Contains("GameFrameworkDemo")))
                {
                    info.Add("GameFrameworkDemo not in scene (will be auto-created by bootstrapper)");
                }
                else
                {
                    // This is just informational - not an error
                    info.Add("GameFrameworkDemo not in scene. If you're using a custom target, this is OK.");
                }
            }

            // Log results
            if (_showWarningsInConsole)
            {
                foreach (var issue in issues)
                {
                    Debug.LogError($"[GameFramework Validator] ERROR: {issue}");
                }

                foreach (var warning in warnings)
                {
                    Debug.LogWarning($"[GameFramework Validator] WARNING: {warning}");
                }

                // Only show info in verbose mode or if there are issues
                if (issues.Count > 0 || warnings.Count > 0)
                {
                    foreach (var i in info)
                    {
                        Debug.Log($"[GameFramework Validator] INFO: {i}");
                    }
                }
            }

            // Show summary dialog if there are issues
            if (issues.Count > 0 || warnings.Count > 0)
            {
                var message = new System.Text.StringBuilder();
                
                if (issues.Count > 0)
                {
                    message.AppendLine("ERRORS:");
                    foreach (var issue in issues)
                    {
                        message.AppendLine($"  • {issue}");
                    }
                    message.AppendLine();
                }

                if (warnings.Count > 0)
                {
                    message.AppendLine("WARNINGS:");
                    foreach (var warning in warnings)
                    {
                        message.AppendLine($"  • {warning}");
                    }
                }

                // Don't block play mode, just warn
                Debug.LogWarning($"[GameFramework Validator] Found {issues.Count} error(s) and {warnings.Count} warning(s). " +
                    "Run 'Game Framework > Validate Scene' for details.");
            }
        }

        /// <summary>
        /// Quick fix: Add GameFrameworkBootstrapper to the scene.
        /// </summary>
        [MenuItem("Game Framework/Quick Fix/Add Bootstrapper", priority = 100)]
        public static void AddBootstrapper()
        {
            var existing = Object.FindObjectOfType<GameFrameworkBootstrapper>();
            if (existing != null)
            {
                Selection.activeGameObject = existing.gameObject;
                EditorGUIUtility.PingObject(existing.gameObject);
                Debug.Log("[GameFramework] Bootstrapper already exists in scene.");
                return;
            }

            var go = new GameObject("[GameFramework Bootstrap]");
            go.AddComponent<GameFrameworkBootstrapper>();
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
            Debug.Log("[GameFramework] Added GameFrameworkBootstrapper to scene.");
        }

        /// <summary>
        /// Quick fix: Add GameFrameworkDemo to the scene.
        /// </summary>
        [MenuItem("Game Framework/Quick Fix/Add Demo Object", priority = 101)]
        public static void AddDemoObject()
        {
            // Try to find the GameFrameworkDemo type
            var demoType = FindType("GameFrameworkDemo");
            if (demoType == null)
            {
                Debug.LogError("[GameFramework] GameFrameworkDemo type not found. " +
                    "Make sure the script is in your project.");
                return;
            }

            var existing = Object.FindObjectsOfType<MonoBehaviour>()
                .FirstOrDefault(mb => mb.GetType().Name == "GameFrameworkDemo");
            
            if (existing != null)
            {
                Selection.activeGameObject = existing.gameObject;
                EditorGUIUtility.PingObject(existing.gameObject);
                Debug.Log("[GameFramework] GameFrameworkDemo already exists in scene.");
                return;
            }

            var go = new GameObject("GameFrameworkDemo");
            go.AddComponent(demoType);
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
            Debug.Log("[GameFramework] Added GameFrameworkDemo to scene.");
        }

        /// <summary>
        /// Quick fix: Add MessageRouter to the scene.
        /// </summary>
        [MenuItem("Game Framework/Quick Fix/Add Message Router", priority = 102)]
        public static void AddMessageRouter()
        {
            var existing = Object.FindObjectOfType<MessageRouter>();
            if (existing != null)
            {
                Selection.activeGameObject = existing.gameObject;
                EditorGUIUtility.PingObject(existing.gameObject);
                Debug.Log("[GameFramework] MessageRouter already exists in scene.");
                return;
            }

            var go = new GameObject("MessageRouter");
            go.AddComponent<MessageRouter>();
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
            Debug.Log("[GameFramework] Added MessageRouter to scene.");
        }

        /// <summary>
        /// Quick fix: Configure script execution order for Game Framework components.
        /// Ensures FlutterBridge and MessageRouter initialize before other scripts.
        /// </summary>
        [MenuItem("Game Framework/Quick Fix/Fix Script Execution Order", priority = 103)]
        public static void FixScriptExecutionOrder()
        {
            bool changed = false;

            // Define the required execution order
            var executionOrder = new Dictionary<string, int>
            {
                { "Xraph.GameFramework.Unity.FlutterBridge", -200 },
                { "Xraph.GameFramework.Unity.MessageRouter", -100 },
                { "Xraph.GameFramework.Unity.GameFrameworkBootstrapper", -50 }
            };

            foreach (var kvp in executionOrder)
            {
                var scriptType = FindType(kvp.Key.Split('.').Last());
                if (scriptType == null)
                {
                    Debug.LogWarning($"[GameFramework] Could not find script type: {kvp.Key}");
                    continue;
                }

                var script = FindMonoScript(scriptType);
                if (script == null)
                {
                    Debug.LogWarning($"[GameFramework] Could not find MonoScript for: {kvp.Key}");
                    continue;
                }

                int currentOrder = MonoImporter.GetExecutionOrder(script);
                if (currentOrder != kvp.Value)
                {
                    MonoImporter.SetExecutionOrder(script, kvp.Value);
                    Debug.Log($"[GameFramework] Set {script.name} execution order: {currentOrder} → {kvp.Value}");
                    changed = true;
                }
                else
                {
                    Debug.Log($"[GameFramework] {script.name} execution order already correct: {kvp.Value}");
                }
            }

            if (changed)
            {
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
                Debug.Log("[GameFramework] ✅ Script execution order fixed! Please rebuild your Unity project.");
            }
            else
            {
                Debug.Log("[GameFramework] Script execution order is already correct.");
            }
        }

        /// <summary>
        /// Find MonoScript asset for a given type.
        /// </summary>
        private static MonoScript FindMonoScript(System.Type type)
        {
            var scripts = UnityEngine.Resources.FindObjectsOfTypeAll<MonoScript>();
            return scripts.FirstOrDefault(s => s.GetClass() == type);
        }

        /// <summary>
        /// Toggle play mode validation.
        /// </summary>
        [MenuItem("Game Framework/Settings/Enable Play Mode Validation", priority = 200)]
        public static void TogglePlayModeValidation()
        {
            EnablePlayModeValidation = !EnablePlayModeValidation;
            Debug.Log($"[GameFramework] Play mode validation: {(EnablePlayModeValidation ? "Enabled" : "Disabled")}");
        }

        [MenuItem("Game Framework/Settings/Enable Play Mode Validation", true)]
        public static bool TogglePlayModeValidation_Validate()
        {
            Menu.SetChecked("Game Framework/Settings/Enable Play Mode Validation", EnablePlayModeValidation);
            return true;
        }

        private static System.Type FindType(string typeName)
        {
            foreach (var assembly in System.AppDomain.CurrentDomain.GetAssemblies())
            {
                var type = assembly.GetType(typeName);
                if (type != null) return type;

                type = assembly.GetType($"GameFrameworkTemplate.{typeName}");
                if (type != null) return type;

                type = assembly.GetType($"Xraph.GameFramework.Unity.{typeName}");
                if (type != null) return type;

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
    }
}
