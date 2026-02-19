using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using Xraph.GameFramework.Unity;

namespace GameFrameworkTemplate
{
    /// <summary>
    /// Demonstrates scene management with Flutter.
    /// 
    /// Features:
    /// - Load/unload scenes
    /// - Scene transition events
    /// - Async loading with progress
    /// - Multi-scene management
    /// 
    /// Flutter usage:
    /// ```dart
    /// // Load a scene
    /// await controller.sendJsonMessage('SceneController', 'loadScene', {
    ///   'sceneName': 'GameScene',
    ///   'mode': 'single', // or 'additive'
    /// });
    /// 
    /// // Load with progress tracking
    /// await controller.sendJsonMessage('SceneController', 'loadSceneAsync', {
    ///   'sceneName': 'GameScene',
    ///   'showProgress': true,
    /// });
    /// 
    /// // Listen for scene events
    /// controller.messageStream.listen((msg) {
    ///   switch (msg.method) {
    ///     case 'onSceneLoading':
    ///       // Scene started loading
    ///       break;
    ///     case 'onSceneProgress':
    ///       final progress = jsonDecode(msg.data)['progress'];
    ///       break;
    ///     case 'onSceneLoaded':
    ///       // Scene fully loaded
    ///       break;
    ///   }
    /// });
    /// ```
    /// </summary>
    public class SceneController : FlutterMonoBehaviour
    {
        protected override string TargetName => "SceneController";
        protected override bool IsSingleton => true;

        [Header("Scene Settings")]
        [SerializeField] private float minLoadingTime = 0.5f;
        [SerializeField] private bool notifyFlutterOnLoad = true;

        private bool _isLoading = false;
        private string _currentlyLoadingScene;

        protected override void Awake()
        {
            base.Awake();

            // Subscribe to Unity scene events
            SceneManager.sceneLoaded += OnSceneLoaded;
            SceneManager.sceneUnloaded += OnSceneUnloaded;
            SceneManager.activeSceneChanged += OnActiveSceneChanged;
        }

        protected override void OnDestroy()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
            SceneManager.sceneUnloaded -= OnSceneUnloaded;
            SceneManager.activeSceneChanged -= OnActiveSceneChanged;

            base.OnDestroy();
        }

        #region Scene Loading

        /// <summary>
        /// Load a scene synchronously.
        /// </summary>
        [FlutterMethod("loadScene")]
        public void LoadScene(SceneLoadRequest request)
        {
            if (_isLoading)
            {
                SendToFlutter("onSceneError", new SceneErrorEvent
                {
                    sceneName = request.sceneName,
                    error = "Another scene is currently loading"
                });
                return;
            }

            Debug.Log($"[SceneController] Loading scene: {request.sceneName}");

            try
            {
                _isLoading = true;
                _currentlyLoadingScene = request.sceneName;

                LoadSceneMode mode = request.mode == "additive" 
                    ? LoadSceneMode.Additive 
                    : LoadSceneMode.Single;

                SendToFlutter("onSceneLoading", new SceneLoadingEvent
                {
                    sceneName = request.sceneName,
                    mode = request.mode ?? "single"
                });

                SceneManager.LoadScene(request.sceneName, mode);
            }
            catch (Exception e)
            {
                _isLoading = false;
                SendToFlutter("onSceneError", new SceneErrorEvent
                {
                    sceneName = request.sceneName,
                    error = e.Message
                });
            }
        }

        /// <summary>
        /// Load a scene asynchronously with progress reporting.
        /// </summary>
        [FlutterMethod("loadSceneAsync")]
        public void LoadSceneAsync(AsyncSceneLoadRequest request)
        {
            if (_isLoading)
            {
                SendToFlutter("onSceneError", new SceneErrorEvent
                {
                    sceneName = request.sceneName,
                    error = "Another scene is currently loading"
                });
                return;
            }

            StartCoroutine(LoadSceneAsyncCoroutine(request));
        }

        private IEnumerator LoadSceneAsyncCoroutine(AsyncSceneLoadRequest request)
        {
            _isLoading = true;
            _currentlyLoadingScene = request.sceneName;

            Debug.Log($"[SceneController] Async loading: {request.sceneName}");

            SendToFlutter("onSceneLoading", new SceneLoadingEvent
            {
                sceneName = request.sceneName,
                mode = request.mode ?? "single",
                isAsync = true
            });

            LoadSceneMode mode = request.mode == "additive" 
                ? LoadSceneMode.Additive 
                : LoadSceneMode.Single;

            AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(request.sceneName, mode);
            asyncLoad.allowSceneActivation = !request.waitForActivation;

            float startTime = Time.time;

            while (!asyncLoad.isDone)
            {
                // Calculate progress (Unity reports 0-0.9, then jumps to 1)
                float progress = Mathf.Clamp01(asyncLoad.progress / 0.9f);

                if (request.showProgress)
                {
                    SendToFlutter("onSceneProgress", new SceneProgressEvent
                    {
                        sceneName = request.sceneName,
                        progress = progress,
                        elapsedTime = Time.time - startTime
                    });
                }

                // Wait for minimum loading time if set
                if (asyncLoad.progress >= 0.9f && request.waitForActivation)
                {
                    float elapsed = Time.time - startTime;
                    if (elapsed < minLoadingTime)
                    {
                        yield return new WaitForSeconds(minLoadingTime - elapsed);
                    }
                    asyncLoad.allowSceneActivation = true;
                }

                yield return null;
            }

            // Final progress update
            if (request.showProgress)
            {
                SendToFlutter("onSceneProgress", new SceneProgressEvent
                {
                    sceneName = request.sceneName,
                    progress = 1f,
                    elapsedTime = Time.time - startTime
                });
            }

            _isLoading = false;
        }

        /// <summary>
        /// Unload a scene.
        /// </summary>
        [FlutterMethod("unloadScene")]
        public void UnloadScene(SceneUnloadRequest request)
        {
            Debug.Log($"[SceneController] Unloading: {request.sceneName}");

            try
            {
                SendToFlutter("onSceneUnloading", new { sceneName = request.sceneName });
                SceneManager.UnloadSceneAsync(request.sceneName);
            }
            catch (Exception e)
            {
                SendToFlutter("onSceneError", new SceneErrorEvent
                {
                    sceneName = request.sceneName,
                    error = e.Message
                });
            }
        }

        #endregion

        #region Scene Queries

        /// <summary>
        /// Get list of all loaded scenes.
        /// </summary>
        [FlutterMethod("getLoadedScenes")]
        public void GetLoadedScenes()
        {
            var scenes = new List<SceneInfo>();

            for (int i = 0; i < SceneManager.sceneCount; i++)
            {
                Scene scene = SceneManager.GetSceneAt(i);
                scenes.Add(new SceneInfo
                {
                    name = scene.name,
                    buildIndex = scene.buildIndex,
                    isLoaded = scene.isLoaded,
                    isActive = scene == SceneManager.GetActiveScene(),
                    rootCount = scene.rootCount
                });
            }

            SendToFlutter("onLoadedScenes", new LoadedScenesResponse
            {
                scenes = scenes.ToArray(),
                activeScene = SceneManager.GetActiveScene().name
            });
        }

        /// <summary>
        /// Get list of all scenes in build.
        /// </summary>
        [FlutterMethod("getBuildScenes")]
        public void GetBuildScenes()
        {
            var scenes = new List<string>();

            for (int i = 0; i < SceneManager.sceneCountInBuildSettings; i++)
            {
                string path = SceneUtility.GetScenePathByBuildIndex(i);
                string name = System.IO.Path.GetFileNameWithoutExtension(path);
                scenes.Add(name);
            }

            SendToFlutter("onBuildScenes", new BuildScenesResponse
            {
                scenes = scenes.ToArray(),
                count = scenes.Count
            });
        }

        /// <summary>
        /// Get current active scene info.
        /// </summary>
        [FlutterMethod("getActiveScene")]
        public void GetActiveScene()
        {
            Scene active = SceneManager.GetActiveScene();

            SendToFlutter("onActiveScene", new SceneInfo
            {
                name = active.name,
                buildIndex = active.buildIndex,
                isLoaded = active.isLoaded,
                isActive = true,
                rootCount = active.rootCount
            });
        }

        /// <summary>
        /// Set active scene.
        /// </summary>
        [FlutterMethod("setActiveScene")]
        public void SetActiveScene(SetActiveSceneRequest request)
        {
            Scene scene = SceneManager.GetSceneByName(request.sceneName);
            
            if (scene.isLoaded)
            {
                SceneManager.SetActiveScene(scene);
                SendToFlutter("onActiveSceneSet", new { sceneName = request.sceneName, success = true });
            }
            else
            {
                SendToFlutter("onSceneError", new SceneErrorEvent
                {
                    sceneName = request.sceneName,
                    error = "Scene is not loaded"
                });
            }
        }

        #endregion

        #region Scene Events

        private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            _isLoading = false;

            Debug.Log($"[SceneController] Scene loaded: {scene.name} (mode: {mode})");

            if (notifyFlutterOnLoad)
            {
                SendToFlutter("onSceneLoaded", new SceneLoadedEvent
                {
                    sceneName = scene.name,
                    buildIndex = scene.buildIndex,
                    mode = mode == LoadSceneMode.Additive ? "additive" : "single",
                    isActive = scene == SceneManager.GetActiveScene()
                });
            }

            // Also notify via FlutterBridge
            FlutterBridge.Instance?.NotifySceneLoaded(scene.name, scene.buildIndex);
        }

        private void OnSceneUnloaded(Scene scene)
        {
            Debug.Log($"[SceneController] Scene unloaded: {scene.name}");

            SendToFlutter("onSceneUnloaded", new { sceneName = scene.name });
        }

        private void OnActiveSceneChanged(Scene previousScene, Scene newScene)
        {
            Debug.Log($"[SceneController] Active scene changed: {previousScene.name} -> {newScene.name}");

            SendToFlutter("onActiveSceneChanged", new ActiveSceneChangedEvent
            {
                previousScene = previousScene.name,
                newScene = newScene.name
            });
        }

        #endregion

        #region Data Types

        [Serializable]
        public class SceneLoadRequest
        {
            public string sceneName;
            public string mode; // "single" or "additive"
        }

        [Serializable]
        public class AsyncSceneLoadRequest
        {
            public string sceneName;
            public string mode;
            public bool showProgress;
            public bool waitForActivation;
        }

        [Serializable]
        public class SceneUnloadRequest
        {
            public string sceneName;
        }

        [Serializable]
        public class SetActiveSceneRequest
        {
            public string sceneName;
        }

        [Serializable]
        public class SceneLoadingEvent
        {
            public string sceneName;
            public string mode;
            public bool isAsync;
        }

        [Serializable]
        public class SceneProgressEvent
        {
            public string sceneName;
            public float progress;
            public float elapsedTime;
        }

        [Serializable]
        public class SceneLoadedEvent
        {
            public string sceneName;
            public int buildIndex;
            public string mode;
            public bool isActive;
        }

        [Serializable]
        public class SceneErrorEvent
        {
            public string sceneName;
            public string error;
        }

        [Serializable]
        public class ActiveSceneChangedEvent
        {
            public string previousScene;
            public string newScene;
        }

        [Serializable]
        public class SceneInfo
        {
            public string name;
            public int buildIndex;
            public bool isLoaded;
            public bool isActive;
            public int rootCount;
        }

        [Serializable]
        public class LoadedScenesResponse
        {
            public SceneInfo[] scenes;
            public string activeScene;
        }

        [Serializable]
        public class BuildScenesResponse
        {
            public string[] scenes;
            public int count;
        }

        #endregion
    }
}
