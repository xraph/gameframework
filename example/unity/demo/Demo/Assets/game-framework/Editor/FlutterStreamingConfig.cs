using UnityEngine;
using System.Collections.Generic;

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// ScriptableObject for per-project streaming configuration.
    /// Controls which content is bundled vs streamed and cloud settings.
    /// </summary>
    [CreateAssetMenu(fileName = "StreamingConfig", menuName = "Game Framework/Streaming Config", order = 1)]
    public class FlutterStreamingConfig : ScriptableObject
    {
        [Header("Cloud Configuration")]
        [Tooltip("GameFramework Cloud URL for streaming content")]
        public string cloudUrl = "https://cloud.gameframework.io";
        
        [Tooltip("Package name for this project (used for cloud manifest URL)")]
        public string packageName = "";
        
        [Tooltip("Enable streaming at runtime")]
        public bool enableStreaming = true;
        
        [Header("Content Configuration")]
        [Tooltip("Addressable groups to bundle with the app (not downloaded)")]
        public List<string> baseGroups = new List<string> { "Base", "UI" };
        
        [Tooltip("Addressable groups to stream from cloud")]
        public List<string> streamingGroups = new List<string> { "Level1", "Level2", "Characters", "Environment" };
        
        [Header("Build Settings")]
        [Tooltip("Chunk size for streaming bundles in MB")]
        [Range(1, 50)]
        public int chunkSizeMB = 10;
        
        [Tooltip("Use LZ4 compression (faster decompression, slightly larger files)")]
        public bool useLZ4Compression = true;
        
        [Tooltip("Generate content hash for cache invalidation")]
        public bool generateContentHash = true;
        
        [Header("Runtime Settings")]
        [Tooltip("Maximum concurrent downloads")]
        [Range(1, 8)]
        public int maxConcurrentDownloads = 3;
        
        [Tooltip("Retry failed downloads")]
        public bool retryOnFailure = true;
        
        [Tooltip("Maximum retry attempts")]
        [Range(1, 10)]
        public int maxRetryAttempts = 3;
        
        [Tooltip("Timeout for downloads in seconds")]
        [Range(10, 300)]
        public int downloadTimeoutSeconds = 60;
        
        [Header("Cache Settings")]
        [Tooltip("Maximum cache size in MB (0 = unlimited)")]
        public int maxCacheSizeMB = 0;
        
        [Tooltip("Clear cache on version update")]
        public bool clearCacheOnUpdate = false;
        
        /// <summary>
        /// Get the manifest URL for a specific version
        /// </summary>
        public string GetManifestUrl(string version)
        {
            return $"{cloudUrl}/v1/packages/{packageName}/versions/{version}/manifest.json";
        }
        
        /// <summary>
        /// Get the bundle URL for a specific bundle
        /// </summary>
        public string GetBundleUrl(string version, string bundleName, string platform)
        {
            return $"{cloudUrl}/v1/packages/{packageName}/versions/{version}/bundles/{platform}/{bundleName}";
        }
        
        /// <summary>
        /// Check if a group is configured for streaming
        /// </summary>
        public bool IsStreamingGroup(string groupName)
        {
            return streamingGroups.Contains(groupName);
        }
        
        /// <summary>
        /// Check if a group is configured as base content
        /// </summary>
        public bool IsBaseGroup(string groupName)
        {
            return baseGroups.Contains(groupName);
        }
        
        /// <summary>
        /// Validate the configuration
        /// </summary>
        public List<string> Validate()
        {
            var issues = new List<string>();
            
            if (string.IsNullOrEmpty(cloudUrl))
            {
                issues.Add("Cloud URL is not configured");
            }
            
            if (string.IsNullOrEmpty(packageName))
            {
                issues.Add("Package name is not configured");
            }
            
            if (baseGroups.Count == 0)
            {
                issues.Add("No base groups configured - app needs some bundled content");
            }
            
            if (enableStreaming && streamingGroups.Count == 0)
            {
                issues.Add("Streaming enabled but no streaming groups configured");
            }
            
            if (chunkSizeMB < 1)
            {
                issues.Add("Chunk size must be at least 1 MB");
            }
            
            // Check for overlapping groups
            foreach (var group in baseGroups)
            {
                if (streamingGroups.Contains(group))
                {
                    issues.Add($"Group '{group}' is in both base and streaming lists");
                }
            }
            
            return issues;
        }
    }
}
