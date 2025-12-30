using UnityEngine;

namespace Xraph.GameFramework.Unity
{
    /// <summary>
    /// Singleton MonoBehaviour pattern for Unity
    /// 
    /// Ensures only one instance of the component exists across scenes.
    /// Based on flutter-unity-view-widget pattern.
    /// 
    /// Usage:
    /// <code>
    /// public class MyManager : SingletonMonoBehaviour<MyManager>
    /// {
    ///     protected override void SingletonAwake()
    ///     {
    ///         // Your initialization code
    ///     }
    /// }
    /// 
    /// // Access anywhere:
    /// MyManager.Instance.DoSomething();
    /// </code>
    /// </summary>
    /// <typeparam name="T">The type of the singleton</typeparam>
    public abstract class SingletonMonoBehaviour<T> : MonoBehaviour where T : MonoBehaviour
    {
        private static T _instance;
        private static object _lock = new object();
        private static bool _applicationIsQuitting = false;

        /// <summary>
        /// Gets the singleton instance
        /// </summary>
        public static T Instance
        {
            get
            {
                if (_applicationIsQuitting)
                {
                    Debug.LogWarning($"[Singleton] Instance '{typeof(T)}' already destroyed on application quit. Won't create again - returning null.");
                    return null;
                }

                lock (_lock)
                {
                    if (_instance == null)
                    {
                        _instance = (T)FindObjectOfType(typeof(T));

                        if (FindObjectsOfType(typeof(T)).Length > 1)
                        {
                            Debug.LogError($"[Singleton] Something went really wrong - there should never be more than 1 singleton! Reopening the scene might fix it.");
                            return _instance;
                        }

                        if (_instance == null)
                        {
                            GameObject singleton = new GameObject();
                            _instance = singleton.AddComponent<T>();
                            singleton.name = $"(singleton) {typeof(T)}";

                            DontDestroyOnLoad(singleton);

                            Debug.Log($"[Singleton] An instance of {typeof(T)} is needed in the scene, so '{singleton}' was created with DontDestroyOnLoad.");
                        }
                        else
                        {
                            Debug.Log($"[Singleton] Using instance already created: {_instance.gameObject.name}");
                        }
                    }

                    return _instance;
                }
            }
        }

        /// <summary>
        /// Check if singleton instance exists
        /// </summary>
        public static bool HasInstance
        {
            get { return _instance != null; }
        }

        /// <summary>
        /// Unity Awake - handles singleton logic
        /// Override SingletonAwake() instead of this method
        /// </summary>
        protected virtual void Awake()
        {
            if (_instance == null)
            {
                _instance = this as T;
                DontDestroyOnLoad(gameObject);
                
                Debug.Log($"[Singleton] {typeof(T)} initialized");
                
                // Call the derived class's initialization
                SingletonAwake();
            }
            else if (_instance != this)
            {
                Debug.LogWarning($"[Singleton] Duplicate instance of {typeof(T)} detected. Destroying {gameObject.name}");
                Destroy(gameObject);
            }
        }

        /// <summary>
        /// Override this method instead of Awake() in derived classes
        /// </summary>
        protected virtual void SingletonAwake()
        {
            // Derived classes can override this
        }

        /// <summary>
        /// When Unity quits, it destroys objects in a random order.
        /// In principle, a Singleton is only destroyed when application quits.
        /// If any script calls Instance after it has been destroyed, 
        /// it will create a buggy ghost object that will stay on the Editor scene
        /// even after stopping playing the Application. Really bad!
        /// So, this was made to be sure we're not creating that buggy ghost object.
        /// </summary>
        protected virtual void OnDestroy()
        {
            if (_instance == this)
            {
                _applicationIsQuitting = true;
            }
        }

        /// <summary>
        /// Reset application quitting flag when application is focused
        /// </summary>
        protected virtual void OnApplicationFocus(bool hasFocus)
        {
            if (hasFocus)
            {
                _applicationIsQuitting = false;
            }
        }
    }
}

