using UnityEngine;
using UnityEditor;
using UnityEditor.Build.Reporting;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;

#if ADDRESSABLES_INSTALLED
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor.AddressableAssets.Build;
using UnityEditor.AddressableAssets.Settings.GroupSchemas;
#endif

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Build script for Addressables integration with Flutter Game Framework.
    /// Handles building addressables separately and generating manifests.
    /// </summary>
    public static class FlutterAddressablesBuildScript
    {
        private const string STREAMING_CONFIG_PATH = "Assets/GameFramework/StreamingConfig.asset";
        private const string MANIFEST_FILENAME = "streaming_manifest.json";
        
        /// <summary>
        /// Check if streaming is enabled via command line
        /// </summary>
        public static bool IsStreamingEnabled()
        {
            string[] args = Environment.GetCommandLineArgs();
            return args.Contains("-enableStreaming");
        }
        
        /// <summary>
        /// Get the streaming output path from command line or use default
        /// </summary>
        public static string GetStreamingOutputPath()
        {
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "-streamingOutputPath" && i + 1 < args.Length)
                {
                    return args[i + 1];
                }
            }
            return Path.Combine(Application.dataPath, "..", "ServerData");
        }
        
        /// <summary>
        /// Build Addressables for the specified platform
        /// </summary>
        [MenuItem("Game Framework/Streaming/Build Addressables", priority = 120)]
        public static void BuildAddressables()
        {
            BuildAddressablesForPlatform(EditorUserBuildSettings.activeBuildTarget);
        }
        
        /// <summary>
        /// Build Addressables for a specific platform
        /// </summary>
        public static bool BuildAddressablesForPlatform(BuildTarget target)
        {
#if !ADDRESSABLES_INSTALLED
            Debug.LogError("Addressables package not installed. Run 'Setup Addressables' first.");
            return false;
#else
            Debug.Log($"Building Addressables for {target}...");
            
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                Debug.LogError("AddressableAssetSettings not found. Run 'Setup Addressables' first.");
                return false;
            }
            
            try
            {
                // 1. Clean previous build
                CleanAddressablesBuild(target);
                
                // 2. Build addressable content
                AddressableAssetSettings.CleanPlayerContent(settings.ActivePlayerDataBuilder);
                AddressableAssetSettings.BuildPlayerContent(out AddressablesPlayerBuildResult result);
                
                if (!string.IsNullOrEmpty(result.Error))
                {
                    Debug.LogError($"Addressables build failed: {result.Error}");
                    return false;
                }
                
                Debug.Log($"Addressables build succeeded. Output: {result.OutputPath}");
                
                // 3. Generate manifest for Flutter
                GenerateStreamingManifest(settings, target, result);
                
                // 4. Organize bundles into base and streaming
                OrganizeBundles(settings, target);
                
                return true;
            }
            catch (Exception e)
            {
                Debug.LogError($"Addressables build failed with exception: {e.Message}\n{e.StackTrace}");
                return false;
            }
#endif
        }
        
#if ADDRESSABLES_INSTALLED
        /// <summary>
        /// Clean previous addressables build
        /// </summary>
        private static void CleanAddressablesBuild(BuildTarget target)
        {
            var outputPath = GetStreamingOutputPath();
            var platformPath = Path.Combine(outputPath, target.ToString());
            
            if (Directory.Exists(platformPath))
            {
                Debug.Log($"Cleaning previous build at: {platformPath}");
                Directory.Delete(platformPath, true);
            }
        }
        
        /// <summary>
        /// Generate streaming manifest JSON for Flutter consumption
        /// </summary>
        private static void GenerateStreamingManifest(
            AddressableAssetSettings settings, 
            BuildTarget target,
            AddressablesPlayerBuildResult buildResult)
        {
            var config = AssetDatabase.LoadAssetAtPath<FlutterStreamingConfig>(STREAMING_CONFIG_PATH);
            
            var manifest = new StreamingManifest
            {
                version = Application.version,
                buildTarget = target.ToString(),
                buildTime = DateTime.UtcNow.ToString("o"),
                bundles = new List<BundleInfo>()
            };
            
            // Scan built bundles
            var outputPath = GetStreamingOutputPath();
            var platformPath = Path.Combine(outputPath, target.ToString());
            
            if (Directory.Exists(platformPath))
            {
                var bundleFiles = Directory.GetFiles(platformPath, "*.bundle", SearchOption.AllDirectories);
                
                foreach (var bundleFile in bundleFiles)
                {
                    var fileInfo = new FileInfo(bundleFile);
                    var bundleName = Path.GetFileName(bundleFile);
                    var relativePath = bundleFile.Replace(platformPath, "").TrimStart(Path.DirectorySeparatorChar);
                    
                    // Determine if this is base or streaming content
                    var isBase = IsBundleBaseContent(settings, config, bundleName);
                    
                    var bundleInfo = new BundleInfo
                    {
                        name = bundleName,
                        path = relativePath,
                        sizeBytes = fileInfo.Length,
                        sha256 = ComputeSha256(bundleFile),
                        isBase = isBase,
                        dependencies = new List<string>()
                    };
                    
                    manifest.bundles.Add(bundleInfo);
                }
            }
            
            // Calculate totals
            manifest.totalSize = manifest.bundles.Sum(b => b.sizeBytes);
            manifest.baseSize = manifest.bundles.Where(b => b.isBase).Sum(b => b.sizeBytes);
            manifest.streamableSize = manifest.bundles.Where(b => !b.isBase).Sum(b => b.sizeBytes);
            manifest.bundleCount = manifest.bundles.Count;
            
            // Write manifest
            var manifestPath = Path.Combine(platformPath, MANIFEST_FILENAME);
            var json = JsonUtility.ToJson(manifest, true);
            File.WriteAllText(manifestPath, json);
            
            Debug.Log($"Generated streaming manifest: {manifestPath}");
            Debug.Log($"  Total bundles: {manifest.bundleCount}");
            Debug.Log($"  Base size: {FormatBytes(manifest.baseSize)}");
            Debug.Log($"  Streamable size: {FormatBytes(manifest.streamableSize)}");
        }
        
        /// <summary>
        /// Check if a bundle is base content based on its group
        /// </summary>
        private static bool IsBundleBaseContent(
            AddressableAssetSettings settings, 
            FlutterStreamingConfig config,
            string bundleName)
        {
            if (config == null) return true; // Default to base if no config
            
            // Check each group to find which one contains this bundle
            foreach (var group in settings.groups)
            {
                var schema = group.GetSchema<BundledAssetGroupSchema>();
                if (schema != null)
                {
                    var buildPath = schema.BuildPath.GetValue(settings);
                    if (buildPath.Contains("Local"))
                    {
                        // This is a local/base group
                        if (config.IsBaseGroup(group.Name))
                        {
                            return true;
                        }
                    }
                }
            }
            
            return false;
        }
        
        /// <summary>
        /// Organize bundles into base and streaming directories
        /// </summary>
        private static void OrganizeBundles(AddressableAssetSettings settings, BuildTarget target)
        {
            var outputPath = GetStreamingOutputPath();
            var platformPath = Path.Combine(outputPath, target.ToString());
            var basePath = Path.Combine(platformPath, "base");
            var streamingPath = Path.Combine(platformPath, "streaming");
            
            // Create directories
            Directory.CreateDirectory(basePath);
            Directory.CreateDirectory(streamingPath);
            
            var config = AssetDatabase.LoadAssetAtPath<FlutterStreamingConfig>(STREAMING_CONFIG_PATH);
            
            // Read manifest
            var manifestPath = Path.Combine(platformPath, MANIFEST_FILENAME);
            if (!File.Exists(manifestPath)) return;
            
            var manifestJson = File.ReadAllText(manifestPath);
            var manifest = JsonUtility.FromJson<StreamingManifest>(manifestJson);
            
            foreach (var bundle in manifest.bundles)
            {
                var sourcePath = Path.Combine(platformPath, bundle.path);
                if (!File.Exists(sourcePath)) continue;
                
                var destDir = bundle.isBase ? basePath : streamingPath;
                var destPath = Path.Combine(destDir, bundle.name);
                
                File.Copy(sourcePath, destPath, true);
            }
            
            Debug.Log($"Organized bundles into base ({basePath}) and streaming ({streamingPath})");
        }
#endif
        
        /// <summary>
        /// Compute SHA256 hash of a file
        /// </summary>
        private static string ComputeSha256(string filePath)
        {
            using (var sha256 = System.Security.Cryptography.SHA256.Create())
            {
                using (var stream = File.OpenRead(filePath))
                {
                    var hash = sha256.ComputeHash(stream);
                    return BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
                }
            }
        }
        
        /// <summary>
        /// Format bytes to human-readable string
        /// </summary>
        private static string FormatBytes(long bytes)
        {
            string[] sizes = { "B", "KB", "MB", "GB" };
            int order = 0;
            double size = bytes;
            while (size >= 1024 && order < sizes.Length - 1)
            {
                order++;
                size /= 1024;
            }
            return $"{size:0.##} {sizes[order]}";
        }
        
        // Manifest data structures
        
        [Serializable]
        public class StreamingManifest
        {
            public string version;
            public string buildTarget;
            public string buildTime;
            public long totalSize;
            public long baseSize;
            public long streamableSize;
            public int bundleCount;
            public List<BundleInfo> bundles;
        }
        
        [Serializable]
        public class BundleInfo
        {
            public string name;
            public string path;
            public long sizeBytes;
            public string sha256;
            public bool isBase;
            public List<string> dependencies;
        }
    }
}
