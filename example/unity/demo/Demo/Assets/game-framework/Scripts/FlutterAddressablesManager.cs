using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

#if ADDRESSABLES_INSTALLED
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.ResourceManagement.ResourceLocations;
#endif

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Runtime manager for loading Addressable assets from Flutter.
    /// Handles cache path configuration, asset loading, and progress reporting.
    /// </summary>
    public class FlutterAddressablesManager : SingletonMonoBehaviour<FlutterAddressablesManager>
    {
        [Header("Configuration")]
        [Tooltip("Enable debug logging")]
        public bool enableDebugLogging = false;
        
        [Tooltip("Custom cache path set by Flutter")]
        private string _cachePath;
        
        [Tooltip("Whether the manager is initialized")]
        private bool _isInitialized = false;
        
        // Track loaded assets for cleanup
        private Dictionary<string, object> _loadedAssets = new Dictionary<string, object>();
        private Dictionary<string, AsyncOperationHandle> _activeOperations = new Dictionary<string, AsyncOperationHandle>();
        
        protected override void SingletonAwake()
        {
            base.SingletonAwake();
            
            // Register message handlers
            RegisterMessageHandlers();
            
            Log("FlutterAddressablesManager initialized");
        }
        
        /// <summary>
        /// Register handlers for Flutter messages
        /// </summary>
        private void RegisterMessageHandlers()
        {
            // These handlers will be called via FlutterBridge
            UnityMessageManager.Instance.AddEventListener("Addressables:SetCachePath", (data) =>
            {
                SetCachePath(data.ToString());
            });
            
            UnityMessageManager.Instance.AddEventListener("Addressables:LoadAsset", (data) =>
            {
                var json = data.ToString();
                var request = JsonUtility.FromJson<LoadAssetRequest>(json);
                LoadAssetAsync(request.addressableKey, request.callbackId);
            });
            
            UnityMessageManager.Instance.AddEventListener("Addressables:LoadScene", (data) =>
            {
                var json = data.ToString();
                var request = JsonUtility.FromJson<LoadSceneRequest>(json);
                LoadSceneAsync(request.sceneName, request.callbackId, request.loadMode);
            });
            
            UnityMessageManager.Instance.AddEventListener("Addressables:UnloadAsset", (data) =>
            {
                UnloadAsset(data.ToString());
            });
            
            UnityMessageManager.Instance.AddEventListener("Addressables:UpdateCatalog", (data) =>
            {
                UpdateCatalog(data.ToString());
            });
            
            UnityMessageManager.Instance.AddEventListener("Addressables:GetLoadedAssets", (data) =>
            {
                SendLoadedAssetsList();
            });
        }
        
        /// <summary>
        /// Set the cache path where Flutter has downloaded assets
        /// </summary>
        public void SetCachePath(string cachePath)
        {
            Log($"Setting cache path: {cachePath}");
            _cachePath = cachePath;
            
#if ADDRESSABLES_INSTALLED
            // Configure Addressables to load from the cache path
            Addressables.InternalIdTransformFunc = TransformInternalId;
#endif
            
            _isInitialized = true;
            
            // Notify Flutter that initialization is complete
            FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onCachePathSet", new CachePathResponse
            {
                success = true,
                cachePath = cachePath
            });
        }
        
#if ADDRESSABLES_INSTALLED
        /// <summary>
        /// Transform addressable internal IDs to use cached files
        /// </summary>
        private string TransformInternalId(IResourceLocation location)
        {
            // If this is a remote URL and we have a cache path, try to use local cached file
            if (!string.IsNullOrEmpty(_cachePath) && location.InternalId.StartsWith("http"))
            {
                var bundleName = Path.GetFileName(location.InternalId);
                var localPath = Path.Combine(_cachePath, bundleName);
                
                if (File.Exists(localPath))
                {
                    Log($"Using cached bundle: {localPath}");
                    return localPath;
                }
                else
                {
                    Log($"Cache miss for: {bundleName}");
                }
            }
            
            return location.InternalId;
        }
#endif
        
        /// <summary>
        /// Load an addressable asset asynchronously
        /// </summary>
        public void LoadAssetAsync(string addressableKey, string callbackId)
        {
            Log($"Loading asset: {addressableKey} (callback: {callbackId})");
            
#if ADDRESSABLES_INSTALLED
            StartCoroutine(LoadAssetCoroutine<UnityEngine.Object>(addressableKey, callbackId));
#else
            SendError(callbackId, "Addressables not installed");
#endif
        }
        
        /// <summary>
        /// Load an addressable asset with type
        /// </summary>
        public void LoadAssetAsync<T>(string addressableKey, string callbackId) where T : UnityEngine.Object
        {
            Log($"Loading typed asset: {addressableKey} (type: {typeof(T).Name}, callback: {callbackId})");
            
#if ADDRESSABLES_INSTALLED
            StartCoroutine(LoadAssetCoroutine<T>(addressableKey, callbackId));
#else
            SendError(callbackId, "Addressables not installed");
#endif
        }
        
#if ADDRESSABLES_INSTALLED
        private IEnumerator LoadAssetCoroutine<T>(string addressableKey, string callbackId) where T : UnityEngine.Object
        {
            var handle = Addressables.LoadAssetAsync<T>(addressableKey);
            _activeOperations[callbackId] = handle;
            
            // Report progress
            while (!handle.IsDone)
            {
                SendProgress(callbackId, addressableKey, handle.PercentComplete);
                yield return null;
            }
            
            _activeOperations.Remove(callbackId);
            
            if (handle.Status == AsyncOperationStatus.Succeeded)
            {
                _loadedAssets[addressableKey] = handle.Result;
                
                SendSuccess(callbackId, addressableKey, new AssetLoadedResponse
                {
                    addressableKey = addressableKey,
                    assetType = handle.Result.GetType().Name,
                    success = true
                });
            }
            else
            {
                SendError(callbackId, $"Failed to load asset: {addressableKey}");
            }
        }
#endif
        
        /// <summary>
        /// Load an addressable scene asynchronously
        /// </summary>
        public void LoadSceneAsync(string sceneName, string callbackId, string loadMode = "Single")
        {
            Log($"Loading scene: {sceneName} (mode: {loadMode}, callback: {callbackId})");
            
#if ADDRESSABLES_INSTALLED
            var sceneLoadMode = loadMode == "Additive" ? LoadSceneMode.Additive : LoadSceneMode.Single;
            StartCoroutine(LoadSceneCoroutine(sceneName, callbackId, sceneLoadMode));
#else
            SendError(callbackId, "Addressables not installed");
#endif
        }
        
#if ADDRESSABLES_INSTALLED
        private IEnumerator LoadSceneCoroutine(string sceneName, string callbackId, LoadSceneMode loadMode)
        {
            var handle = Addressables.LoadSceneAsync(sceneName, loadMode);
            _activeOperations[callbackId] = handle;
            
            // Report progress
            while (!handle.IsDone)
            {
                SendProgress(callbackId, sceneName, handle.PercentComplete);
                yield return null;
            }
            
            _activeOperations.Remove(callbackId);
            
            if (handle.Status == AsyncOperationStatus.Succeeded)
            {
                SendSuccess(callbackId, sceneName, new SceneLoadedResponse
                {
                    sceneName = sceneName,
                    success = true
                });
            }
            else
            {
                SendError(callbackId, $"Failed to load scene: {sceneName}");
            }
        }
#endif
        
        /// <summary>
        /// Unload a previously loaded asset
        /// </summary>
        public void UnloadAsset(string addressableKey)
        {
            Log($"Unloading asset: {addressableKey}");
            
#if ADDRESSABLES_INSTALLED
            if (_loadedAssets.TryGetValue(addressableKey, out var asset))
            {
                Addressables.Release(asset);
                _loadedAssets.Remove(addressableKey);
                
                FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onAssetUnloaded", addressableKey);
            }
#endif
        }
        
        /// <summary>
        /// Update the addressables catalog from a URL
        /// </summary>
        public void UpdateCatalog(string catalogUrl)
        {
            Log($"Updating catalog from: {catalogUrl}");
            
#if ADDRESSABLES_INSTALLED
            StartCoroutine(UpdateCatalogCoroutine(catalogUrl));
#else
            FlutterBridge.Instance.SendError("Addressables not installed");
#endif
        }
        
#if ADDRESSABLES_INSTALLED
        private IEnumerator UpdateCatalogCoroutine(string catalogUrl)
        {
            var checkHandle = Addressables.CheckForCatalogUpdates(false);
            yield return checkHandle;
            
            if (checkHandle.Status == AsyncOperationStatus.Succeeded && checkHandle.Result.Count > 0)
            {
                var updateHandle = Addressables.UpdateCatalogs(checkHandle.Result, false);
                yield return updateHandle;
                
                if (updateHandle.Status == AsyncOperationStatus.Succeeded)
                {
                    FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onCatalogUpdated", new CatalogUpdateResponse
                    {
                        success = true,
                        updatedCatalogs = checkHandle.Result.Count
                    });
                }
                else
                {
                    FlutterBridge.Instance.SendError("Failed to update catalogs");
                }
                
                Addressables.Release(updateHandle);
            }
            else
            {
                FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onCatalogUpdated", new CatalogUpdateResponse
                {
                    success = true,
                    updatedCatalogs = 0,
                    message = "No updates available"
                });
            }
            
            Addressables.Release(checkHandle);
        }
#endif
        
        /// <summary>
        /// Send list of currently loaded assets to Flutter
        /// </summary>
        private void SendLoadedAssetsList()
        {
            var assetList = new List<string>(_loadedAssets.Keys);
            FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onLoadedAssetsList", new LoadedAssetsResponse
            {
                assets = assetList.ToArray()
            });
        }
        
        /// <summary>
        /// Cancel an active loading operation
        /// </summary>
        public void CancelOperation(string callbackId)
        {
#if ADDRESSABLES_INSTALLED
            if (_activeOperations.TryGetValue(callbackId, out var handle))
            {
                Addressables.Release(handle);
                _activeOperations.Remove(callbackId);
                Log($"Cancelled operation: {callbackId}");
            }
#endif
        }
        
        /// <summary>
        /// Release all loaded assets
        /// </summary>
        public void ReleaseAll()
        {
#if ADDRESSABLES_INSTALLED
            foreach (var asset in _loadedAssets.Values)
            {
                Addressables.Release(asset);
            }
            _loadedAssets.Clear();
            Log("Released all loaded assets");
#endif
        }
        
        protected override void OnDestroy()
        {
            ReleaseAll();
            base.OnDestroy();
        }
        
        // Helper methods for Flutter communication
        
        private void SendProgress(string callbackId, string key, float progress)
        {
            FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onProgress", new ProgressResponse
            {
                callbackId = callbackId,
                key = key,
                progress = progress
            });
        }
        
        private void SendSuccess<T>(string callbackId, string key, T response)
        {
            FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onSuccess", response);
        }
        
        private void SendError(string callbackId, string error)
        {
            FlutterBridge.Instance.SendToFlutter("FlutterAddressablesManager", "onError", new ErrorResponse
            {
                callbackId = callbackId,
                error = error
            });
        }
        
        private void Log(string message)
        {
            if (enableDebugLogging)
            {
                Debug.Log($"[FlutterAddressablesManager] {message}");
            }
        }
        
        // Request/Response classes for JSON serialization
        
        [Serializable]
        public class LoadAssetRequest
        {
            public string addressableKey;
            public string callbackId;
        }
        
        [Serializable]
        public class LoadSceneRequest
        {
            public string sceneName;
            public string callbackId;
            public string loadMode;
        }
        
        [Serializable]
        public class CachePathResponse
        {
            public bool success;
            public string cachePath;
        }
        
        [Serializable]
        public class AssetLoadedResponse
        {
            public string addressableKey;
            public string assetType;
            public bool success;
        }
        
        [Serializable]
        public class SceneLoadedResponse
        {
            public string sceneName;
            public bool success;
        }
        
        [Serializable]
        public class CatalogUpdateResponse
        {
            public bool success;
            public int updatedCatalogs;
            public string message;
        }
        
        [Serializable]
        public class LoadedAssetsResponse
        {
            public string[] assets;
        }
        
        [Serializable]
        public class ProgressResponse
        {
            public string callbackId;
            public string key;
            public float progress;
        }
        
        [Serializable]
        public class ErrorResponse
        {
            public string callbackId;
            public string error;
        }
    }
}
