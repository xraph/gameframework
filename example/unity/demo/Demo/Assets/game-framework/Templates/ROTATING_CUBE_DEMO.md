# 🎮 Interactive Rotating Cube Demo

An interactive 3D rotating cube demo showcasing bidirectional Flutter-Unity communication with a beautiful overlay UI.

## Features

### Unity Side
- ✨ **Procedurally generated 3D cube** with metallic material
- 🔄 **Real-time rotation** with customizable speed and axis
- 📊 **Live UI display** with 3 text fields:
  - **Speed**: Shows degrees/second and RPM
  - **Message**: Last message received
  - **Direction**: Communication flow indicator
- 🎨 **Color-coded indicators**:
  - Green: ← FROM FLUTTER
  - Orange: → TO FLUTTER
- 🌟 **Dynamic lighting** for visual appeal

### Flutter Side
- 🎯 **Beautiful overlay UI** that doesn't block Unity view
- 🎚️ **Speed slider** (-180° to 180°/second) with live preview
- 🔘 **Axis selector buttons** (X, Y, Z, All) with visual feedback
- 🎨 **Action buttons**:
  - Reset: Restore to defaults
  - Get State: Request current state
  - Random Color: Apply random cube color
- 📈 **Live info card** showing real-time stats
- 🌈 **Dark theme** with semi-transparent cards

## Setup

### Unity Setup

1. **Sync the template scripts:**
   ```bash
   game sync scripts --templates
   ```

2. **In Unity Editor:**
   - Create a new scene (or use existing)
   - Create an empty GameObject
   - Name it `GameFrameworkDemo`
   - Attach the `GameFrameworkDemo.cs` script
   - Press Play to test

The script automatically creates:
- The rotating cube with material
- Camera positioned to view the cube
- Directional light for proper lighting
- Canvas with 3 TextMeshPro UI elements

### Flutter Setup

The Flutter scaffold automatically includes the interactive UI:

```bash
# Create a new package with the demo
game scaffold --name my_game --engine unity --templates

# Or use in existing project
cd your_flutter_app/example
flutter run
```

The UI will overlay the Unity view with:
- Info card at the top showing status
- Control panel at the bottom
- Back button in top-left
- Loading indicator while Unity initializes

## Usage

### From Flutter

**Control rotation speed:**
```dart
// Set speed to 90°/s
controller.sendMessage('GameFrameworkDemo', 'setSpeed', '90.0');

// Stop rotation
controller.sendMessage('GameFrameworkDemo', 'setSpeed', '0');

// Reverse rotation
controller.sendMessage('GameFrameworkDemo', 'setSpeed', '-50.0');
```

**Change rotation axis:**
```dart
// Rotate around X axis
controller.sendJsonMessage('GameFrameworkDemo', 'setAxis', {
  'x': 1.0,
  'y': 0.0,
  'z': 0.0,
});

// Rotate around all axes
controller.sendJsonMessage('GameFrameworkDemo', 'setAxis', {
  'x': 1.0,
  'y': 1.0,
  'z': 1.0,
});
```

**Change cube color:**
```dart
// Set to blue
controller.sendJsonMessage('GameFrameworkDemo', 'setColor', {
  'r': 0.2,
  'g': 0.4,
  'b': 1.0,
  'a': 1.0,
});
```

**Reset everything:**
```dart
controller.sendMessage('GameFrameworkDemo', 'reset', '');
```

**Get current state:**
```dart
controller.sendMessage('GameFrameworkDemo', 'getState', '');

// Listen for response
controller.messageStream.listen((msg) {
  if (msg.method == 'onState') {
    final state = msg.data as Map<String, dynamic>;
    print('Speed: ${state['speed']}');
    print('RPM: ${state['rpm']}');
    print('Message count: ${state['messageCount']}');
  }
});
```

### From Unity (Sending to Flutter)

The demo automatically sends updates:

```csharp
// Send speed confirmation
SendToFlutter("onSpeedChanged", new SpeedData {
    speed = _rotationSpeed,
    rpm = (_rotationSpeed / 360f) * 60f
});

// Send reset confirmation
SendToFlutter("onReset", new { success = true });

// Send complete state
SendToFlutter("onState", new CubeState {
    speed = _rotationSpeed,
    rpm = (_rotationSpeed / 360f) * 60f,
    axis = new AxisData { x = _rotationAxis.x, y = _rotationAxis.y, z = _rotationAxis.z },
    rotation = new Vector3Data { x = eulerAngles.x, y = eulerAngles.y, z = eulerAngles.z },
    messageCount = _messageCount
});
```

## UI Components

### Unity UI Elements

The demo creates 3 TextMeshPro UI elements:

1. **Speed Display** (Yellow/Bold)
   - Format: "Speed: {rpm} RPM ({degrees}°/s)"
   - Updates every frame
   - Example: "Speed: 8.3 RPM (50°/s)"

2. **Message Display** (White)
   - Shows last message content
   - Example: "Message: Speed changed to 90°/s"

3. **Direction Display** (Green/Orange/Bold)
   - Shows communication flow
   - Green when receiving from Flutter
   - Orange when sending to Flutter
   - Example: "Direction: ← FROM FLUTTER"

### Flutter Overlay UI

**Top Info Card** (Semi-transparent black):
```
┌─────────────────────────────────────┐
│ 🏃 Speed    50°/s (8.3 RPM)         │
│ ──────────────────────────────────  │
│ 💬 Message  Speed changed            │
│ ──────────────────────────────────  │
│ ➡️  Direction → TO UNITY             │
└─────────────────────────────────────┘
```

**Bottom Control Panel** (Semi-transparent black):
```
┌─────────────────────────────────────┐
│         🎮 Cube Controls            │
│                                      │
│ 🔄 Rotation Speed         [50°/s]   │
│ ━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━     │
│                                      │
│ 🔁 Rotation Axis                    │
│ [X] [Y✓] [Z] [All]                  │
│                                      │
│ [🔄 Reset] [📊 State] [🎨 Color]    │
└─────────────────────────────────────┘
```

## Customization

### Unity Customization

Edit `GameFrameworkDemo.cs`:

```csharp
[Header("Cube Configuration")]
[SerializeField] private float initialSpeed = 100f;  // Change default speed
[SerializeField] private Color cubeColor = Color.red; // Change cube color

[Header("UI Configuration")]
[SerializeField] private bool verboseLogging = false; // Disable logs
```

### Flutter Customization

Edit the scaffold example `main.dart`:

```dart
// Change speed range
_buildSliderControl(
  'Rotation Speed',
  _rotationSpeed,
  -360,  // Change from -180
  360,   // Change from 180
  (value) => _sendSpeed(value),
  Icons.threesixty,
),

// Add more axis options
_buildAxisButton('XY', Colors.cyan),
_buildAxisButton('YZ', Colors.magenta),

// Change theme colors
Card(
  color: Colors.blue.withOpacity(0.9),  // Change card color
  ...
)
```

## Advanced Usage

### Add More Interactive Elements

**Unity side - Add a sphere:**
```csharp
private GameObject _sphere;

void Start()
{
    CreateCube();
    CreateSphere();
    CreateUI();
}

private void CreateSphere()
{
    _sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
    _sphere.transform.position = new Vector3(3, 0, 0);
    _sphere.transform.localScale = Vector3.one * 1.5f;
}

[FlutterMethod("moveSphere")]
private void MoveSphere(string data)
{
    var pos = FlutterSerialization.Deserialize<Vector3Data>(data);
    _sphere.transform.position = new Vector3(pos.x, pos.y, pos.z);
}
```

**Flutter side - Add joystick:**
```dart
// In control panel
_buildJoystick(
  onChanged: (dx, dy) {
    controller.sendJsonMessage('GameFrameworkDemo', 'moveSphere', {
      'x': dx * 5,
      'y': 0,
      'z': dy * 5,
    });
  },
)
```

### Performance Monitoring

Enable performance monitoring to track communication overhead:

```csharp
[Header("Performance")]
[SerializeField] private bool enablePerformanceMonitoring = true;

private int _messagesPerSecond = 0;
private float _messageTimer = 0f;

void Update()
{
    _messageTimer += Time.deltaTime;
    if (_messageTimer >= 1f)
    {
        SendToFlutter("onPerformance", new {
            messagesPerSecond = _messagesPerSecond,
            fps = 1f / Time.deltaTime
        });
        _messagesPerSecond = 0;
        _messageTimer = 0f;
    }
}
```

## Troubleshooting

### Cube Not Visible

**Issue:** Black screen, no cube visible

**Solutions:**
1. Check camera position: `transform.position = new Vector3(0, 2, -6)`
2. Ensure cube is at origin: `transform.position = Vector3.zero`
3. Check lighting: Add directional light if missing
4. Verify shader: Use "Standard" or "Universal Render Pipeline/Lit"

### UI Not Showing

**Issue:** Text fields not visible in Unity

**Solutions:**
1. **Import TextMeshPro:** Window → TextMeshPro → Import TMP Essential Resources
2. Check canvas render mode: Should be `ScreenSpaceOverlay`
3. Verify sorting order: Canvas should have `sortingOrder = 100`
4. Check text alpha: Ensure color has alpha = 1.0

### Flutter Overlay Not Working

**Issue:** Flutter controls not visible

**Solutions:**
1. Ensure `Stack` widget is used (not Column)
2. Check `Positioned` widget bounds
3. Verify background transparency: `backgroundColor: Colors.transparent`
4. Test on device (overlays may not render in some emulators)

### Messages Not Received

**Issue:** Button clicks don't affect cube

**Solutions:**
1. Check GameObject name matches: "GameFrameworkDemo"
2. Verify script is attached to GameObject
3. Enable debug logging: `verboseLogging = true`
4. Check Unity Console for errors
5. Verify `MessageRouter` is in scene (automatically created)

## Performance Tips

1. **Use batching for frequent updates:**
   ```csharp
   protected override void ConfigureRouting()
   {
       EnableBatching = true;
   }
   ```

2. **Throttle high-frequency messages:**
   ```csharp
   [FlutterMethod("updatePosition", Throttle = 60)] // 60 Hz max
   private void UpdatePosition(string data) { }
   ```

3. **Use delta compression for state sync:**
   ```csharp
   protected override void ConfigureRouting()
   {
       EnableDeltaCompression = true;
   }
   ```

## What's Next?

After getting familiar with the rotating cube demo, explore other templates:

- **`MessagingExample.cs`** - Learn different messaging patterns
- **`BinaryDataExample.cs`** - Transfer images and binary data
- **`StateManager.cs`** - Synchronize game state efficiently
- **`SceneController.cs`** - Manage multiple Unity scenes
- **`HighFrequencyDemo.cs`** - Test performance limits

## Demo Showcase

### What You Can Do

1. **Adjust Speed**: Slide to change rotation from -180 to 180 °/s
2. **Change Axis**: Tap X, Y, Z, or All for different rotations
3. **Random Colors**: Make the cube colorful with random colors
4. **View Stats**: Watch the info card update in real-time
5. **Reset**: Return to initial state instantly
6. **Get State**: Request full state data from Unity

### Expected Behavior

**When you move the speed slider:**
- Flutter UI updates immediately (smooth)
- Message sent to Unity: `setSpeed`
- Unity receives and applies speed
- Unity sends confirmation: `onSpeedChanged`
- Info card updates with new values
- Direction shows "← FROM FLUTTER" then "→ TO UNITY"

**When cube rotates:**
- Smooth 60 FPS rotation in Unity
- UI updates every frame showing current speed
- No lag or stuttering
- Messages are efficiently batched

## Code Quality

This demo demonstrates production-ready practices:

✅ **Proper inheritance** from `FlutterMonoBehaviour`  
✅ **Declarative routing** with `[FlutterMethod]` attributes  
✅ **Type-safe serialization** with data classes  
✅ **Error handling** with try-catch blocks  
✅ **Resource cleanup** in `OnDestroy`  
✅ **Performance optimizations** (batching, pooling)  
✅ **Clear logging** for debugging  
✅ **Null-safe code** throughout  

Use this as a template for your own game implementations!

## License

Part of the Flutter Game Framework - MIT License
