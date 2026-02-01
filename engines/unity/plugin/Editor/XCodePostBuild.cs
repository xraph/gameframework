#if UNITY_IOS
using System.IO;
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using UnityEngine;

namespace Xraph.GameFramework.Unity.Editor
{
    /// <summary>
    /// Post-build processor for iOS Unity builds
    /// 
    /// Automatically modifies the Xcode project to:
    /// - Enable bitcode (if needed)
    /// - Set framework search paths
    /// - Configure build settings for Unity as a Library
    /// - Add required frameworks
    /// 
    /// Based on flutter-unity-view-widget XCodePostBuild.cs
    /// https://github.com/juicycleff/flutter-unity-view-widget
    /// </summary>
    public class XCodePostBuild
    {
        /// <summary>
        /// Post-process build callback
        /// Called automatically after iOS build completes
        /// </summary>
        [PostProcessBuild(999)]
        public static void OnPostProcessBuild(BuildTarget target, string pathToBuiltProject)
        {
            if (target != BuildTarget.iOS)
            {
                return;
            }

            Debug.Log("XCodePostBuild: Starting post-build processing for iOS");

            // Get the Xcode project path
            string projPath = pathToBuiltProject + "/Unity-iPhone.xcodeproj/project.pbxproj";
            
            if (!File.Exists(projPath))
            {
                Debug.LogError($"XCodePostBuild: Xcode project not found at {projPath}");
                return;
            }

            // Load the Xcode project
            PBXProject proj = new PBXProject();
            proj.ReadFromFile(projPath);

            // Get the main target GUID
#if UNITY_2019_3_OR_NEWER
            string targetGuid = proj.GetUnityMainTargetGuid();
            string frameworkTargetGuid = proj.GetUnityFrameworkTargetGuid();
#else
            string targetGuid = proj.TargetGuidByName(PBXProject.GetUnityTargetName());
            string frameworkTargetGuid = targetGuid;
#endif

            Debug.Log($"XCodePostBuild: Main target GUID: {targetGuid}");
            Debug.Log($"XCodePostBuild: Framework target GUID: {frameworkTargetGuid}");

            // Add Data folder to UnityFramework target (CRITICAL for game to work)
            // Without this, the framework won't contain game data and Unity will fail to initialize
            AddDataFolderToFramework(proj, pathToBuiltProject, frameworkTargetGuid);

            // Configure build settings
            ConfigureBuildSettings(proj, targetGuid, frameworkTargetGuid);

            // Add required frameworks
            AddRequiredFrameworks(proj, frameworkTargetGuid);

            // Configure framework search paths
            ConfigureFrameworkSearchPaths(proj, frameworkTargetGuid);

            // Save the modified project
            proj.WriteToFile(projPath);

            // Modify Info.plist
            ModifyPlist(pathToBuiltProject);

            Debug.Log("XCodePostBuild: Post-build processing completed successfully");
        }

        /// <summary>
        /// Configure Xcode build settings
        /// </summary>
        private static void ConfigureBuildSettings(PBXProject proj, string targetGuid, string frameworkTargetGuid)
        {
            // Enable bitcode (set to NO for Unity as a Library)
            proj.SetBuildProperty(targetGuid, "ENABLE_BITCODE", "NO");
            proj.SetBuildProperty(frameworkTargetGuid, "ENABLE_BITCODE", "NO");

            // Set C++ language standard (Unity 2022+ requires C++17)
            proj.SetBuildProperty(frameworkTargetGuid, "CLANG_CXX_LANGUAGE_STANDARD", "gnu++17");

            // Enable modules
            proj.SetBuildProperty(frameworkTargetGuid, "CLANG_ENABLE_MODULES", "YES");

            // Set deployment target (Unity 2022+ requires iOS 15.0+)
            proj.SetBuildProperty(targetGuid, "IPHONEOS_DEPLOYMENT_TARGET", "15.0");
            proj.SetBuildProperty(frameworkTargetGuid, "IPHONEOS_DEPLOYMENT_TARGET", "15.0");

            // Enable automatic signing (can be changed in Xcode)
            proj.SetBuildProperty(targetGuid, "CODE_SIGN_STYLE", "Automatic");

            // Set other linker flags
            proj.AddBuildProperty(frameworkTargetGuid, "OTHER_LDFLAGS", "-ObjC");

            Debug.Log("XCodePostBuild: Build settings configured");
        }

        /// <summary>
        /// Add required frameworks to the Xcode project
        /// </summary>
        private static void AddRequiredFrameworks(PBXProject proj, string frameworkTargetGuid)
        {
            // Add system frameworks required by Unity
            string[] frameworks = new string[]
            {
                "Foundation.framework",
                "UIKit.framework",
                "CoreGraphics.framework",
                "QuartzCore.framework",
                "AudioToolbox.framework",
                "AVFoundation.framework",
                "CoreAudio.framework",
                "CoreMedia.framework",
                "CoreVideo.framework",
                "OpenGLES.framework",
                "Metal.framework",
                "MetalKit.framework",
                "GameController.framework"
            };

            foreach (string framework in frameworks)
            {
                proj.AddFrameworkToProject(frameworkTargetGuid, framework, false);
            }

            Debug.Log($"XCodePostBuild: Added {frameworks.Length} required frameworks");
        }

        /// <summary>
        /// Configure framework search paths
        /// </summary>
        private static void ConfigureFrameworkSearchPaths(PBXProject proj, string frameworkTargetGuid)
        {
            // Add framework search paths
            proj.AddBuildProperty(frameworkTargetGuid, "FRAMEWORK_SEARCH_PATHS", "$(inherited)");
            proj.AddBuildProperty(frameworkTargetGuid, "FRAMEWORK_SEARCH_PATHS", "$(PROJECT_DIR)/Frameworks");

            // Add library search paths
            proj.AddBuildProperty(frameworkTargetGuid, "LIBRARY_SEARCH_PATHS", "$(inherited)");
            proj.AddBuildProperty(frameworkTargetGuid, "LIBRARY_SEARCH_PATHS", "$(PROJECT_DIR)/Libraries");

            Debug.Log("XCodePostBuild: Framework search paths configured");
        }

        /// <summary>
        /// Add the Data folder to the UnityFramework target
        /// This is CRITICAL - without it, the built framework won't contain game data
        /// (scenes, assets, IL2CPP metadata like global-metadata.dat)
        /// </summary>
        private static void AddDataFolderToFramework(PBXProject proj, string pathToBuiltProject, string frameworkTargetGuid)
        {
            string dataPath = Path.Combine(pathToBuiltProject, "Data");
            
            if (!Directory.Exists(dataPath))
            {
                Debug.LogWarning($"XCodePostBuild: Data folder not found at {dataPath}");
                return;
            }

            // Add the Data folder reference to the project
            string fileGuid = proj.AddFolderReference(dataPath, "Data");
            
            // Add to the UnityFramework target build phase
            proj.AddFileToBuild(frameworkTargetGuid, fileGuid);
            
            Debug.Log("XCodePostBuild: Added Data folder to UnityFramework target");
        }

        /// <summary>
        /// Modify Info.plist for Unity as a Library
        /// </summary>
        private static void ModifyPlist(string pathToBuiltProject)
        {
            string plistPath = pathToBuiltProject + "/Info.plist";
            
            if (!File.Exists(plistPath))
            {
                Debug.LogWarning($"XCodePostBuild: Info.plist not found at {plistPath}");
                return;
            }

            PlistDocument plist = new PlistDocument();
            plist.ReadFromFile(plistPath);

            // Get root dict
            PlistElementDict rootDict = plist.root;

            // Add Unity metadata
            rootDict.SetString("UnityBuildNumber", Application.version);
            rootDict.SetString("UnityBuildDate", System.DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));

            // Ensure status bar is hidden for Unity
            rootDict.SetBoolean("UIViewControllerBasedStatusBarAppearance", false);
            rootDict.SetBoolean("UIStatusBarHidden", true);

            // Set supported orientations (can be customized)
            PlistElementArray orientations = rootDict.CreateArray("UISupportedInterfaceOrientations");
            orientations.AddString("UIInterfaceOrientationPortrait");
            orientations.AddString("UIInterfaceOrientationLandscapeLeft");
            orientations.AddString("UIInterfaceOrientationLandscapeRight");

            // Save the modified plist
            plist.WriteToFile(plistPath);

            Debug.Log("XCodePostBuild: Info.plist modified successfully");
        }
    }
}
#endif

