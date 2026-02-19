using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Validates Unity project configuration for Flutter integration
    ///
    /// Checks project settings, scene setup, and provides recommendations
    /// for optimal Flutter integration.
    /// </summary>
    public class FlutterProjectValidator : EditorWindow
    {
        private Vector2 scrollPosition;
        private List<ValidationResult> validationResults = new List<ValidationResult>();
        private bool hasValidated = false;

        private class ValidationResult
        {
            public string Category;
            public string Message;
            public ValidationType Type;
            public System.Action FixAction;
        }

        private enum ValidationType
        {
            Success,
            Warning,
            Error,
            Info
        }

        [MenuItem("Game Framework/Validate Project")]
        public static void ShowWindow()
        {
            var window = GetWindow<FlutterProjectValidator>("Flutter Validator");
            window.minSize = new Vector2(600, 400);
        }

        void OnGUI()
        {
            GUILayout.Label("Flutter Integration Validator", EditorStyles.boldLabel);
            GUILayout.Space(10);

            if (GUILayout.Button("Run Validation", GUILayout.Height(40)))
            {
                RunValidation();
            }

            GUILayout.Space(10);

            if (hasValidated)
            {
                DisplayResults();
            }
        }

        private void RunValidation()
        {
            validationResults.Clear();
            hasValidated = true;

            ValidateProjectSettings();
            ValidateSceneSetup();
            ValidatePlatformSettings();
            ValidateFlutterBridgeSetup();
            ValidateBuildSettings();
        }

        private void ValidateProjectSettings()
        {
            // Check scripting runtime
            var scriptingRuntime = PlayerSettings.GetScriptingBackend(BuildTargetGroup.Android);
            if (scriptingRuntime == ScriptingImplementation.IL2CPP)
            {
                AddResult("Project Settings", "Scripting backend is IL2CPP (Recommended)", ValidationType.Success);
            }
            else
            {
                AddResult("Project Settings", "Scripting backend is Mono. IL2CPP is recommended for better performance",
                    ValidationType.Warning, () => {
                        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
                        PlayerSettings.SetScriptingBackend(BuildTargetGroup.iOS, ScriptingImplementation.IL2CPP);
                    });
            }

            // Check API compatibility level
            var apiLevel = PlayerSettings.GetApiCompatibilityLevel(BuildTargetGroup.Android);
            if (apiLevel == ApiCompatibilityLevel.NET_4_6 || apiLevel == ApiCompatibilityLevel.NET_Standard_2_0)
            {
                AddResult("Project Settings", "API Compatibility Level is .NET 4.x/Standard 2.0 (Good)", ValidationType.Success);
            }
            else
            {
                AddResult("Project Settings", "Consider using .NET Standard 2.0 for better compatibility", ValidationType.Info);
            }

            // Check stripping level
            var strippingLevel = PlayerSettings.GetManagedStrippingLevel(BuildTargetGroup.Android);
            if (strippingLevel == ManagedStrippingLevel.Minimal || strippingLevel == ManagedStrippingLevel.Low)
            {
                AddResult("Project Settings", "Stripping level is appropriate for Flutter integration", ValidationType.Success);
            }
        }

        private void ValidateSceneSetup()
        {
            var activeScene = SceneManager.GetActiveScene();
            var rootObjects = activeScene.GetRootGameObjects();
            var allMonoBehaviours = Object.FindObjectsOfType<MonoBehaviour>();

            // Check for FlutterBridge
            bool hasFlutterBridge = rootObjects.Any(obj => obj.GetComponent<FlutterBridge>() != null);
            if (hasFlutterBridge)
            {
                AddResult("Scene Setup", "FlutterBridge found in scene ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Scene Setup", "FlutterBridge not found in scene (will auto-create at runtime)",
                    ValidationType.Info, () => CreateFlutterBridge());
            }

            // Check for MessageRouter
            bool hasMessageRouter = Object.FindObjectOfType<MessageRouter>() != null;
            if (hasMessageRouter)
            {
                AddResult("Scene Setup", "MessageRouter found in scene ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Scene Setup", "MessageRouter not found in scene (will auto-create at runtime)",
                    ValidationType.Info, () => CreateMessageRouter());
            }

            // Check for GameFrameworkBootstrapper
            bool hasBootstrapper = Object.FindObjectOfType<GameFrameworkBootstrapper>() != null;
            if (hasBootstrapper)
            {
                AddResult("Scene Setup", "GameFrameworkBootstrapper found in scene ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Scene Setup", "GameFrameworkBootstrapper not in scene. Consider adding for auto-creation of targets",
                    ValidationType.Info, () => CreateBootstrapper());
            }

            // Check for FlutterMonoBehaviour instances
            var flutterBehaviours = allMonoBehaviours.OfType<FlutterMonoBehaviour>().ToList();
            if (flutterBehaviours.Count > 0)
            {
                AddResult("Scene Setup", $"Found {flutterBehaviours.Count} FlutterMonoBehaviour instance(s) ✓", ValidationType.Success);
                foreach (var fb in flutterBehaviours)
                {
                    AddResult("Scene Setup", $"  - {fb.GetType().Name} on '{fb.gameObject.name}'", ValidationType.Info);
                }
            }
            else
            {
                AddResult("Scene Setup", "No FlutterMonoBehaviour instances found. Messages from Flutter may not be received",
                    ValidationType.Warning, () => CreateDemoObject());
            }

            // Check for FlutterSceneManager
            bool hasSceneManager = rootObjects.Any(obj => obj.GetComponent<FlutterSceneManager>() != null);
            if (hasSceneManager)
            {
                AddResult("Scene Setup", "FlutterSceneManager found in scene ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Scene Setup", "FlutterSceneManager not found. Consider adding it for scene notifications",
                    ValidationType.Warning, () => CreateFlutterSceneManager());
            }

            // Check for game manager
            bool hasGameManager = rootObjects.Any(obj => obj.GetComponent<FlutterGameManager>() != null);
            if (hasGameManager)
            {
                AddResult("Scene Setup", "FlutterGameManager found in scene ✓", ValidationType.Info);
            }
            else
            {
                AddResult("Scene Setup", "FlutterGameManager not found. You may want to add it or create your own",
                    ValidationType.Info, () => CreateFlutterGameManager());
            }
        }

        private void ValidatePlatformSettings()
        {
            // Android settings
            if (PlayerSettings.Android.minSdkVersion < AndroidSdkVersions.AndroidApiLevel25)
            {
                AddResult("Android Settings", "minSdkVersion must be at least 25 for Flutter",
                    ValidationType.Error, () => {
                        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel25;
                    });
            }
            else
            {
                AddResult("Android Settings", $"minSdkVersion is {PlayerSettings.Android.minSdkVersion} (OK)", ValidationType.Success);
            }

            // Check target architectures
            var archs = PlayerSettings.Android.targetArchitectures;
            if ((archs & AndroidArchitecture.ARM64) != 0)
            {
                AddResult("Android Settings", "ARM64 architecture enabled ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Android Settings", "ARM64 architecture should be enabled for Google Play",
                    ValidationType.Warning, () => {
                        PlayerSettings.Android.targetArchitectures |= AndroidArchitecture.ARM64;
                    });
            }

            // iOS settings
            var iosVersion = PlayerSettings.iOS.targetOSVersionString;
            if (float.TryParse(iosVersion, out float version) && version >= 12.0f)
            {
                AddResult("iOS Settings", $"iOS target version is {iosVersion} (OK)", ValidationType.Success);
            }
            else
            {
                AddResult("iOS Settings", "iOS target version should be at least 12.0",
                    ValidationType.Warning, () => {
                        PlayerSettings.iOS.targetOSVersionString = "12.0";
                    });
            }
        }

        private void ValidateFlutterBridgeSetup()
        {
            // Check if FlutterBridge script exists
            var bridgeScript = AssetDatabase.FindAssets("t:Script FlutterBridge")
                .Select(guid => AssetDatabase.GUIDToAssetPath(guid))
                .FirstOrDefault();

            if (!string.IsNullOrEmpty(bridgeScript))
            {
                AddResult("Flutter Scripts", "FlutterBridge.cs found ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Flutter Scripts", "FlutterBridge.cs not found. Did you import the Flutter plugin scripts?",
                    ValidationType.Error);
            }

            // Check for iOS plugin
            var iosPlugin = AssetDatabase.FindAssets("FlutterBridge t:DefaultAsset")
                .Select(guid => AssetDatabase.GUIDToAssetPath(guid))
                .Where(path => path.Contains("Plugins/iOS") && path.EndsWith(".mm"))
                .FirstOrDefault();

            if (!string.IsNullOrEmpty(iosPlugin))
            {
                AddResult("Flutter Scripts", "iOS native bridge found ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Flutter Scripts", "iOS native bridge (FlutterBridge.mm) not found in Plugins/iOS",
                    ValidationType.Warning);
            }
        }

        private void ValidateBuildSettings()
        {
            // Check if there are scenes in build settings
            var scenesInBuild = EditorBuildSettings.scenes.Where(s => s.enabled).ToList();
            if (scenesInBuild.Count > 0)
            {
                AddResult("Build Settings", $"{scenesInBuild.Count} scene(s) in build settings ✓", ValidationType.Success);
            }
            else
            {
                AddResult("Build Settings", "No scenes added to build settings",
                    ValidationType.Error, () => {
                        EditorWindow.GetWindow(System.Type.GetType("UnityEditor.BuildPlayerWindow,UnityEditor"));
                    });
            }

            // Check for active build target
            var currentTarget = EditorUserBuildSettings.activeBuildTarget;
            if (currentTarget == BuildTarget.Android || currentTarget == BuildTarget.iOS)
            {
                AddResult("Build Settings", $"Build target is {currentTarget} (Ready for Flutter)", ValidationType.Success);
            }
            else
            {
                AddResult("Build Settings", $"Build target is {currentTarget}. Switch to Android or iOS for Flutter",
                    ValidationType.Info);
            }
        }

        private void DisplayResults()
        {
            var successCount = validationResults.Count(r => r.Type == ValidationType.Success);
            var warningCount = validationResults.Count(r => r.Type == ValidationType.Warning);
            var errorCount = validationResults.Count(r => r.Type == ValidationType.Error);
            var infoCount = validationResults.Count(r => r.Type == ValidationType.Info);

            // Summary
            GUILayout.BeginHorizontal(EditorStyles.helpBox);
            GUILayout.Label($"Results: {validationResults.Count} checks", EditorStyles.boldLabel);
            GUILayout.FlexibleSpace();

            if (errorCount > 0)
                GUILayout.Label($"✗ {errorCount} Errors", GetStatusStyle(ValidationType.Error));
            if (warningCount > 0)
                GUILayout.Label($"⚠ {warningCount} Warnings", GetStatusStyle(ValidationType.Warning));
            if (successCount > 0)
                GUILayout.Label($"✓ {successCount} Passed", GetStatusStyle(ValidationType.Success));

            GUILayout.EndHorizontal();

            GUILayout.Space(10);

            // Results list
            scrollPosition = GUILayout.BeginScrollView(scrollPosition);

            string currentCategory = "";
            foreach (var result in validationResults)
            {
                if (result.Category != currentCategory)
                {
                    currentCategory = result.Category;
                    GUILayout.Space(10);
                    GUILayout.Label(currentCategory, EditorStyles.boldLabel);
                }

                GUILayout.BeginHorizontal(EditorStyles.helpBox);

                // Icon
                GUILayout.Label(GetIcon(result.Type), GUILayout.Width(20));

                // Message
                GUILayout.Label(result.Message, EditorStyles.wordWrappedLabel);

                // Fix button
                if (result.FixAction != null)
                {
                    if (GUILayout.Button("Fix", GUILayout.Width(60)))
                    {
                        result.FixAction.Invoke();
                        EditorUtility.DisplayDialog("Fixed", "Setting has been updated. Re-run validation to verify.", "OK");
                    }
                }

                GUILayout.EndHorizontal();
            }

            GUILayout.EndScrollView();

            // Footer
            GUILayout.Space(10);
            if (errorCount == 0 && warningCount == 0)
            {
                GUILayout.BeginHorizontal(EditorStyles.helpBox);
                GUILayout.Label("✓ All checks passed! Your project is ready for Flutter integration.",
                    GetStatusStyle(ValidationType.Success));
                GUILayout.EndHorizontal();
            }
        }

        private void AddResult(string category, string message, ValidationType type, System.Action fixAction = null)
        {
            validationResults.Add(new ValidationResult
            {
                Category = category,
                Message = message,
                Type = type,
                FixAction = fixAction
            });
        }

        private string GetIcon(ValidationType type)
        {
            switch (type)
            {
                case ValidationType.Success: return "✓";
                case ValidationType.Warning: return "⚠";
                case ValidationType.Error: return "✗";
                case ValidationType.Info: return "ℹ";
                default: return "•";
            }
        }

        private GUIStyle GetStatusStyle(ValidationType type)
        {
            var style = new GUIStyle(EditorStyles.label);
            switch (type)
            {
                case ValidationType.Success:
                    style.normal.textColor = new Color(0, 0.7f, 0);
                    break;
                case ValidationType.Warning:
                    style.normal.textColor = new Color(0.8f, 0.5f, 0);
                    break;
                case ValidationType.Error:
                    style.normal.textColor = new Color(0.8f, 0, 0);
                    break;
                case ValidationType.Info:
                    style.normal.textColor = new Color(0, 0.5f, 0.8f);
                    break;
            }
            style.fontStyle = FontStyle.Bold;
            return style;
        }

        private void CreateFlutterBridge()
        {
            var go = new GameObject("FlutterBridge");
            go.AddComponent<FlutterBridge>();
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
        }

        private void CreateMessageRouter()
        {
            var go = new GameObject("MessageRouter");
            go.AddComponent<MessageRouter>();
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
        }

        private void CreateBootstrapper()
        {
            var go = new GameObject("[GameFramework Bootstrap]");
            go.AddComponent<GameFrameworkBootstrapper>();
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
        }

        private void CreateDemoObject()
        {
            // Try to find the GameFrameworkDemo type
            var demoType = FindType("GameFrameworkDemo");
            if (demoType != null)
            {
                var go = new GameObject("GameFrameworkDemo");
                go.AddComponent(demoType);
                Selection.activeGameObject = go;
                EditorGUIUtility.PingObject(go);
            }
            else
            {
                Debug.LogWarning("[FlutterValidator] GameFrameworkDemo type not found. " +
                    "You can add your own FlutterMonoBehaviour script to a GameObject.");
            }
        }

        private System.Type FindType(string typeName)
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

        private void CreateFlutterSceneManager()
        {
            var go = new GameObject("FlutterSceneManager");
            go.AddComponent<FlutterSceneManager>();
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
        }

        private void CreateFlutterGameManager()
        {
            var go = new GameObject("FlutterGameManager");
            go.AddComponent<FlutterGameManager>();
            Selection.activeGameObject = go;
            EditorGUIUtility.PingObject(go);
        }
    }
}
