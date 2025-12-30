# Singleton Pattern in Game Framework

## Overview

The Game Framework uses the **SingletonMonoBehaviour** pattern from [flutter-unity-view-widget](https://github.com/juicycleff/flutter-unity-view-widget/blob/master/example/unity/DemoApp/Assets/FlutterUnityIntegration/SingletonMonoBehaviour.cs) to ensure only one instance of key managers exists across scenes.

## SingletonMonoBehaviour Pattern

### What It Does

- **Ensures single instance**: Only one instance of the component exists
- **Persists across scenes**: Uses `DontDestroyOnLoad`
- **Auto-creates if missing**: Creates instance when first accessed
- **Thread-safe**: Uses lock for instance access
- **Prevents duplicates**: Automatically destroys duplicate instances
- **Application quit handling**: Prevents ghost objects on quit

### Base Class

```csharp
public abstract class SingletonMonoBehaviour<T> : MonoBehaviour where T : MonoBehaviour
{
    public static T Instance { get; }
    public static bool HasInstance { get; }
    
    protected virtual void SingletonAwake() { }
    // ... implementation
}
```

## Managers Using Singleton Pattern

### 1. UnityMessageManager

```csharp
public class UnityMessageManager : SingletonMonoBehaviour<UnityMessageManager>
```

**Purpose**: Centralized message routing for Unity-Flutter communication

**Usage**:
```csharp
UnityMessageManager.Instance.SendToFlutter("target", "method", data);
UnityMessageManager.Instance.AddEventListener("event", HandleEvent);
```

**Why Singleton**: 
- ✅ Single communication channel
- ✅ Consistent callback tracking
- ✅ Event listeners persist across scenes

### 2. FlutterGameManager

```csharp
public class FlutterGameManager : SingletonMonoBehaviour<FlutterGameManager>
```

**Purpose**: Example game state manager

**Usage**:
```csharp
FlutterGameManager.Instance.StartGame("level1");
FlutterGameManager.Instance.UpdateScore("100");
FlutterGameManager.Instance.PauseGame();
```

**Why Singleton**:
- ✅ Global game state
- ✅ Persists across scene transitions
- ✅ Single source of truth

### 3. FlutterSceneManager

```csharp
public class FlutterSceneManager : SingletonMonoBehaviour<FlutterSceneManager>
```

**Purpose**: Scene loading and event management

**Usage**:
```csharp
FlutterSceneManager.Instance.LoadScene("Level2");
FlutterSceneManager.Instance.LoadSceneAsync("Level3");
```

**Why Singleton**:
- ✅ Consistent scene event handling
- ✅ Works across scene changes
- ✅ No duplicate event subscriptions

## Creating Your Own Singleton

### Step 1: Inherit from SingletonMonoBehaviour

```csharp
using Xraph.GameFramework.Unity;

public class MyManager : SingletonMonoBehaviour<MyManager>
{
    // Your fields
    private int myData;
    
    // Override SingletonAwake instead of Awake
    protected override void SingletonAwake()
    {
        base.SingletonAwake();
        
        // Your initialization code
        myData = 0;
        Debug.Log("MyManager initialized");
    }
    
    // Your methods
    public void DoSomething()
    {
        Debug.Log("Doing something!");
    }
    
    // Override OnDestroy if needed
    protected override void OnDestroy()
    {
        // Your cleanup code
        
        base.OnDestroy();
    }
}
```

### Step 2: Access from Anywhere

```csharp
// In any script
MyManager.Instance.DoSomething();

// Check if instance exists
if (MyManager.HasInstance)
{
    MyManager.Instance.DoSomething();
}
```

### Step 3: No Manual GameObject Creation Needed

The singleton will automatically create itself when first accessed:

```csharp
// First access creates the singleton
MyManager.Instance.DoSomething();
// Creates: GameObject "(singleton) MyManager"
// With DontDestroyOnLoad applied
```

## Best Practices

### ✅ DO: Use for Managers and Global State

```csharp
// Good use cases
public class AudioManager : SingletonMonoBehaviour<AudioManager>
public class DataManager : SingletonMonoBehaviour<DataManager>
public class GameStateManager : SingletonMonoBehaviour<GameStateManager>
```

### ✅ DO: Override SingletonAwake for Initialization

```csharp
protected override void SingletonAwake()
{
    base.SingletonAwake();
    
    // Initialize here
    LoadConfiguration();
    SetupListeners();
}
```

### ✅ DO: Clean Up in OnDestroy

```csharp
protected override void OnDestroy()
{
    // Unsubscribe from events
    EventBus.Unsubscribe(OnEvent);
    
    base.OnDestroy();
}
```

### ✅ DO: Check HasInstance Before Optional Access

```csharp
if (MyManager.HasInstance)
{
    // Only call if instance exists
    MyManager.Instance.OptionalOperation();
}
```

### ❌ DON'T: Use for Scene-Specific Components

```csharp
// Bad - should be per-scene
public class LevelController : SingletonMonoBehaviour<LevelController>
public class PlayerController : SingletonMonoBehaviour<PlayerController>
```

Use regular MonoBehaviour for components that should exist per scene.

### ❌ DON'T: Override Awake Directly

```csharp
// Bad
void Awake()
{
    // This breaks singleton logic!
}

// Good
protected override void SingletonAwake()
{
    base.SingletonAwake();
    // Your initialization
}
```

### ❌ DON'T: Manually Destroy Singleton Instances

```csharp
// Bad
Destroy(MyManager.Instance.gameObject);

// Singletons manage their own lifecycle
```

## Advanced Patterns

### Optional Singleton

For managers that aren't always needed:

```csharp
public class OptionalManager : SingletonMonoBehaviour<OptionalManager>
{
    public void DoOptionalWork()
    {
        Debug.Log("Optional work");
    }
}

// Check before use
if (OptionalManager.HasInstance)
{
    OptionalManager.Instance.DoOptionalWork();
}
```

### Singleton with Dependencies

```csharp
public class DependentManager : SingletonMonoBehaviour<DependentManager>
{
    protected override void SingletonAwake()
    {
        base.SingletonAwake();
        
        // Access other singletons
        UnityMessageManager.Instance.AddEventListener("event", HandleEvent);
    }
    
    private void HandleEvent(string data)
    {
        Debug.Log($"Event received: {data}");
    }
}
```

### Lazy Initialization

```csharp
public class LazyManager : SingletonMonoBehaviour<LazyManager>
{
    private bool _initialized = false;
    
    protected override void SingletonAwake()
    {
        base.SingletonAwake();
        // Don't initialize here
    }
    
    public void EnsureInitialized()
    {
        if (!_initialized)
        {
            Initialize();
            _initialized = true;
        }
    }
    
    private void Initialize()
    {
        Debug.Log("Lazy initialization");
    }
}

// Use
LazyManager.Instance.EnsureInitialized();
```

## Lifecycle

### Creation
1. First `Instance` access
2. `SingletonMonoBehaviour` creates GameObject
3. Adds component
4. Calls `SingletonAwake()`
5. Applies `DontDestroyOnLoad`

### Scene Transitions
1. Scene unloads
2. Singleton persists (DontDestroyOnLoad)
3. New scene loads
4. Singleton still available

### Duplicate Detection
1. Duplicate instance created (e.g., in scene)
2. `Awake()` detects existing instance
3. Destroys duplicate GameObject
4. Logs warning

### Application Quit
1. Unity starts quitting
2. Objects destroyed in random order
3. `OnDestroy()` sets `_applicationIsQuitting = true`
4. Future `Instance` access returns null (no ghost objects)

## Debugging

### Check if Singleton Exists

```csharp
if (MyManager.HasInstance)
{
    Debug.Log("Singleton exists");
}
else
{
    Debug.Log("Singleton not yet created");
}
```

### Log Singleton State

```csharp
public class MyManager : SingletonMonoBehaviour<MyManager>
{
    protected override void SingletonAwake()
    {
        base.SingletonAwake();
        Debug.Log($"[{GetType().Name}] Singleton initialized");
    }
    
    protected override void OnDestroy()
    {
        Debug.Log($"[{GetType().Name}] Singleton destroyed");
        base.OnDestroy();
    }
}
```

### Find All Singletons

```csharp
// In editor or debug builds
var singletons = FindObjectsOfType<MonoBehaviour>()
    .Where(mb => mb.GetType().BaseType?.IsGenericType == true && 
                 mb.GetType().BaseType.GetGenericTypeDefinition() == typeof(SingletonMonoBehaviour<>))
    .ToList();

foreach (var singleton in singletons)
{
    Debug.Log($"Singleton: {singleton.GetType().Name} on {singleton.gameObject.name}");
}
```

## Comparison to Other Patterns

### vs Static Class
```csharp
// Static class - no Unity lifecycle
public static class MyStaticClass
{
    public static void DoWork() { }
}

// Singleton - full Unity lifecycle
public class MySingleton : SingletonMonoBehaviour<MySingleton>
{
    void Update() { } // Can use Update, Coroutines, etc.
}
```

### vs Manual Singleton
```csharp
// Manual singleton - error-prone
public class ManualSingleton : MonoBehaviour
{
    public static ManualSingleton Instance;
    
    void Awake()
    {
        if (Instance != null)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }
}

// SingletonMonoBehaviour - robust, tested, handles edge cases
public class RobustSingleton : SingletonMonoBehaviour<RobustSingleton>
{
    // Thread-safe, application quit handling, etc.
}
```

## References

- **flutter-unity-view-widget**: [SingletonMonoBehaviour.cs](https://github.com/juicycleff/flutter-unity-view-widget/blob/master/example/unity/DemoApp/Assets/FlutterUnityIntegration/SingletonMonoBehaviour.cs)
- **Unity Design Patterns**: Singleton pattern for MonoBehaviour
- **Game Framework**: Used by UnityMessageManager, FlutterGameManager, FlutterSceneManager

