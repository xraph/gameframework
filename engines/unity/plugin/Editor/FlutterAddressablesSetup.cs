using UnityEngine;
using UnityEditor;
using System;
using System.IO;
using System.Collections.Generic;

#if ADDRESSABLES_INSTALLED
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor.AddressableAssets.Settings.GroupSchemas;
#endif

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Automated setup for Unity Addressables with Flutter-optimized configuration.
    /// Provides one-click setup and configuration for streaming content.
    /// </summary>
    public static class FlutterAddressablesSetup
    {
        private const string ADDRESSABLES_PACKAGE = "com.unity.addressables";
        private const string STREAMING_CONFIG_PATH = "Assets/GameFramework/StreamingConfig.asset";
        
        /// <summary>
        /// Setup Addressables with Flutter Game Framework defaults
        /// </summary>
        [MenuItem("Game Framework/Streaming/Setup Addressables", priority = 100)]
        public static void SetupAddressables()
        {
#if !ADDRESSABLES_INSTALLED
            Debug.Log("Addressables package not installed. Installing...");
            InstallAddressablesPackage();
#else
            Debug.Log("Setting up Addressables for Flutter Game Framework...");
            
            // 1. Create or get AddressableAssetSettings
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                settings = AddressableAssetSettingsDefaultObject.GetSettings(true);
                Debug.Log("Created new AddressableAssetSettings");
            }
            
            // 2. Configure build and load paths for remote content
            ConfigureRemotePaths(settings);
            
            // 3. Create default groups
            CreateDefaultGroups(settings);
            
            // 4. Configure compression settings
            ConfigureCompression(settings);
            
            // 5. Create streaming config asset
            CreateStreamingConfig();
            
            Debug.Log("Addressables setup complete!");
            EditorUtility.DisplayDialog(
                "Addressables Setup Complete",
                "Flutter Game Framework Addressables configuration is ready.\n\n" +
                "Next steps:\n" +
                "1. Mark your assets as Addressable\n" +
                "2. Assign assets to Base or Streaming groups\n" +
                "3. Run 'Game Framework > Streaming > Analyze Streaming' to review\n" +
                "4. Build with streaming enabled",
                "OK");
#endif
        }
        
        /// <summary>
        /// Install the Addressables package via Package Manager
        /// </summary>
        private static void InstallAddressablesPackage()
        {
            UnityEditor.PackageManager.Client.Add(ADDRESSABLES_PACKAGE);
            Debug.Log($"Installing {ADDRESSABLES_PACKAGE}... Please wait for import to complete, then run Setup again.");
            
            EditorUtility.DisplayDialog(
                "Installing Addressables",
                "The Addressables package is being installed.\n\n" +
                "Please wait for the import to complete, then run:\n" +
                "Game Framework > Streaming > Setup Addressables\n\n" +
                "You may need to restart Unity after installation.",
                "OK");
        }
        
#if ADDRESSABLES_INSTALLED
        /// <summary>
        /// Configure remote build and load paths for GameFramework Cloud
        /// </summary>
        private static void ConfigureRemotePaths(AddressableAssetSettings settings)
        {
            // Create profile variables for remote paths
            var profileId = settings.activeProfileId;
            
            // Set remote build path
            settings.profileSettings.SetValue(profileId, "Remote.BuildPath", 
                "[UnityEngine.Application.dataPath]/../ServerData/[BuildTarget]");
            
            // Set remote load path - this will be overridden at runtime by Flutter
            settings.profileSettings.SetValue(profileId, "Remote.LoadPath", 
                "{GameFramework.StreamingUrl}/[BuildTarget]");
            
            Debug.Log("Configured remote build and load paths");
        }
        
        /// <summary>
        /// Create default addressable groups for base and streaming content
        /// </summary>
        private static void CreateDefaultGroups(AddressableAssetSettings settings)
        {
            // Create Base group (bundled with app)
            var baseGroup = CreateOrGetGroup(settings, "Base", false);
            ConfigureGroupForLocalContent(baseGroup);
            
            // Create UI group (bundled with app)
            var uiGroup = CreateOrGetGroup(settings, "UI", false);
            ConfigureGroupForLocalContent(uiGroup);
            
            // Create streaming groups
            var level1Group = CreateOrGetGroup(settings, "Level1", true);
            ConfigureGroupForRemoteContent(level1Group);
            
            var level2Group = CreateOrGetGroup(settings, "Level2", true);
            ConfigureGroupForRemoteContent(level2Group);
            
            var charactersGroup = CreateOrGetGroup(settings, "Characters", true);
            ConfigureGroupForRemoteContent(charactersGroup);
            
            var environmentGroup = CreateOrGetGroup(settings, "Environment", true);
            ConfigureGroupForRemoteContent(environmentGroup);
            
            Debug.Log("Created default addressable groups");
        }
        
        private static AddressableAssetGroup CreateOrGetGroup(AddressableAssetSettings settings, string groupName, bool isRemote)
        {
            var group = settings.FindGroup(groupName);
            if (group == null)
            {
                group = settings.CreateGroup(groupName, false, false, true, null);
                Debug.Log($"Created addressable group: {groupName}");
            }
            return group;
        }
        
        private static void ConfigureGroupForLocalContent(AddressableAssetGroup group)
        {
            var schema = group.GetSchema<BundledAssetGroupSchema>();
            if (schema == null)
            {
                schema = group.AddSchema<BundledAssetGroupSchema>();
            }
            
            // Local content settings
            schema.BuildPath.SetVariableByName(group.Settings, "LocalBuildPath");
            schema.LoadPath.SetVariableByName(group.Settings, "LocalLoadPath");
            schema.BundleMode = BundledAssetGroupSchema.BundlePackingMode.PackTogether;
            schema.Compression = BundledAssetGroupSchema.BundleCompressionMode.LZ4;
            
            // Ensure content update schema
            var updateSchema = group.GetSchema<ContentUpdateGroupSchema>();
            if (updateSchema == null)
            {
                updateSchema = group.AddSchema<ContentUpdateGroupSchema>();
            }
            updateSchema.StaticContent = true;
        }
        
        private static void ConfigureGroupForRemoteContent(AddressableAssetGroup group)
        {
            var schema = group.GetSchema<BundledAssetGroupSchema>();
            if (schema == null)
            {
                schema = group.AddSchema<BundledAssetGroupSchema>();
            }
            
            // Remote content settings
            schema.BuildPath.SetVariableByName(group.Settings, "Remote.BuildPath");
            schema.LoadPath.SetVariableByName(group.Settings, "Remote.LoadPath");
            schema.BundleMode = BundledAssetGroupSchema.BundlePackingMode.PackTogether;
            schema.Compression = BundledAssetGroupSchema.BundleCompressionMode.LZ4;
            
            // Ensure content update schema
            var updateSchema = group.GetSchema<ContentUpdateGroupSchema>();
            if (updateSchema == null)
            {
                updateSchema = group.AddSchema<ContentUpdateGroupSchema>();
            }
            updateSchema.StaticContent = false; // Allow updates for remote content
        }
        
        /// <summary>
        /// Configure compression settings optimized for mobile
        /// </summary>
        private static void ConfigureCompression(AddressableAssetSettings settings)
        {
            // LZ4 is faster to decompress than LZMA, better for mobile
            // This is already set per-group, but we can set defaults here
            Debug.Log("Compression configured to LZ4 for optimal mobile performance");
        }
#endif
        
        /// <summary>
        /// Create the streaming configuration ScriptableObject
        /// </summary>
        private static void CreateStreamingConfig()
        {
            // Ensure directory exists
            var directory = Path.GetDirectoryName(STREAMING_CONFIG_PATH);
            if (!Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
            
            // Check if config already exists
            var existingConfig = AssetDatabase.LoadAssetAtPath<FlutterStreamingConfig>(STREAMING_CONFIG_PATH);
            if (existingConfig != null)
            {
                Debug.Log("Streaming config already exists");
                return;
            }
            
            // Create new config
            var config = ScriptableObject.CreateInstance<FlutterStreamingConfig>();
            AssetDatabase.CreateAsset(config, STREAMING_CONFIG_PATH);
            AssetDatabase.SaveAssets();
            
            Debug.Log($"Created streaming config at: {STREAMING_CONFIG_PATH}");
        }
        
        /// <summary>
        /// Validate Addressables configuration
        /// </summary>
        [MenuItem("Game Framework/Streaming/Validate Configuration", priority = 110)]
        public static void ValidateConfiguration()
        {
#if !ADDRESSABLES_INSTALLED
            Debug.LogWarning("Addressables package not installed. Run 'Setup Addressables' first.");
            return;
#else
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                Debug.LogError("AddressableAssetSettings not found. Run 'Setup Addressables' first.");
                return;
            }
            
            var issues = new List<string>();
            
            // Check for required groups
            if (settings.FindGroup("Base") == null)
            {
                issues.Add("Missing 'Base' group for local content");
            }
            
            // Check for streaming groups
            var hasStreamingGroups = false;
            foreach (var group in settings.groups)
            {
                var schema = group.GetSchema<BundledAssetGroupSchema>();
                if (schema != null && schema.LoadPath.GetName(settings) == "Remote.LoadPath")
                {
                    hasStreamingGroups = true;
                    break;
                }
            }
            
            if (!hasStreamingGroups)
            {
                issues.Add("No streaming groups configured. Assets won't be downloaded at runtime.");
            }
            
            // Check streaming config
            var streamingConfig = AssetDatabase.LoadAssetAtPath<FlutterStreamingConfig>(STREAMING_CONFIG_PATH);
            if (streamingConfig == null)
            {
                issues.Add("Streaming config not found. Run 'Setup Addressables' to create it.");
            }
            
            // Report results
            if (issues.Count == 0)
            {
                Debug.Log("Addressables configuration is valid!");
                EditorUtility.DisplayDialog("Validation Passed", "Addressables configuration is valid and ready for streaming.", "OK");
            }
            else
            {
                var message = "Configuration issues found:\n\n" + string.Join("\n", issues);
                Debug.LogWarning(message);
                EditorUtility.DisplayDialog("Validation Issues", message, "OK");
            }
#endif
        }
        
        /// <summary>
        /// Quick action to mark selected assets as streaming content
        /// </summary>
        [MenuItem("Assets/Game Framework/Mark as Streaming Content", priority = 1000)]
        public static void MarkAsStreamingContent()
        {
#if !ADDRESSABLES_INSTALLED
            Debug.LogWarning("Addressables package not installed.");
            return;
#else
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                Debug.LogError("Run 'Setup Addressables' first.");
                return;
            }
            
            var defaultStreamingGroup = settings.FindGroup("Level1");
            if (defaultStreamingGroup == null)
            {
                Debug.LogError("Default streaming group 'Level1' not found. Run 'Setup Addressables' first.");
                return;
            }
            
            var selectedAssets = Selection.assetGUIDs;
            foreach (var guid in selectedAssets)
            {
                var entry = settings.CreateOrMoveEntry(guid, defaultStreamingGroup, false, false);
                if (entry != null)
                {
                    Debug.Log($"Marked as streaming: {entry.address}");
                }
            }
            
            settings.SetDirty(AddressableAssetSettings.ModificationEvent.EntryMoved, null, true);
#endif
        }
        
        /// <summary>
        /// Quick action to mark selected assets as base content
        /// </summary>
        [MenuItem("Assets/Game Framework/Mark as Base Content", priority = 1001)]
        public static void MarkAsBaseContent()
        {
#if !ADDRESSABLES_INSTALLED
            Debug.LogWarning("Addressables package not installed.");
            return;
#else
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                Debug.LogError("Run 'Setup Addressables' first.");
                return;
            }
            
            var baseGroup = settings.FindGroup("Base");
            if (baseGroup == null)
            {
                Debug.LogError("Base group not found. Run 'Setup Addressables' first.");
                return;
            }
            
            var selectedAssets = Selection.assetGUIDs;
            foreach (var guid in selectedAssets)
            {
                var entry = settings.CreateOrMoveEntry(guid, baseGroup, false, false);
                if (entry != null)
                {
                    Debug.Log($"Marked as base content: {entry.address}");
                }
            }
            
            settings.SetDirty(AddressableAssetSettings.ModificationEvent.EntryMoved, null, true);
#endif
        }
    }
}
