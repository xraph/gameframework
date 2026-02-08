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
        
        /// <summary>
        /// Check if streaming/addressables build is enabled
        /// </summary>
        private static bool IsStreamingEnabled()
        {
            string[] args = Environment.GetCommandLineArgs();
            return args.Contains("-enableStreaming");
        }
        
        /// <summary>
        /// Build addressables if streaming is enabled
        /// </summary>
        private static bool BuildAddressablesIfEnabled(BuildTarget target)
        {
            if (!IsStreamingEnabled())
            {
                return true; // Not enabled, skip
            }
            
#if ADDRESSABLES_INSTALLED
            Debug.Log("Streaming enabled - building Addressables first...");
            return FlutterAddressablesBuildScript.BuildAddressablesForPlatform(target);
#else
            Debug.LogWarning("Streaming is enabled but Addressables package is not installed. Skipping Addressables build.");
            return true;
#endif
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
            bool streamingEnabled = IsStreamingEnabled();

            // Build addressables first if streaming is enabled
            if (streamingEnabled)
            {
                if (!BuildAddressablesIfEnabled(BuildTarget.Android))
                {
                    Debug.LogError("Addressables build failed, aborting Android build");
                    EditorApplication.Exit(1);
                    return;
                }
            }

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
            Debug.Log($"Streaming Enabled: {streamingEnabled}");
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
            bool streamingEnabled = IsStreamingEnabled();

            // Build addressables first if streaming is enabled
            if (streamingEnabled)
            {
                if (!BuildAddressablesIfEnabled(BuildTarget.iOS))
                {
                    Debug.LogError("Addressables build failed, aborting iOS build");
                    EditorApplication.Exit(1);
                    return;
                }
            }

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
            Debug.Log($"Streaming Enabled: {streamingEnabled}");

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
        /// Build for WebGL - exports Unity WebGL build for Flutter Web
        /// </summary>
        [MenuItem("Game Framework/Build WebGL")]
        public static void BuildWebGL()
        {
            Debug.Log("Starting WebGL build for Flutter Web...");

            string buildPath = GetBuildPath();
            bool isDevelopment = IsDevelopmentBuild();
            bool streamingEnabled = IsStreamingEnabled();

            // Build addressables first if streaming is enabled
            if (streamingEnabled)
            {
                if (!BuildAddressablesIfEnabled(BuildTarget.WebGL))
                {
                    Debug.LogError("Addressables build failed, aborting WebGL build");
                    EditorApplication.Exit(1);
                    return;
                }
            }

            if (!Directory.Exists(buildPath))
            {
                Directory.CreateDirectory(buildPath);
            }

            // Configure WebGL-specific settings for optimal web delivery
            ConfigureWebGLSettings(isDevelopment);

            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = GetScenes(),
                locationPathName = buildPath,
                target = BuildTarget.WebGL,
                options = BuildOptions.None
            };

            if (isDevelopment)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            Debug.Log($"Building to: {buildPath}");
            Debug.Log($"Development: {isDevelopment}");
            Debug.Log($"Streaming Enabled: {streamingEnabled}");
            Debug.Log($"Scenes: {string.Join(", ", buildPlayerOptions.scenes)}");

            BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"WebGL build succeeded: {summary.totalSize} bytes");
                Debug.Log($"Output: {buildPath}");
                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"WebGL build failed: {summary.result}");
                EditorApplication.Exit(1);
            }
        }

        /// <summary>
        /// Configure WebGL-specific player settings for optimal web delivery
        /// </summary>
        private static void ConfigureWebGLSettings(bool isDevelopment)
        {
            // Use Brotli compression for smaller builds (best for web)
            // Development builds use disabled compression for faster iteration
            PlayerSettings.WebGL.compressionFormat = isDevelopment 
                ? WebGLCompressionFormat.Disabled 
                : WebGLCompressionFormat.Brotli;

            // Use Wasm linker target (required for modern browsers)
            PlayerSettings.WebGL.linkerTarget = WebGLLinkerTarget.Wasm;

            // Disable exception handling in release for smaller builds
            if (!isDevelopment)
            {
                PlayerSettings.WebGL.exceptionSupport = WebGLExceptionSupport.None;
            }
            else
            {
                PlayerSettings.WebGL.exceptionSupport = WebGLExceptionSupport.FullWithStacktrace;
            }

            // Use IL2CPP scripting backend
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.WebGL, ScriptingImplementation.IL2CPP);

            // Set template to minimal for Flutter integration (no Unity loading bar)
            PlayerSettings.WebGL.template = "PROJECT:Minimal";

            Debug.Log("WebGL settings configured for Flutter Web integration");
            Debug.Log($"  Compression: {PlayerSettings.WebGL.compressionFormat}");
            Debug.Log($"  Linker Target: {PlayerSettings.WebGL.linkerTarget}");
            Debug.Log($"  Exceptions: {PlayerSettings.WebGL.exceptionSupport}");
        }

        /// <summary>
        /// Build for macOS - exports as Xcode project (source) only. IL2CPP is required.
        /// The game-cli builds the Xcode project and assembles UnityFramework.framework.
        /// </summary>
        [MenuItem("Game Framework/Build macOS")]
        public static void BuildMacos()
        {
            Debug.Log("Starting macOS build for Flutter...");

            string buildPath = GetBuildPath();
            bool isDevelopment = IsDevelopmentBuild();
            bool streamingEnabled = IsStreamingEnabled();

            // Build addressables first if streaming is enabled
            if (streamingEnabled)
            {
                if (!BuildAddressablesIfEnabled(BuildTarget.StandaloneOSX))
                {
                    Debug.LogError("Addressables build failed, aborting macOS build");
                    EditorApplication.Exit(1);
                    return;
                }
            }

            if (!Directory.Exists(buildPath))
            {
                Directory.CreateDirectory(buildPath);
            }

            // Configure macOS settings; require IL2CPP for Xcode project export
            bool isIL2CPP = ConfigureMacOSSettings();
            if (!isIL2CPP)
            {
                Debug.LogError("macOS build requires IL2CPP scripting backend.");
                Debug.LogError("Install Mac Build Support (IL2CPP) via Unity Hub > Installs > your version > Add Modules.");
                Debug.LogError("Then set Edit > Project Settings > Player > macOS > Other Settings > Scripting Backend to IL2CPP.");
                EditorApplication.Exit(1);
                return;
            }

            // Request Xcode project export (mirrors iOS; game-cli assembles UnityFramework from build products)
            try
            {
                EditorUserBuildSettings.SetPlatformSettings("OSXUniversal", "CreateXcodeProject", "true");
                Debug.Log("Requested Xcode project export (CreateXcodeProject=true)");
            }
            catch (System.Exception e)
            {
                Debug.LogWarning($"SetPlatformSettings failed (Unity 6 Build Profiles may override): {e.Message}");
            }

            // Always export to build path as Xcode project directory
            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = GetScenes(),
                locationPathName = buildPath,
                target = BuildTarget.StandaloneOSX,
                options = BuildOptions.None
            };

            if (isDevelopment)
            {
                buildPlayerOptions.options |= BuildOptions.Development;
            }

            Debug.Log($"Building to: {buildPath}");
            Debug.Log($"Development: {isDevelopment}");
            Debug.Log($"Streaming Enabled: {streamingEnabled}");

            BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"macOS build succeeded: {summary.totalSize} bytes");

                // Verify Xcode project was produced; fail if not
                bool hasXcodeProj = false;
                foreach (string dir in Directory.GetDirectories(buildPath))
                {
                    if (dir.EndsWith(".xcodeproj"))
                    {
                        hasXcodeProj = true;
                        Debug.Log($"Xcode project found: {dir}");
                        break;
                    }
                }

                if (!hasXcodeProj)
                {
                    Debug.LogError("Build did not produce an Xcode project. A .app bundle was produced instead.");
                    Debug.LogError("Enable 'Create Xcode Project' in Build Profiles (Edit > Project Settings > Build) for macOS.");
                    Debug.LogError("Then re-run the build.");
                    EditorApplication.Exit(1);
                    return;
                }

                EditorApplication.Exit(0);
            }
            else
            {
                Debug.LogError($"macOS build failed: {summary.result}");
                EditorApplication.Exit(1);
            }
        }

        /// <summary>
        /// Configure macOS player settings for Flutter integration.
        /// Returns true if IL2CPP scripting backend is active after configuration.
        /// </summary>
        private static bool ConfigureMacOSSettings()
        {
            // Try to use IL2CPP scripting backend for macOS (required for UnityFramework)
            try
            {
                PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone, ScriptingImplementation.IL2CPP);
                Debug.Log("Set scripting backend to IL2CPP");
            }
            catch (System.Exception e)
            {
                Debug.LogWarning($"Could not set IL2CPP backend: {e.Message}");
                Debug.LogWarning("IL2CPP module may not be installed. Install it via Unity Hub > Installs > Add Modules.");
            }

            // Verify what backend is actually active
            var activeBackend = PlayerSettings.GetScriptingBackend(BuildTargetGroup.Standalone);
            bool isIL2CPP = activeBackend == ScriptingImplementation.IL2CPP;

            if (!isIL2CPP)
            {
                Debug.LogWarning($"Active scripting backend is {activeBackend}, not IL2CPP.");
                Debug.LogWarning("UnityFramework.framework requires IL2CPP. The build will produce a .app bundle.");
                Debug.LogWarning("To fix: Install IL2CPP module via Unity Hub, or set IL2CPP in Project Settings > Player > macOS > Other Settings.");
            }

            // Set macOS build number
            PlayerSettings.macOS.buildNumber = PlayerSettings.bundleVersion;

            Debug.Log($"macOS settings configured (backend: {activeBackend})");
            return isIL2CPP;
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
            bool streamingEnabled = IsStreamingEnabled();

            // Build addressables first if streaming is enabled
            if (streamingEnabled)
            {
                if (!BuildAddressablesIfEnabled(BuildTarget.StandaloneWindows64))
                {
                    Debug.LogError("Addressables build failed, aborting Windows build");
                    EditorApplication.Exit(1);
                    return;
                }
            }

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
            Debug.Log($"Streaming Enabled: {streamingEnabled}");

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
            bool streamingEnabled = IsStreamingEnabled();

            // Build addressables first if streaming is enabled
            if (streamingEnabled)
            {
                if (!BuildAddressablesIfEnabled(BuildTarget.StandaloneLinux64))
                {
                    Debug.LogError("Addressables build failed, aborting Linux build");
                    EditorApplication.Exit(1);
                    return;
                }
            }

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
            Debug.Log($"Streaming Enabled: {streamingEnabled}");

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
