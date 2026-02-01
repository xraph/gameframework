using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using System.Linq;

#if ADDRESSABLES_INSTALLED
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor.AddressableAssets.Settings.GroupSchemas;
#endif

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Editor window for analyzing streaming configuration and content.
    /// Shows what will be bundled vs streamed and estimated sizes.
    /// </summary>
    public class FlutterStreamingAnalyzer : EditorWindow
    {
        private Vector2 _scrollPosition;
        private AnalysisResult _analysisResult;
        private bool _showBaseContent = true;
        private bool _showStreamingContent = true;
        private bool _showRecommendations = true;

        [MenuItem("Game Framework/Streaming/Analyze Streaming", priority = 130)]
        public static void ShowWindow()
        {
            var window = GetWindow<FlutterStreamingAnalyzer>("Streaming Analyzer");
            window.minSize = new Vector2(400, 500);
            window.Show();
        }

        private void OnEnable()
        {
            RefreshAnalysis();
        }

        private void OnGUI()
        {
            EditorGUILayout.Space(10);

            // Header
            EditorGUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            EditorGUILayout.LabelField("Streaming Content Analyzer", EditorStyles.boldLabel);
            GUILayout.FlexibleSpace();
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space(10);

            // Refresh button
            EditorGUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("Refresh Analysis", GUILayout.Width(150)))
            {
                RefreshAnalysis();
            }
            GUILayout.FlexibleSpace();
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space(10);

#if !ADDRESSABLES_INSTALLED
            EditorGUILayout.HelpBox(
                "Addressables package not installed.\n\n" +
                "Click 'Setup Addressables' to install and configure.",
                MessageType.Warning);

            EditorGUILayout.Space(5);

            if (GUILayout.Button("Setup Addressables"))
            {
                FlutterAddressablesSetup.SetupAddressables();
            }
            return;
#else
            if (_analysisResult == null)
            {
                EditorGUILayout.HelpBox("Click 'Refresh Analysis' to analyze your project.", MessageType.Info);
                return;
            }

            _scrollPosition = EditorGUILayout.BeginScrollView(_scrollPosition);

            // Summary
            DrawSummarySection();

            EditorGUILayout.Space(10);

            // Base Content
            DrawContentSection("Base Content (Bundled with App)", _analysisResult.BaseGroups, ref _showBaseContent, true);

            EditorGUILayout.Space(5);

            // Streaming Content
            DrawContentSection("Streaming Content (Downloaded at Runtime)", _analysisResult.StreamingGroups, ref _showStreamingContent, false);

            EditorGUILayout.Space(10);

            // Recommendations
            DrawRecommendationsSection();

            EditorGUILayout.Space(10);

            // Actions
            DrawActionsSection();

            EditorGUILayout.EndScrollView();
#endif
        }

#if ADDRESSABLES_INSTALLED
        private void RefreshAnalysis()
        {
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                _analysisResult = null;
                return;
            }

            var config = AssetDatabase.LoadAssetAtPath<FlutterStreamingConfig>(
                "Assets/GameFramework/StreamingConfig.asset");

            var result = new AnalysisResult();

            foreach (var group in settings.groups)
            {
                if (group == null) continue;

                var schema = group.GetSchema<BundledAssetGroupSchema>();
                if (schema == null) continue;

                var groupInfo = new GroupInfo
                {
                    Name = group.Name,
                    AssetCount = group.entries.Count,
                    EstimatedSize = EstimateGroupSize(group)
                };

                // Determine if base or streaming based on build path
                var buildPath = schema.BuildPath.GetName(settings);
                var isBase = buildPath.Contains("Local") ||
                             (config != null && config.IsBaseGroup(group.Name));

                if (isBase)
                {
                    result.BaseGroups.Add(groupInfo);
                    result.TotalBaseSize += groupInfo.EstimatedSize;
                }
                else
                {
                    result.StreamingGroups.Add(groupInfo);
                    result.TotalStreamingSize += groupInfo.EstimatedSize;
                }
            }

            // Generate recommendations
            GenerateRecommendations(result, config);

            _analysisResult = result;
        }

        private long EstimateGroupSize(AddressableAssetGroup group)
        {
            long totalSize = 0;

            foreach (var entry in group.entries)
            {
                var path = AssetDatabase.GUIDToAssetPath(entry.guid);
                if (!string.IsNullOrEmpty(path))
                {
                    var fileInfo = new FileInfo(path);
                    if (fileInfo.Exists)
                    {
                        totalSize += fileInfo.Length;
                    }
                }
            }

            // Rough compression estimate (assets compress ~60-70%)
            return (long)(totalSize * 0.65f);
        }

        private void GenerateRecommendations(AnalysisResult result, FlutterStreamingConfig config)
        {
            result.Recommendations = new List<string>();

            // Check if streaming is configured
            if (config == null || !config.enableStreaming)
            {
                result.Recommendations.Add("Create a StreamingConfig asset (Game Framework > Streaming > Setup Addressables)");
            }

            // Check if there's content to stream
            if (result.StreamingGroups.Count == 0)
            {
                result.Recommendations.Add("No streaming groups found. Create groups for content that should be downloaded at runtime.");
            }

            // Check if base content exists
            if (result.BaseGroups.Count == 0)
            {
                result.Recommendations.Add("WARNING: No base content groups! Your app needs bundled content to run.");
            }

            // Check for large streaming groups
            foreach (var group in result.StreamingGroups)
            {
                if (group.EstimatedSize > 100 * 1024 * 1024) // > 100 MB
                {
                    result.Recommendations.Add($"Group '{group.Name}' is large ({FormatBytes(group.EstimatedSize)}). Consider splitting into smaller groups for better streaming UX.");
                }
            }

            // Check total base size
            if (result.TotalBaseSize > 100 * 1024 * 1024) // > 100 MB
            {
                result.Recommendations.Add($"Base content is {FormatBytes(result.TotalBaseSize)}. Consider moving some content to streaming groups to reduce app size.");
            }
        }

        private void DrawSummarySection()
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);

            EditorGUILayout.LabelField("Summary", EditorStyles.boldLabel);
            EditorGUILayout.Space(5);

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Base Groups:", GUILayout.Width(120));
            EditorGUILayout.LabelField($"{_analysisResult.BaseGroups.Count} groups");
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Base Size:", GUILayout.Width(120));
            EditorGUILayout.LabelField(FormatBytes(_analysisResult.TotalBaseSize));
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space(3);

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Streaming Groups:", GUILayout.Width(120));
            EditorGUILayout.LabelField($"{_analysisResult.StreamingGroups.Count} groups");
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Streaming Size:", GUILayout.Width(120));
            EditorGUILayout.LabelField(FormatBytes(_analysisResult.TotalStreamingSize));
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space(3);

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Total Size:", GUILayout.Width(120));
            EditorGUILayout.LabelField(
                FormatBytes(_analysisResult.TotalBaseSize + _analysisResult.TotalStreamingSize),
                EditorStyles.boldLabel);
            EditorGUILayout.EndHorizontal();

            // App size reduction estimate
            if (_analysisResult.TotalStreamingSize > 0)
            {
                var reduction = (float)_analysisResult.TotalStreamingSize /
                               (_analysisResult.TotalBaseSize + _analysisResult.TotalStreamingSize) * 100;
                EditorGUILayout.Space(5);
                EditorGUILayout.LabelField($"Estimated app size reduction: {reduction:F1}%",
                    EditorStyles.miniLabel);
            }

            EditorGUILayout.EndVertical();
        }

        private void DrawContentSection(string title, List<GroupInfo> groups, ref bool foldout, bool isBase)
        {
            foldout = EditorGUILayout.Foldout(foldout, title, true);

            if (foldout)
            {
                EditorGUILayout.BeginVertical(EditorStyles.helpBox);

                if (groups.Count == 0)
                {
                    EditorGUILayout.LabelField("No groups configured", EditorStyles.miniLabel);
                }
                else
                {
                    foreach (var group in groups)
                    {
                        EditorGUILayout.BeginHorizontal();

                        // Icon
                        var icon = isBase
                            ? EditorGUIUtility.IconContent("Collab.FileAdded").image
                            : EditorGUIUtility.IconContent("CloudConnect").image;
                        GUILayout.Label(icon, GUILayout.Width(20), GUILayout.Height(16));

                        EditorGUILayout.LabelField(group.Name, GUILayout.Width(150));
                        EditorGUILayout.LabelField($"{group.AssetCount} assets", GUILayout.Width(80));
                        EditorGUILayout.LabelField(FormatBytes(group.EstimatedSize));

                        EditorGUILayout.EndHorizontal();
                    }
                }

                EditorGUILayout.EndVertical();
            }
        }

        private void DrawRecommendationsSection()
        {
            _showRecommendations = EditorGUILayout.Foldout(_showRecommendations, "Recommendations", true);

            if (_showRecommendations)
            {
                EditorGUILayout.BeginVertical(EditorStyles.helpBox);

                if (_analysisResult.Recommendations.Count == 0)
                {
                    EditorGUILayout.LabelField("✓ Configuration looks good!", EditorStyles.miniLabel);
                }
                else
                {
                    foreach (var rec in _analysisResult.Recommendations)
                    {
                        var isWarning = rec.StartsWith("WARNING");
                        var style = isWarning ? EditorStyles.wordWrappedLabel : EditorStyles.miniLabel;
                        EditorGUILayout.LabelField(isWarning ? "⚠ " + rec : "• " + rec, style);
                        EditorGUILayout.Space(3);
                    }
                }

                EditorGUILayout.EndVertical();
            }
        }

        private void DrawActionsSection()
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            EditorGUILayout.LabelField("Actions", EditorStyles.boldLabel);
            EditorGUILayout.Space(5);

            EditorGUILayout.BeginHorizontal();

            if (GUILayout.Button("Configure Groups"))
            {
                EditorApplication.ExecuteMenuItem("Window/Asset Management/Addressables/Groups");
            }

            if (GUILayout.Button("Build Addressables"))
            {
                FlutterAddressablesBuildScript.BuildAddressables();
            }

            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space(5);

            EditorGUILayout.BeginHorizontal();

            if (GUILayout.Button("Validate Configuration"))
            {
                FlutterAddressablesSetup.ValidateConfiguration();
            }

            if (GUILayout.Button("Edit Streaming Config"))
            {
                var config = AssetDatabase.LoadAssetAtPath<FlutterStreamingConfig>(
                    "Assets/GameFramework/StreamingConfig.asset");
                if (config != null)
                {
                    Selection.activeObject = config;
                }
                else
                {
                    EditorUtility.DisplayDialog("Not Found",
                        "StreamingConfig.asset not found. Run Setup Addressables first.",
                        "OK");
                }
            }

            EditorGUILayout.EndHorizontal();

            EditorGUILayout.EndVertical();
        }
#endif

        private static string FormatBytes(long bytes)
        {
            if (bytes < 1024) return $"{bytes} B";
            if (bytes < 1024 * 1024) return $"{bytes / 1024f:F1} KB";
            if (bytes < 1024 * 1024 * 1024) return $"{bytes / (1024f * 1024f):F1} MB";
            return $"{bytes / (1024f * 1024f * 1024f):F2} GB";
        }

        // Data classes
        private class AnalysisResult
        {
            public List<GroupInfo> BaseGroups = new List<GroupInfo>();
            public List<GroupInfo> StreamingGroups = new List<GroupInfo>();
            public long TotalBaseSize;
            public long TotalStreamingSize;
            public List<string> Recommendations = new List<string>();
        }

        private class GroupInfo
        {
            public string Name;
            public int AssetCount;
            public long EstimatedSize;
        }
    }
}
