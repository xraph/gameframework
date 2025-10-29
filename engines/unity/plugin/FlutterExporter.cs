using System;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Unity editor tool for exporting projects for Flutter integration
    ///
    /// This provides menu items and automation for exporting Unity builds
    /// that are ready to integrate with the Flutter Game Framework.
    /// </summary>
    public class FlutterExporter : EditorWindow
    {
        private string exportPath = "";
        private bool exportAndroid = true;
        private bool exportIOS = true;
        private bool developmentBuild = false;
        private bool autoRunBuilder = false;

        [MenuItem("Flutter/Export for Flutter")]
        public static void ShowWindow()
        {
            GetWindow<FlutterExporter>("Flutter Exporter");
        }

        void OnGUI()
        {
            GUILayout.Label("Flutter Game Framework Exporter", EditorStyles.boldLabel);
            GUILayout.Space(10);

            // Export path
            GUILayout.Label("Export Settings", EditorStyles.boldLabel);
            GUILayout.BeginHorizontal();
            exportPath = EditorGUILayout.TextField("Export Path:", exportPath);
            if (GUILayout.Button("Browse", GUILayout.Width(80)))
            {
                string path = EditorUtility.OpenFolderPanel("Select Export Folder", exportPath, "");
                if (!string.IsNullOrEmpty(path))
                {
                    exportPath = path;
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.Space(10);

            // Platform selection
            GUILayout.Label("Platforms", EditorStyles.boldLabel);
            exportAndroid = EditorGUILayout.Toggle("Export Android", exportAndroid);
            exportIOS = EditorGUILayout.Toggle("Export iOS", exportIOS);

            GUILayout.Space(10);

            // Build options
            GUILayout.Label("Build Options", EditorStyles.boldLabel);
            developmentBuild = EditorGUILayout.Toggle("Development Build", developmentBuild);
            autoRunBuilder = EditorGUILayout.Toggle("Auto-run Builder", autoRunBuilder);

            GUILayout.Space(20);

            // Export button
            GUI.enabled = !string.IsNullOrEmpty(exportPath) && (exportAndroid || exportIOS);
            if (GUILayout.Button("Export for Flutter", GUILayout.Height(40)))
            {
                Export();
            }
            GUI.enabled = true;

            GUILayout.Space(10);

            // Quick export buttons
            GUILayout.Label("Quick Actions", EditorStyles.boldLabel);
            if (GUILayout.Button("Export Android Only"))
            {
                QuickExportAndroid();
            }
            if (GUILayout.Button("Export iOS Only"))
            {
                QuickExportIOS();
            }
        }

        private void Export()
        {
            if (string.IsNullOrEmpty(exportPath))
            {
                EditorUtility.DisplayDialog("Error", "Please select an export path", "OK");
                return;
            }

            if (!Directory.Exists(exportPath))
            {
                Directory.CreateDirectory(exportPath);
            }

            try
            {
                if (exportAndroid)
                {
                    Debug.Log("Exporting Android...");
                    ExportAndroid(Path.Combine(exportPath, "android"));
                }

                if (exportIOS)
                {
                    Debug.Log("Exporting iOS...");
                    ExportIOS(Path.Combine(exportPath, "ios"));
                }

                EditorUtility.DisplayDialog("Success",
                    "Export completed successfully!\n\nExported to: " + exportPath,
                    "OK");

                // Open the folder
                EditorUtility.RevealInFinder(exportPath);
            }
            catch (Exception e)
            {
                EditorUtility.DisplayDialog("Error",
                    "Export failed: " + e.Message,
                    "OK");
                Debug.LogError("Export failed: " + e);
            }
        }

        private void QuickExportAndroid()
        {
            string path = EditorUtility.SaveFolderPanel("Select Android Export Folder", "", "android");
            if (!string.IsNullOrEmpty(path))
            {
                ExportAndroid(path);
                EditorUtility.DisplayDialog("Success",
                    "Android export completed!\n\nExported to: " + path,
                    "OK");
            }
        }

        private void QuickExportIOS()
        {
            string path = EditorUtility.SaveFolderPanel("Select iOS Export Folder", "", "ios");
            if (!string.IsNullOrEmpty(path))
            {
                ExportIOS(path);
                EditorUtility.DisplayDialog("Success",
                    "iOS export completed!\n\nExported to: " + path,
                    "OK");
            }
        }

        /// <summary>
        /// Export Android build for Flutter integration
        /// </summary>
        public static void ExportAndroid(string path)
        {
            if (!Directory.Exists(path))
            {
                Directory.CreateDirectory(path);
            }

            // Save current build target
            BuildTarget previousTarget = EditorUserBuildSettings.activeBuildTarget;
            BuildTargetGroup previousGroup = BuildPipeline.GetBuildTargetGroup(previousTarget);

            try
            {
                // Switch to Android
                EditorUserBuildSettings.SwitchActiveBuildTarget(
                    BuildTargetGroup.Android,
                    BuildTarget.Android
                );

                // Configure Android settings for Flutter integration
                ConfigureAndroidSettings();

                // Build options
                BuildPlayerOptions buildOptions = new BuildPlayerOptions
                {
                    scenes = GetScenePaths(),
                    locationPathName = Path.Combine(path, "unityLibrary"),
                    target = BuildTarget.Android,
                    options = BuildOptions.None
                };

                if (EditorUserBuildSettings.development)
                {
                    buildOptions.options |= BuildOptions.Development;
                }

                // Export as Gradle project
                EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

                // Build
                var report = BuildPipeline.BuildPlayer(buildOptions);

                if (report.summary.result == UnityEditor.Build.Reporting.BuildResult.Succeeded)
                {
                    Debug.Log("Android export succeeded: " + path);
                    CreateAndroidReadme(path);
                }
                else
                {
                    throw new Exception("Android build failed: " + report.summary.result);
                }
            }
            finally
            {
                // Restore build target
                EditorUserBuildSettings.SwitchActiveBuildTarget(previousGroup, previousTarget);
            }
        }

        /// <summary>
        /// Export iOS build for Flutter integration
        /// </summary>
        public static void ExportIOS(string path)
        {
            if (!Directory.Exists(path))
            {
                Directory.CreateDirectory(path);
            }

            // Save current build target
            BuildTarget previousTarget = EditorUserBuildSettings.activeBuildTarget;
            BuildTargetGroup previousGroup = BuildPipeline.GetBuildTargetGroup(previousTarget);

            try
            {
                // Switch to iOS
                EditorUserBuildSettings.SwitchActiveBuildTarget(
                    BuildTargetGroup.iOS,
                    BuildTarget.iOS
                );

                // Configure iOS settings for Flutter integration
                ConfigureIOSSettings();

                // Build options
                BuildPlayerOptions buildOptions = new BuildPlayerOptions
                {
                    scenes = GetScenePaths(),
                    locationPathName = path,
                    target = BuildTarget.iOS,
                    options = BuildOptions.None
                };

                if (EditorUserBuildSettings.development)
                {
                    buildOptions.options |= BuildOptions.Development;
                }

                // Build
                var report = BuildPipeline.BuildPlayer(buildOptions);

                if (report.summary.result == UnityEditor.Build.Reporting.BuildResult.Succeeded)
                {
                    Debug.Log("iOS export succeeded: " + path);
                    CreateIOSReadme(path);
                }
                else
                {
                    throw new Exception("iOS build failed: " + report.summary.result);
                }
            }
            finally
            {
                // Restore build target
                EditorUserBuildSettings.SwitchActiveBuildTarget(previousGroup, previousTarget);
            }
        }

        private static void ConfigureAndroidSettings()
        {
            // Set Android settings for Flutter integration
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel22;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevel33;

            // Scripting backend
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);

            // Target architectures
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64 | AndroidArchitecture.ARMv7;

            Debug.Log("Android settings configured for Flutter integration");
        }

        private static void ConfigureIOSSettings()
        {
            // Set iOS settings for Flutter integration
            PlayerSettings.iOS.targetOSVersionString = "12.0";

            // Scripting backend
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.iOS, ScriptingImplementation.IL2CPP);

            // Architecture
            PlayerSettings.iOS.sdkVersion = iOSSdkVersion.DeviceSDK;

            Debug.Log("iOS settings configured for Flutter integration");
        }

        private static string[] GetScenePaths()
        {
            string[] scenes = new string[EditorBuildSettings.scenes.Length];
            for (int i = 0; i < scenes.Length; i++)
            {
                scenes[i] = EditorBuildSettings.scenes[i].path;
            }
            return scenes;
        }

        private static void CreateAndroidReadme(string path)
        {
            string readme = @"# Android Unity Export for Flutter

This folder contains the Unity Android export for Flutter integration.

## Integration Steps

1. Copy the `unityLibrary` folder to your Flutter project's `android/` directory
2. Add the Unity library to your app's `build.gradle`:

```gradle
dependencies {
    implementation project(':unityLibrary')
}
```

3. Add to `settings.gradle`:

```gradle
include ':unityLibrary'
```

4. Ensure your app's `build.gradle` has matching SDK versions:
   - minSdkVersion: 21
   - targetSdkVersion: 33

5. Run `flutter pub get` and rebuild your Flutter app

## Troubleshooting

- If you get NDK errors, ensure you have NDK installed in Android Studio
- If you get duplicate class errors, check for conflicting dependencies
- Check that all .so files are included in the build

For more information, see the Flutter Game Framework documentation.
";

            File.WriteAllText(Path.Combine(path, "README.md"), readme);
        }

        private static void CreateIOSReadme(string path)
        {
            string readme = @"# iOS Unity Export for Flutter

This folder contains the Unity iOS export for Flutter integration.

## Integration Steps

1. Copy the `UnityFramework.framework` from this export to your Flutter project's iOS folder
2. The podspec will automatically link the framework
3. Ensure your iOS deployment target is at least 12.0
4. Run `flutter pub get` and `pod install` in the ios folder
5. Rebuild your Flutter app

## Xcode Configuration

If you open the project in Xcode:
1. Select your target
2. Go to General > Frameworks, Libraries, and Embedded Content
3. Ensure UnityFramework.framework is set to 'Embed & Sign'

## Troubleshooting

- If you get code signing errors, check your team settings in Xcode
- If the framework is not found, verify the search paths
- Ensure the framework is for the correct architecture (device vs simulator)

For more information, see the Flutter Game Framework documentation.
";

            File.WriteAllText(Path.Combine(path, "README.md"), readme);
        }

        [MenuItem("Flutter/Quick Export Android")]
        public static void QuickExportAndroidMenu()
        {
            string path = EditorUtility.SaveFolderPanel("Select Android Export Folder", "", "android");
            if (!string.IsNullOrEmpty(path))
            {
                ExportAndroid(path);
                EditorUtility.DisplayDialog("Success",
                    "Android export completed!\n\nExported to: " + path,
                    "OK");
                EditorUtility.RevealInFinder(path);
            }
        }

        [MenuItem("Flutter/Quick Export iOS")]
        public static void QuickExportIOSMenu()
        {
            string path = EditorUtility.SaveFolderPanel("Select iOS Export Folder", "", "ios");
            if (!string.IsNullOrEmpty(path))
            {
                ExportIOS(path);
                EditorUtility.DisplayDialog("Success",
                    "iOS export completed!\n\nExported to: " + path,
                    "OK");
                EditorUtility.RevealInFinder(path);
            }
        }
    }
}
