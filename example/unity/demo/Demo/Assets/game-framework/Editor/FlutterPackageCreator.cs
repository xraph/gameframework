using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;

namespace FlutterUnity.Editor
{
    /// <summary>
    /// Creates a Unity package (.unitypackage) containing all Flutter integration assets
    /// </summary>
    public class FlutterPackageCreator : EditorWindow
    {
        private const string PACKAGE_NAME = "FlutterUnityIntegration";
        private const string PACKAGE_VERSION = "0.4.0";

        private bool includeScripts = true;
        private bool includeEditorTools = true;
        private bool includeIOSBridge = true;
        private bool includeDocumentation = true;
        private bool includeExamples = false;

        private string outputPath = "";
        private Vector2 scrollPosition;

        [MenuItem("Game Framework/Create Unity Package", false, 100)]
        public static void ShowWindow()
        {
            var window = GetWindow<FlutterPackageCreator>("Create Flutter Package");
            window.minSize = new Vector2(400, 500);
            window.Show();
        }

        private void OnEnable()
        {
            // Set default output path to user's desktop
            outputPath = System.Environment.GetFolderPath(System.Environment.SpecialFolder.Desktop);
        }

        private void OnGUI()
        {
            scrollPosition = EditorGUILayout.BeginScrollView(scrollPosition);

            // Header
            GUILayout.Space(10);
            GUIStyle titleStyle = new GUIStyle(EditorStyles.boldLabel);
            titleStyle.fontSize = 16;
            titleStyle.alignment = TextAnchor.MiddleCenter;
            EditorGUILayout.LabelField("Flutter Unity Package Creator", titleStyle);
            GUILayout.Space(10);

            EditorGUILayout.HelpBox(
                "This tool creates a Unity package (.unitypackage) containing all Flutter integration assets. " +
                "The package can be easily imported into other Unity projects.",
                MessageType.Info
            );

            GUILayout.Space(10);

            // Package Info
            DrawSection("Package Information", () =>
            {
                EditorGUILayout.LabelField("Package Name:", PACKAGE_NAME);
                EditorGUILayout.LabelField("Version:", PACKAGE_VERSION);
                EditorGUILayout.LabelField("Target Unity:", "2022.3.x or higher");
            });

            GUILayout.Space(10);

            // Options
            DrawSection("Package Contents", () =>
            {
                includeScripts = EditorGUILayout.Toggle("Runtime Scripts", includeScripts);
                EditorGUI.indentLevel++;
                if (includeScripts)
                {
                    EditorGUILayout.LabelField("• FlutterBridge.cs", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• FlutterSceneManager.cs", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• FlutterGameManager.cs", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• FlutterUtilities.cs", EditorStyles.miniLabel);
                }
                EditorGUI.indentLevel--;

                GUILayout.Space(5);

                includeEditorTools = EditorGUILayout.Toggle("Editor Tools", includeEditorTools);
                EditorGUI.indentLevel++;
                if (includeEditorTools)
                {
                    EditorGUILayout.LabelField("• FlutterExporter.cs", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• FlutterProjectValidator.cs", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• FlutterPackageCreator.cs", EditorStyles.miniLabel);
                }
                EditorGUI.indentLevel--;

                GUILayout.Space(5);

                includeIOSBridge = EditorGUILayout.Toggle("iOS Native Bridge", includeIOSBridge);
                EditorGUI.indentLevel++;
                if (includeIOSBridge)
                {
                    EditorGUILayout.LabelField("• FlutterBridge.mm", EditorStyles.miniLabel);
                }
                EditorGUI.indentLevel--;

                GUILayout.Space(5);

                includeDocumentation = EditorGUILayout.Toggle("Documentation", includeDocumentation);
                EditorGUI.indentLevel++;
                if (includeDocumentation)
                {
                    EditorGUILayout.LabelField("• README.md", EditorStyles.miniLabel);
                    EditorGUILayout.LabelField("• AR_FOUNDATION.md", EditorStyles.miniLabel);
                }
                EditorGUI.indentLevel--;

                GUILayout.Space(5);

                includeExamples = EditorGUILayout.Toggle("Example Scenes", includeExamples);
                EditorGUI.indentLevel++;
                if (includeExamples)
                {
                    EditorGUILayout.LabelField("• Example scenes and prefabs", EditorStyles.miniLabel);
                }
                EditorGUI.indentLevel--;
            });

            GUILayout.Space(10);

            // Output Path
            DrawSection("Output Settings", () =>
            {
                EditorGUILayout.LabelField("Output Directory:");
                EditorGUILayout.BeginHorizontal();
                EditorGUILayout.TextField(outputPath);
                if (GUILayout.Button("Browse...", GUILayout.Width(80)))
                {
                    string path = EditorUtility.OpenFolderPanel("Select Output Directory", outputPath, "");
                    if (!string.IsNullOrEmpty(path))
                    {
                        outputPath = path;
                    }
                }
                EditorGUILayout.EndHorizontal();

                EditorGUILayout.LabelField("Output File:");
                EditorGUILayout.LabelField(GetOutputFileName(), EditorStyles.boldLabel);
            });

            GUILayout.Space(10);

            // Estimated Size
            DrawSection("Package Statistics", () =>
            {
                int fileCount = EstimateFileCount();
                EditorGUILayout.LabelField("Estimated Files:", fileCount.ToString());
                EditorGUILayout.LabelField("Estimated Size:", EstimateSize());
            });

            GUILayout.Space(20);

            // Create Button
            GUI.backgroundColor = new Color(0.3f, 0.8f, 0.3f);
            if (GUILayout.Button("Create Package", GUILayout.Height(40)))
            {
                CreatePackage();
            }
            GUI.backgroundColor = Color.white;

            GUILayout.Space(10);

            EditorGUILayout.EndScrollView();
        }

        private void DrawSection(string title, System.Action content)
        {
            EditorGUILayout.LabelField(title, EditorStyles.boldLabel);
            EditorGUI.BeginDisabledGroup(false);
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            content();
            EditorGUILayout.EndVertical();
            EditorGUI.EndDisabledGroup();
        }

        private string GetOutputFileName()
        {
            return $"{PACKAGE_NAME}_v{PACKAGE_VERSION}.unitypackage";
        }

        private int EstimateFileCount()
        {
            int count = 0;
            if (includeScripts) count += 4;
            if (includeEditorTools) count += 3;
            if (includeIOSBridge) count += 1;
            if (includeDocumentation) count += 2;
            if (includeExamples) count += 5;
            return count;
        }

        private string EstimateSize()
        {
            int kb = 0;
            if (includeScripts) kb += 200;
            if (includeEditorTools) kb += 150;
            if (includeIOSBridge) kb += 10;
            if (includeDocumentation) kb += 100;
            if (includeExamples) kb += 500;

            if (kb < 1024)
                return $"{kb} KB";
            else
                return $"{(kb / 1024.0f):F1} MB";
        }

        private void CreatePackage()
        {
            if (string.IsNullOrEmpty(outputPath))
            {
                EditorUtility.DisplayDialog("Error", "Please select an output directory.", "OK");
                return;
            }

            if (!Directory.Exists(outputPath))
            {
                EditorUtility.DisplayDialog("Error", "Output directory does not exist.", "OK");
                return;
            }

            List<string> assetPaths = CollectAssetPaths();

            if (assetPaths.Count == 0)
            {
                EditorUtility.DisplayDialog("Error", "No assets found to export.", "OK");
                return;
            }

            string fullPath = Path.Combine(outputPath, GetOutputFileName());

            try
            {
                // Export package
                AssetDatabase.ExportPackage(
                    assetPaths.ToArray(),
                    fullPath,
                    ExportPackageOptions.Recurse | ExportPackageOptions.IncludeDependencies
                );

                // Show success dialog
                if (EditorUtility.DisplayDialog(
                    "Success",
                    $"Package created successfully!\n\n" +
                    $"Location: {fullPath}\n" +
                    $"Files: {assetPaths.Count}\n\n" +
                    "Would you like to reveal the file in Finder/Explorer?",
                    "Yes",
                    "No"))
                {
                    EditorUtility.RevealInFinder(fullPath);
                }

                Debug.Log($"Flutter Unity package created: {fullPath}");
            }
            catch (System.Exception e)
            {
                EditorUtility.DisplayDialog("Error", $"Failed to create package:\n{e.Message}", "OK");
                Debug.LogError($"Package creation failed: {e}");
            }
        }

        private List<string> CollectAssetPaths()
        {
            List<string> paths = new List<string>();

            // Find the FlutterPlugins folder
            string[] guids = AssetDatabase.FindAssets("t:Script FlutterBridge");
            if (guids.Length == 0)
            {
                Debug.LogWarning("FlutterBridge script not found. Make sure Flutter scripts are in your project.");
                return paths;
            }

            string scriptPath = AssetDatabase.GUIDToAssetPath(guids[0]);
            string flutterPluginsPath = Path.GetDirectoryName(scriptPath);

            // Add runtime scripts
            if (includeScripts)
            {
                AddIfExists(paths, Path.Combine(flutterPluginsPath, "FlutterBridge.cs"));
                AddIfExists(paths, Path.Combine(flutterPluginsPath, "FlutterSceneManager.cs"));
                AddIfExists(paths, Path.Combine(flutterPluginsPath, "FlutterGameManager.cs"));
                AddIfExists(paths, Path.Combine(flutterPluginsPath, "FlutterUtilities.cs"));
            }

            // Add editor tools
            if (includeEditorTools)
            {
                string editorPath = Path.Combine(flutterPluginsPath, "Editor");
                AddIfExists(paths, Path.Combine(editorPath, "FlutterExporter.cs"));
                AddIfExists(paths, Path.Combine(editorPath, "FlutterProjectValidator.cs"));
                AddIfExists(paths, Path.Combine(editorPath, "FlutterPackageCreator.cs"));
            }

            // Add iOS bridge
            if (includeIOSBridge)
            {
                string pluginsPath = Path.Combine(flutterPluginsPath, "Plugins");
                string iosPath = Path.Combine(pluginsPath, "iOS");
                AddIfExists(paths, Path.Combine(iosPath, "FlutterBridge.mm"));
            }

            // Add documentation
            if (includeDocumentation)
            {
                AddIfExists(paths, Path.Combine(flutterPluginsPath, "README.md"));
                AddIfExists(paths, Path.Combine(flutterPluginsPath, "AR_FOUNDATION.md"));
            }

            // Add examples
            if (includeExamples)
            {
                string examplesPath = Path.Combine(flutterPluginsPath, "Examples");
                if (Directory.Exists(examplesPath))
                {
                    AddDirectoryRecursive(paths, examplesPath);
                }
            }

            return paths;
        }

        private void AddIfExists(List<string> paths, string path)
        {
            // Convert to forward slashes for Unity
            path = path.Replace("\\", "/");

            if (File.Exists(path))
            {
                paths.Add(path);
            }
            else
            {
                Debug.LogWarning($"File not found: {path}");
            }
        }

        private void AddDirectoryRecursive(List<string> paths, string directory)
        {
            if (!Directory.Exists(directory)) return;

            string[] files = Directory.GetFiles(directory, "*", SearchOption.AllDirectories);
            foreach (string file in files)
            {
                if (!file.EndsWith(".meta"))
                {
                    AddIfExists(paths, file);
                }
            }
        }
    }
}
