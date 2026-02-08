using UnityEditor;
using UnityEngine;
using System;
using System.IO;
using System.Linq;
using UnityEditor.Build.Reporting;

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Unity Editor build script for GameFramework CLI
    /// This script is called by the game CLI to automate Unity builds
    /// </summary>
    public static class FlutterBuildScript
    {
        private static string GetBuildPath()
        {
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "-buildPath" && i + 1 < args.Length)
                {
                    return args[i + 1];
                }
            }
            return "./Build";
        }

        private static bool IsDevelopmentBuild()
        {
            string[] args = Environment.GetCommandLineArgs();
            return args.Contains("-development");
        }

        private static string[] GetScenes()
        {
            // Check if scenes were specified via command line
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "-buildScenes" && i + 1 < args.Length)
                {
                    // Parse comma-separated scene names
                    string scenesArg = args[i + 1];
                    string[] sceneNames = scenesArg.Split(',');

                    // Convert scene names to full paths
                    var scenePaths = new System.Collections.Generic.List<string>();
                    foreach (var sceneName in sceneNames)
                    {
                        // Try to find the scene by name in Assets folder
                        string[] foundScenes = AssetDatabase.FindAssets($"{sceneName.Trim()} t:Scene");
                        if (foundScenes.Length > 0)
                        {
                            string scenePath = AssetDatabase.GUIDToAssetPath(foundScenes[0]);
                            scenePaths.Add(scenePath);
                            Debug.Log($"Found scene: {sceneName} at {scenePath}");
                        }
                        else
                        {
                            Debug.LogWarning($"Scene not found: {sceneName}");
                        }
                    }

                    if (scenePaths.Count > 0)
                    {
                        return scenePaths.ToArray();
                    }
                }
            }

            // Fall back to all enabled scenes from build settings
            return EditorBuildSettings.scenes
                .Where(scene => scene.enabled)
                .Select(scene => scene.path)
                .ToArray();
        }

        private static string GetBuildConfiguration()
        {
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "-buildConfiguration" && i + 1 < args.Length)
                {
                    return args[i + 1];
                }
            }
            return "Release"; // Default
        }

        /// <summary>
        /// Build for Android - exports as Gradle project
        /// </summary>
        [MenuItem("Game Framework/Build Android")]
        public static void BuildAndroid()
        {
            Debug.Log("Starting Android build for Flutter...");

            string buildPath = GetBuildPath();
            bool isDevelopment = IsDevelopmentBuild();
            string buildConfiguration = GetBuildConfiguration();

            // Ensure build path exists
            if (!Directory.Exists(buildPath))
            {
                Directory.CreateDirectory(buildPath);
            }

            // Configure build options
            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = GetScenes(),
                locationPathName = buildPath,
                target = BuildTarget.Android,
                options = BuildOptions.None
            };

            // Add development flag if specified
            if (isDevelopment)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            // Export as Gradle project for Flutter integration
            EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

            Debug.Log($"Building to: {buildPath}");
            Debug.Log($"Development: {isDevelopment}");
            Debug.Log($"Build Configuration: {buildConfiguration}");
            Debug.Log($"Scenes: {string.Join(", ", buildPlayerOptions.scenes)}");

            BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"Android build succeeded: {summary.totalSize} bytes");
                Debug.Log($"Output: {buildPath}");
                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"Android build failed: {summary.result}");
                EditorApplication.Exit(1);
            }
        }

        /// <summary>
        /// Build for iOS - exports as Xcode project
        /// </summary>
        [MenuItem("Game Framework/Build iOS")]
        public static void BuildIos()
        {
            Debug.Log("Starting iOS build for Flutter...");

            string buildPath = GetBuildPath();
            bool isDevelopment = IsDevelopmentBuild();

            if (!Directory.Exists(buildPath))
            {
                Directory.CreateDirectory(buildPath);
            }

            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = GetScenes(),
                locationPathName = buildPath,
                target = BuildTarget.iOS,
                options = BuildOptions.None
            };

            if (isDevelopment)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            Debug.Log($"Building to: {buildPath}");
            Debug.Log($"Development: {isDevelopment}");

            BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"iOS build succeeded: {summary.totalSize} bytes");
                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"iOS build failed: {summary.result}");
                EditorApplication.Exit(1);
            }
        }

        /// <summary>
        /// Build for macOS
        /// </summary>
        [MenuItem("Game Framework/Build macOS")]
        public static void BuildMacos()
        {
            Debug.Log("Starting macOS build for Flutter...");

            string buildPath = GetBuildPath();
            bool isDevelopment = IsDevelopmentBuild();

            if (!Directory.Exists(buildPath))
            {
                Directory.CreateDirectory(buildPath);
            }

            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = GetScenes(),
                locationPathName = Path.Combine(buildPath, "UnityGame.app"),
                target = BuildTarget.StandaloneOSX,
                options = BuildOptions.None
            };

            if (isDevelopment)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            Debug.Log($"Building to: {buildPath}");

            BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"macOS build succeeded: {summary.totalSize} bytes");
                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"macOS build failed: {summary.result}");
                EditorApplication.Exit(1);
            }
        }

        /// <summary>
        /// Build for Windows
        /// </summary>
        [MenuItem("Game Framework/Build Windows")]
        public static void BuildWindows()
        {
            Debug.Log("Starting Windows build for Flutter...");

            string buildPath = GetBuildPath();
            bool isDevelopment = IsDevelopmentBuild();

            if (!Directory.Exists(buildPath))
            {
                Directory.CreateDirectory(buildPath);
            }

            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = GetScenes(),
                locationPathName = Path.Combine(buildPath, "UnityGame.exe"),
                target = BuildTarget.StandaloneWindows64,
                options = BuildOptions.None
            };

            if (isDevelopment)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            Debug.Log($"Building to: {buildPath}");

            BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"Windows build succeeded: {summary.totalSize} bytes");
                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"Windows build failed: {summary.result}");
                EditorApplication.Exit(1);
            }
        }

        /// <summary>
        /// Build for Linux
        /// </summary>
        [MenuItem("Game Framework/Build Linux")]
        public static void BuildLinux()
        {
            Debug.Log("Starting Linux build for Flutter...");

            string buildPath = GetBuildPath();
            bool isDevelopment = IsDevelopmentBuild();

            if (!Directory.Exists(buildPath))
            {
                Directory.CreateDirectory(buildPath);
            }

            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = GetScenes(),
                locationPathName = Path.Combine(buildPath, "UnityGame"),
                target = BuildTarget.StandaloneLinux64,
                options = BuildOptions.None
            };

            if (isDevelopment)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            Debug.Log($"Building to: {buildPath}");

            BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"Linux build succeeded: {summary.totalSize} bytes");
                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"Linux build failed: {summary.result}");
                EditorApplication.Exit(1);
            }
        }

        /// <summary>
        /// Validate build configuration
        /// </summary>
        [MenuItem("Game Framework/Validate Build Settings")]
        public static void ValidateBuildSettings()
        {
            Debug.Log("Validating Unity build settings for Flutter...");

            var scenes = GetScenes();
            if (scenes.Length == 0)
            {
                Debug.LogError("No scenes enabled in Build Settings!");
            }
            else
            {
                Debug.Log($"Found {scenes.Length} enabled scenes:");
                foreach (var scene in scenes)
                {
                    Debug.Log($"  - {scene}");
                }
            }

            // Android checks
            Debug.Log($"Android Build System: {EditorUserBuildSettings.androidBuildSystem}");
            Debug.Log($"Export as Gradle: {EditorUserBuildSettings.exportAsGoogleAndroidProject}");

            Debug.Log("Validation complete!");
        }
    }
}
