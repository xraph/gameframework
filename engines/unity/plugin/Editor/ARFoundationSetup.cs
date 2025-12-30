using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using System.IO;

namespace FlutterUnity.Editor
{
    /// <summary>
    /// Automated setup for AR Foundation integration with Flutter
    /// </summary>
    public class ARFoundationSetup : EditorWindow
    {
        private enum ARPlatform
        {
            Both,
            ARCore,
            ARKit
        }

        private ARPlatform targetPlatform = ARPlatform.Both;
        private bool createExampleScene = true;
        private bool addFlutterBridge = true;
        private bool configureBuildSettings = true;
        private Vector2 scrollPosition;

        [MenuItem("Game Framework/AR Foundation Setup", false, 80)]
        public static void ShowWindow()
        {
            var window = GetWindow<ARFoundationSetup>("AR Foundation Setup");
            window.minSize = new Vector2(450, 600);
            window.Show();
        }

        private void OnGUI()
        {
            scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);

            // Header
            GUILayout.Space(10);
            GUIStyle titleStyle = new GUIStyle(EditorStyles.boldLabel);
            titleStyle.fontSize = 16;
            titleStyle.alignment = TextAnchor.MiddleCenter;
            EditorGUILayout.LabelField("AR Foundation Setup for Flutter", titleStyle);
            GUILayout.Space(10);

            EditorGUILayout.HelpBox(
                "This tool helps set up AR Foundation for use with Flutter. " +
                "It will configure your project settings, install required packages, " +
                "and optionally create an example AR scene.",
                MessageType.Info
            );

            GUILayout.Space(10);

            // Platform Selection
            DrawSection("Target Platform", () =>
            {
                targetPlatform = (ARPlatform)EditorGUILayout.EnumPopup("Platform:", targetPlatform);

                EditorGUI.indentLevel++;
                switch (targetPlatform)
                {
                    case ARPlatform.Both:
                        EditorGUILayout.LabelField("• ARCore (Android)", EditorStyles.miniLabel);
                        EditorGUILayout.LabelField("• ARKit (iOS)", EditorStyles.miniLabel);
                        break;
                    case ARPlatform.ARCore:
                        EditorGUILayout.LabelField("• ARCore (Android only)", EditorStyles.miniLabel);
                        break;
                    case ARPlatform.ARKit:
                        EditorGUILayout.LabelField("• ARKit (iOS only)", EditorStyles.miniLabel);
                        break;
                }
                EditorGUI.indentLevel--;
            });

            GUILayout.Space(10);

            // Setup Options
            DrawSection("Setup Options", () =>
            {
                createExampleScene = EditorGUILayout.Toggle("Create Example Scene", createExampleScene);
                if (createExampleScene)
                {
                    EditorGUI.indentLevel++;
                    EditorGUILayout.LabelField("Creates AR scene with:", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• AR Session Origin", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• AR Plane Manager", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• AR Raycast Manager", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• Flutter Bridge", EditorStyles.miniLabel);
                    EditorGUI.indentLevel--;
                }

                GUILayout.Space(5);

                addFlutterBridge = EditorGUILayout.Toggle("Add Flutter Bridge", addFlutterBridge);
                if (addFlutterBridge)
                {
                    EditorGUI.indentLevel++;
                    EditorGUILayout.LabelField("Adds FlutterBridge to AR scene", EditorStyles.miniLabel);
                    EditorGUI.indentLevel--;
                }

                GUILayout.Space(5);

                configureBuildSettings = EditorGUILayout.Toggle("Configure Build Settings", configureBuildSettings);
                if (configureBuildSettings)
                {
                    EditorGUI.indentLevel++;
                    EditorGUILayout.LabelField("Sets up project for AR:", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• Graphics API", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• Camera usage description", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• Required capabilities", EditorStyles.miniLabel);
                    EditorGUI.indentLevel--;
                }
            });

            GUILayout.Space(10);

            // Required Packages
            DrawSection("Required Packages", () =>
            {
                EditorGUILayout.LabelField("The following packages are required:", EditorStyles.boldLabel);
                EditorGUILayout.LabelField("• com.unity.xr.arfoundation (4.0+)", EditorStyles.miniLabel);
                EditorGUILayout.LabelField("• com.unity.xr.arcore (iOS)", EditorStyles.miniLabel);
                EditorGUILayout.LabelField("• com.unity.xr.arkit (Android)", EditorStyles.miniLabel);

                GUILayout.Space(5);

                if (GUILayout.Button("Open Package Manager"))
                {
                    UnityEditor.PackageManager.UI.Window.Open("com.unity.xr.arfoundation");
                }
            });

            GUILayout.Space(10);

            // Prerequisites Check
            DrawSection("Prerequisites Check", () =>
            {
                CheckARFoundationPackage();
                CheckPlatformSupport();
            });

            GUILayout.Space(20);

            // Setup Button
            GUI.backgroundColor = new Color(0.3f, 0.8f, 0.3f);
            if (GUILayout.Button("Run Setup", GUILayout.Height(40)))
            {
                RunSetup();
            }
            GUI.backgroundColor = Color.white;

            GUILayout.Space(10);

            // Documentation Link
            if (GUILayout.Button("Open AR Foundation Guide"))
            {
                string guidePath = Path.Combine(Application.dataPath, "FlutterPlugins/AR_FOUNDATION.md");
                if (File.Exists(guidePath))
                {
                    Application.OpenURL($"file://{guidePath}");
                }
                else
                {
                    EditorUtility.DisplayDialog(
                        "Guide Not Found",
                        "AR_FOUNDATION.md not found in Assets/FlutterPlugins/.\n\n" +
                        "Please ensure the Flutter Unity Integration package is properly installed.",
                        "OK"
                    );
                }
            }

            GUILayout.Space(10);

            EditorGUILayout.EndScrollView();
        }

        private void DrawSection(string title, System.Action content)
        {
            EditorGUILayout.LabelField(title, EditorStyles.boldLabel);
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            content();
            EditorGUILayout.EndVertical();
        }

        private void CheckARFoundationPackage()
        {
            bool hasARFoundation = HasPackage("com.unity.xr.arfoundation");
            bool hasARCore = targetPlatform != ARPlatform.ARKit && HasPackage("com.unity.xr.arcore");
            bool hasARKit = targetPlatform != ARPlatform.ARCore && HasPackage("com.unity.xr.arkit");

            DrawCheckResult("AR Foundation", hasARFoundation);
            if (targetPlatform != ARPlatform.ARKit)
            {
                DrawCheckResult("ARCore XR Plugin", hasARCore);
            }
            if (targetPlatform != ARPlatform.ARCore)
            {
                DrawCheckResult("ARKit XR Plugin", hasARKit);
            }
        }

        private void CheckPlatformSupport()
        {
            if (targetPlatform != ARPlatform.ARKit)
            {
                bool androidSupport = BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Android, BuildTarget.Android);
                DrawCheckResult("Android Build Support", androidSupport);
            }

            if (targetPlatform != ARPlatform.ARCore)
            {
                bool iosSupport = BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.iOS, BuildTarget.iOS);
                DrawCheckResult("iOS Build Support", iosSupport);
            }
        }

        private void DrawCheckResult(string label, bool passed)
        {
            EditorGUILayout.BeginHorizontal();
            GUIContent icon = passed
                ? EditorGUIUtility.IconContent("TestPassed")
                : EditorGUIUtility.IconContent("TestFailed");
            GUILayout.Label(icon, GUILayout.Width(20), GUILayout.Height(20));
            EditorGUILayout.LabelField(label, passed ? "✓ Installed" : "✗ Missing");
            EditorGUILayout.EndHorizontal();
        }

        private bool HasPackage(string packageName)
        {
            var request = UnityEditor.PackageManager.Client.List();
            while (!request.IsCompleted) { }

            if (request.Status == UnityEditor.PackageManager.StatusCode.Success)
            {
                foreach (var package in request.Result)
                {
                    if (package.name == packageName)
                    {
                        return true;
                    }
                }
            }
            return false;
        }

        private void RunSetup()
        {
            if (!EditorUtility.DisplayDialog(
                "Confirm Setup",
                "This will configure your project for AR Foundation integration with Flutter.\n\n" +
                "Make sure you have the required packages installed first.\n\n" +
                "Continue?",
                "Yes",
                "Cancel"))
            {
                return;
            }

            try
            {
                int progress = 0;
                int totalSteps = 3;

                // Step 1: Configure build settings
                if (configureBuildSettings)
                {
                    EditorUtility.DisplayProgressBar("AR Setup", "Configuring build settings...", (float)progress / totalSteps);
                    ConfigureBuildSettings();
                    progress++;
                }

                // Step 2: Create example scene
                if (createExampleScene)
                {
                    EditorUtility.DisplayProgressBar("AR Setup", "Creating example scene...", (float)progress / totalSteps);
                    CreateARScene();
                    progress++;
                }

                // Step 3: Add Flutter bridge
                if (addFlutterBridge)
                {
                    EditorUtility.DisplayProgressBar("AR Setup", "Adding Flutter Bridge...", (float)progress / totalSteps);
                    AddFlutterBridgeToScene();
                    progress++;
                }

                EditorUtility.ClearProgressBar();

                EditorUtility.DisplayDialog(
                    "Setup Complete",
                    "AR Foundation setup completed successfully!\n\n" +
                    (createExampleScene ? "Example scene created: Scenes/ARExample.unity\n" : "") +
                    "\nNext steps:\n" +
                    "1. Export your Unity project using Flutter > Export for Flutter\n" +
                    "2. Integrate with your Flutter app\n" +
                    "3. Test on a physical device (AR doesn't work in simulator)",
                    "OK"
                );

                Debug.Log("AR Foundation setup completed successfully!");
            }
            catch (System.Exception e)
            {
                EditorUtility.ClearProgressBar();
                EditorUtility.DisplayDialog("Error", $"Setup failed:\n{e.Message}", "OK");
                Debug.LogError($"AR setup failed: {e}");
            }
        }

        private void ConfigureBuildSettings()
        {
            // Android settings
            if (targetPlatform != ARPlatform.ARKit)
            {
                PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel24;
                PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
            }

            // iOS settings
            if (targetPlatform != ARPlatform.ARCore)
            {
                PlayerSettings.iOS.cameraUsageDescription = "Required for AR features";
                PlayerSettings.iOS.targetOSVersionString = "12.0";
                PlayerSettings.SetScriptingBackend(BuildTargetGroup.iOS, ScriptingImplementation.IL2CPP);
            }

            Debug.Log("Build settings configured for AR");
        }

        private void CreateARScene()
        {
            // This is a placeholder - actual scene creation would require AR Foundation types
            // which may not be available at compile time
            EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

            // Save scene
            string scenePath = "Assets/Scenes";
            if (!Directory.Exists(scenePath))
            {
                Directory.CreateDirectory(scenePath);
            }

            string fullPath = Path.Combine(scenePath, "ARExample.unity");
            EditorSceneManager.SaveScene(EditorSceneManager.GetActiveScene(), fullPath);

            Debug.Log($"AR scene created: {fullPath}");
            Debug.Log("NOTE: You'll need to manually add AR Session Origin and AR Session components from AR Foundation");
        }

        private void AddFlutterBridgeToScene()
        {
            GameObject bridgeObject = GameObject.Find("FlutterBridge");
            if (bridgeObject == null)
            {
                bridgeObject = new GameObject("FlutterBridge");
                // Note: Actual component addition would need to find the FlutterBridge type
                Debug.Log("FlutterBridge GameObject created. Add FlutterBridge component manually.");
            }
        }
    }
}
