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
    /// that are ready to integrate with the GameFramework.
    /// </summary>
    public class FlutterExporter : EditorWindow
    {
        private string exportPath = "";
        private bool exportAndroid = true;
        private bool exportIOS = true;
        private bool exportMacOS = true;
        private bool developmentBuild = false;
        private bool autoRunBuilder = false;

        [MenuItem("Game Framework/Export Unity Project")]
        public static void ShowWindow()
        {
            GetWindow<FlutterExporter>("Game Framework Exporter");
        }

        void OnGUI()
        {
            GUILayout.Label("GameFramework Exporter", EditorStyles.boldLabel);
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
            exportMacOS = EditorGUILayout.Toggle("Export macOS", exportMacOS);

            GUILayout.Space(10);

            // Build options
            GUILayout.Label("Build Options", EditorStyles.boldLabel);
            developmentBuild = EditorGUILayout.Toggle("Development Build", developmentBuild);
            autoRunBuilder = EditorGUILayout.Toggle("Auto-run Builder", autoRunBuilder);

            GUILayout.Space(20);

            // Export button
            GUI.enabled = !string.IsNullOrEmpty(exportPath) && (exportAndroid || exportIOS || exportMacOS);
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
            if (GUILayout.Button("Export macOS Only"))
            {
                QuickExportMacOS();
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

                if (exportMacOS)
                {
                    Debug.Log("Exporting macOS...");
                    ExportMacOS(Path.Combine(exportPath, "macos"));
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

        private void QuickExportMacOS()
        {
            string path = EditorUtility.SaveFolderPanel("Select macOS Export Folder", "", "macos");
            if (!string.IsNullOrEmpty(path))
            {
                ExportMacOS(path);
                EditorUtility.DisplayDialog("Success",
                    "macOS export completed!\n\nExported to: " + path,
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
                    
                    // CRITICAL: Fix AndroidManifest for embedded mode
                    FixAndroidManifestForEmbedding(Path.Combine(path, "unityLibrary"));
                    
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

        /// <summary>
        /// Export macOS build for Flutter integration.
        /// Attempts IL2CPP + Xcode project; falls back to .app if not available.
        /// </summary>
        public static void ExportMacOS(string path)
        {
            if (!Directory.Exists(path))
            {
                Directory.CreateDirectory(path);
            }

            BuildTarget previousTarget = EditorUserBuildSettings.activeBuildTarget;
            BuildTargetGroup previousGroup = BuildPipeline.GetBuildTargetGroup(previousTarget);

            try
            {
                EditorUserBuildSettings.SwitchActiveBuildTarget(
                    BuildTargetGroup.Standalone,
                    BuildTarget.StandaloneOSX
                );

                // Try IL2CPP + Xcode project
                PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone, ScriptingImplementation.IL2CPP);
                try { EditorUserBuildSettings.SetPlatformSettings("OSXUniversal", "CreateXcodeProject", "true"); }
                catch (System.Exception) { /* May not work in Unity 6 Build Profiles */ }

                // Determine output: Xcode project or .app
                var activeBackend = PlayerSettings.GetScriptingBackend(BuildTargetGroup.Standalone);
                string locationPath = (activeBackend == ScriptingImplementation.IL2CPP)
                    ? path
                    : System.IO.Path.Combine(path, PlayerSettings.productName + ".app");

                BuildPlayerOptions buildOptions = new BuildPlayerOptions
                {
                    scenes = GetScenePaths(),
                    locationPathName = locationPath,
                    target = BuildTarget.StandaloneOSX,
                    options = BuildOptions.None
                };

                if (EditorUserBuildSettings.development)
                {
                    buildOptions.options |= BuildOptions.Development;
                }

                var report = BuildPipeline.BuildPlayer(buildOptions);

                if (report.summary.result == UnityEditor.Build.Reporting.BuildResult.Succeeded)
                {
                    Debug.Log("macOS export succeeded: " + path);
                    CreateMacOSReadme(path);
                }
                else
                {
                    throw new Exception("macOS build failed: " + report.summary.result);
                }
            }
            finally
            {
                EditorUserBuildSettings.SwitchActiveBuildTarget(previousGroup, previousTarget);
            }
        }

        private static void ConfigureAndroidSettings()
        {
            // Set Android settings for Flutter integration
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel25;
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
            PlayerSettings.iOS.targetOSVersionString = "15.0";

            // Scripting backend
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.iOS, ScriptingImplementation.IL2CPP);

            // Architecture
            PlayerSettings.iOS.sdkVersion = iOSSdkVersion.DeviceSDK;

            Debug.Log("iOS settings configured for Flutter integration");
        }

        private static void ConfigureMacOSSettings()
        {
            // Scripting backend
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone, ScriptingImplementation.IL2CPP);
            // macOS build number
            PlayerSettings.macOS.buildNumber = PlayerSettings.bundleVersion;
            Debug.Log("macOS settings configured for Flutter integration");
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

For more information, see the GameFramework documentation.
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
3. Ensure your iOS deployment target is at least 15.0
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

For more information, see the GameFramework documentation.
";

            File.WriteAllText(Path.Combine(path, "README.md"), readme);
        }

        private static void CreateMacOSReadme(string path)
        {
            string readme = @"# macOS Unity Export for Flutter

This folder contains the Unity macOS export (Xcode project) for Flutter integration.

## Integration Steps

1. Build UnityFramework from the Xcode project (or use game-cli: `game export unity -p macos` which runs xcodebuild for you).
2. Copy the built `UnityFramework.framework` to your Flutter project's macos folder (or run `game sync unity --platform macos`).
3. The podspec will link the framework. Ensure macOS deployment target is at least 10.15.
4. Run `flutter pub get` and rebuild your Flutter app for macOS.

## Building the framework manually

From this directory:
```bash
xcodebuild archive -project <YourProject>.xcodeproj \
  -scheme UnityFramework -configuration Release \
  -destination ""generic/platform=macOS"" \
  -archivePath ./macos.xcarchive \
  MACOSX_DEPLOYMENT_TARGET=10.15 \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO
```
The framework will be in `macos.xcarchive/Products/Library/Frameworks/UnityFramework.framework`.

## Troubleshooting

- If you get code signing errors, check your team settings in Xcode
- If the framework is not found, verify FRAMEWORK_SEARCH_PATHS in the plugin podspec

For more information, see the GameFramework documentation.
";
            File.WriteAllText(Path.Combine(path, "README.md"), readme);
        }

        [MenuItem("Game Framework/Quick Export Android")]
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

        [MenuItem("Game Framework/Quick Export iOS")]
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

        [MenuItem("Game Framework/Quick Export macOS")]
        public static void QuickExportMacOSMenu()
        {
            string path = EditorUtility.SaveFolderPanel("Select macOS Export Folder", "", "macos");
            if (!string.IsNullOrEmpty(path))
            {
                ExportMacOS(path);
                EditorUtility.DisplayDialog("Success",
                    "macOS export completed!\n\nExported to: " + path,
                    "OK");
                EditorUtility.RevealInFinder(path);
            }
        }

        /// <summary>
        /// Fix AndroidManifest.xml for embedded mode (remove launcher intent)
        /// CRITICAL: Unity exports with LAUNCHER intent by default, which makes it
        /// launch as a standalone app instead of embedding in Flutter
        /// </summary>
        private static void FixAndroidManifestForEmbedding(string unityLibraryPath)
        {
            string manifestPath = Path.Combine(unityLibraryPath, "src", "main", "AndroidManifest.xml");
            
            if (!File.Exists(manifestPath))
            {
                Debug.LogWarning($"AndroidManifest.xml not found at {manifestPath}");
                return;
            }

            try
            {
                string manifest = File.ReadAllText(manifestPath);
                string originalManifest = manifest;

                // Remove the launcher intent-filter that causes Unity to launch as standalone app
                // This is the MOST CRITICAL fix for embedded mode
                int intentFilterStart = manifest.IndexOf("<intent-filter>");
                while (intentFilterStart >= 0)
                {
                    int intentFilterEnd = manifest.IndexOf("</intent-filter>", intentFilterStart);
                    if (intentFilterEnd >= 0)
                    {
                        string intentFilterBlock = manifest.Substring(
                            intentFilterStart, 
                            intentFilterEnd - intentFilterStart + "</intent-filter>".Length
                        );

                        // Check if this intent-filter contains LAUNCHER
                        if (intentFilterBlock.Contains("android.intent.category.LAUNCHER") || 
                            intentFilterBlock.Contains("android.intent.action.MAIN"))
                        {
                            // Remove this intent-filter
                            manifest = manifest.Remove(intentFilterStart, intentFilterEnd - intentFilterStart + "</intent-filter>".Length);
                            Debug.Log("✅ Removed LAUNCHER intent-filter from AndroidManifest.xml");
                            break;
                        }
                    }
                    intentFilterStart = manifest.IndexOf("<intent-filter>", intentFilterStart + 1);
                }

                // Also ensure exported="false" on UnityPlayerActivity
                manifest = manifest.Replace(
                    "android:exported=\"true\"",
                    "android:exported=\"false\""
                );

                // Change launchMode from singleTask to standard for better embedding
                manifest = manifest.Replace(
                    "android:launchMode=\"singleTask\"",
                    "android:launchMode=\"standard\""
                );

                // Enable hardware acceleration for better performance
                manifest = manifest.Replace(
                    "android:hardwareAccelerated=\"false\"",
                    "android:hardwareAccelerated=\"true\""
                );

                if (manifest != originalManifest)
                {
                    // Backup original
                    File.WriteAllText(manifestPath + ".backup", originalManifest);
                    
                    // Write fixed manifest
                    File.WriteAllText(manifestPath, manifest);
                    
                    Debug.Log("✅ AndroidManifest.xml fixed for embedded mode");
                    Debug.Log("   - Removed LAUNCHER intent-filter");
                    Debug.Log("   - Set exported=false");
                    Debug.Log("   - Changed launchMode to standard");
                    Debug.Log($"   - Backup saved to: {manifestPath}.backup");
                }
                else
                {
                    Debug.Log("ℹ️ AndroidManifest.xml already configured for embedded mode");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to fix AndroidManifest.xml: {e.Message}");
                Debug.LogError("You may need to manually remove the LAUNCHER intent-filter");
            }
        }
    }
}
