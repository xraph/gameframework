using UnityEngine;
using UnityEngine.SceneManagement;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Manages Unity scene events and notifies Flutter
    ///
    /// This component automatically notifies Flutter when scenes are loaded/unloaded.
    /// Uses singleton pattern to ensure consistent scene management across scenes.
    /// 
    /// Usage:
    /// <code>
    /// FlutterSceneManager.Instance.LoadScene("Level2");
    /// FlutterSceneManager.Instance.LoadSceneAsync("Level3");
    /// </code>
    /// </summary>
    public class FlutterSceneManager : SingletonMonoBehaviour<FlutterSceneManager>
    {
        [Header("Settings")]
        [Tooltip("Automatically notify Flutter on scene load")]
        public bool notifyOnSceneLoad = true;

        [Tooltip("Automatically notify Flutter on scene unload")]
        public bool notifyOnSceneUnload = true;

        protected override void SingletonAwake()
        {
            base.SingletonAwake();
            
            SceneManager.sceneLoaded += OnSceneLoaded;
            SceneManager.sceneUnloaded += OnSceneUnloaded;
            
            Debug.Log("FlutterSceneManager singleton initialized");
        }

        protected override void OnDestroy()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
            SceneManager.sceneUnloaded -= OnSceneUnloaded;
            
            base.OnDestroy();
        }

        private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            if (notifyOnSceneLoad)
            {
                Debug.Log($"FlutterSceneManager: Scene loaded - {scene.name} (Index: {scene.buildIndex})");
                FlutterBridge.Instance.NotifySceneLoaded(scene.name, scene.buildIndex);
            }
        }

        private void OnSceneUnloaded(Scene scene)
        {
            if (notifyOnSceneUnload)
            {
                Debug.Log($"FlutterSceneManager: Scene unloaded - {scene.name}");
                FlutterBridge.Instance.SendToFlutter("SceneManager", "onSceneUnloaded", scene.name);
            }
        }

        /// <summary>
        /// Load a scene by name
        /// Can be called from Flutter
        /// </summary>
        public void LoadScene(string sceneName)
        {
            try
            {
                SceneManager.LoadScene(sceneName);
            }
            catch (System.Exception e)
            {
                Debug.LogError($"Failed to load scene {sceneName}: {e.Message}");
                FlutterBridge.Instance.SendError($"Failed to load scene: {e.Message}");
            }
        }

        /// <summary>
        /// Load a scene by index
        /// Can be called from Flutter
        /// </summary>
        public void LoadSceneByIndex(string indexStr)
        {
            if (int.TryParse(indexStr, out int index))
            {
                try
                {
                    SceneManager.LoadScene(index);
                }
                catch (System.Exception e)
                {
                    Debug.LogError($"Failed to load scene at index {index}: {e.Message}");
                    FlutterBridge.Instance.SendError($"Failed to load scene: {e.Message}");
                }
            }
        }

        /// <summary>
        /// Load a scene asynchronously
        /// Can be called from Flutter
        /// </summary>
        public void LoadSceneAsync(string sceneName)
        {
            StartCoroutine(LoadSceneAsyncCoroutine(sceneName));
        }

        private System.Collections.IEnumerator LoadSceneAsyncCoroutine(string sceneName)
        {
            AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(sceneName);

            while (!asyncLoad.isDone)
            {
                float progress = asyncLoad.progress;
                FlutterBridge.Instance.SendToFlutter("SceneManager", "onSceneLoadProgress", progress.ToString());
                yield return null;
            }
        }
    }
}
