# AR Foundation Support for Flutter Game Framework

This guide explains how to integrate Unity's AR Foundation with the Flutter Game Framework.

---

## Overview

AR Foundation provides a unified API for building AR experiences that work across multiple
platforms (ARCore for Android, ARKit for iOS). When combined with the Flutter Game Framework, you
can embed AR experiences directly in your Flutter apps.

---

## Prerequisites

- Unity 2022.3 or later
- AR Foundation package 5.x
- ARCore XR Plugin (for Android)
- ARKit XR Plugin (for iOS)
- Flutter Game Framework Unity plugin

---

## Setup

### 1. Install AR Foundation Packages

In Unity Package Manager, install:

```
com.unity.xr.arfoundation (5.x)
com.unity.xr.arcore (5.x) - for Android
com.unity.xr.arkit (5.x) - for iOS
```

### 2. Configure XR Plugin Management

1. Go to **Edit > Project Settings > XR Plug-in Management**
2. Enable **ARCore** for Android
3. Enable **ARKit** for iOS

### 3. Create AR Session Setup

Add these components to your scene:

```
ARSession
ARSessionOrigin (or XROrigin in newer versions)
ARCameraManager
ARCameraBackground
```

---

## Integration with Flutter

### Unity C# Code

Create an AR manager that communicates with Flutter:

```csharp
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using Xraph.GameFramework.Unity;
using System.Collections.Generic;

public class FlutterARManager : MonoBehaviour
{
    [Header("AR Components")]
    public ARSession arSession;
    public ARPlaneManager planeManager;
    public ARPointCloudManager pointCloudManager;
    public ARRaycastManager raycastManager;

    private bool isARActive = false;

    void OnEnable()
    {
        FlutterBridge.OnFlutterMessage += HandleFlutterMessage;

        // Subscribe to AR events
        if (planeManager != null)
        {
            planeManager.planesChanged += OnPlanesChanged;
        }
    }

    void OnDisable()
    {
        FlutterBridge.OnFlutterMessage -= HandleFlutterMessage;

        if (planeManager != null)
        {
            planeManager.planesChanged -= OnPlanesChanged;
        }
    }

    private void HandleFlutterMessage(string target, string method, string data)
    {
        if (target != "ARManager") return;

        switch (method)
        {
            case "StartAR":
                StartAR();
                break;
            case "StopAR":
                StopAR();
                break;
            case "PlaceObject":
                PlaceObjectAtScreenPoint(data);
                break;
            case "GetPlaneCount":
                SendPlaneCount();
                break;
        }
    }

    public void StartAR()
    {
        if (arSession != null)
        {
            arSession.enabled = true;
            isARActive = true;
            FlutterBridge.Instance.SendToFlutter("ARManager", "onARStarted", "true");
        }
    }

    public void StopAR()
    {
        if (arSession != null)
        {
            arSession.enabled = false;
            isARActive = false;
            FlutterBridge.Instance.SendToFlutter("ARManager", "onARStopped", "true");
        }
    }

    private void OnPlanesChanged(ARPlanesChangedEventArgs args)
    {
        // Notify Flutter about detected planes
        var planeData = new ARPlaneData
        {
            addedCount = args.added.Count,
            updatedCount = args.updated.Count,
            removedCount = args.removed.Count,
            totalPlanes = planeManager.trackables.count
        };

        FlutterBridge.Instance.SendToFlutter("ARManager", "onPlanesChanged", planeData);
    }

    private void PlaceObjectAtScreenPoint(string screenPointJson)
    {
        try
        {
            var point = JsonUtility.FromJson<ScreenPoint>(screenPointJson);
            var screenPos = new Vector2(point.x, point.y);

            List<ARRaycastHit> hits = new List<ARRaycastHit>();
            if (raycastManager.Raycast(screenPos, hits, UnityEngine.XR.ARSubsystems.TrackableType.PlaneWithinPolygon))
            {
                var hitPose = hits[0].pose;

                // Place object at hit position
                // Your object placement logic here

                // Notify Flutter
                var result = new ObjectPlacementResult
                {
                    success = true,
                    position = new Vector3Data
                    {
                        x = hitPose.position.x,
                        y = hitPose.position.y,
                        z = hitPose.position.z
                    }
                };

                FlutterBridge.Instance.SendToFlutter("ARManager", "onObjectPlaced", result);
            }
            else
            {
                var result = new ObjectPlacementResult { success = false };
                FlutterBridge.Instance.SendToFlutter("ARManager", "onObjectPlaced", result);
            }
        }
        catch (System.Exception e)
        {
            FlutterBridge.Instance.SendError($"Failed to place object: {e.Message}");
        }
    }

    private void SendPlaneCount()
    {
        var count = planeManager != null ? planeManager.trackables.count : 0;
        FlutterBridge.Instance.SendToFlutter("ARManager", "onPlaneCount", count.ToString());
    }

    // Data structures
    [System.Serializable]
    private class ARPlaneData
    {
        public int addedCount;
        public int updatedCount;
        public int removedCount;
        public int totalPlanes;
    }

    [System.Serializable]
    private class ScreenPoint
    {
        public float x;
        public float y;
    }

    [System.Serializable]
    private class ObjectPlacementResult
    {
        public bool success;
        public Vector3Data position;
    }

    [System.Serializable]
    private class Vector3Data
    {
        public float x;
        public float y;
        public float z;
    }
}
```

### Flutter Code

```dart
import 'package:flutter/material.dart';
import 'package:gameframework/gameframework.dart';
import 'package:gameframework_unity/gameframework_unity.dart';

class ARScreen extends StatefulWidget {
  @override
  _ARScreenState createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  GameEngineController? _controller;
  int _planeCount = 0;
  bool _isARActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AR Experience'),
        actions: [
          IconButton(
            icon: Icon(_isARActive ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleAR,
          ),
        ],
      ),
      body: Stack(
        children: [
          // AR View
          GameWidget(
            engineType: GameEngineType.unity,
            onEngineCreated: _onEngineCreated,
            onMessage: _onMessage,
            config: GameEngineConfig(
              fullscreen: true,
              runImmediately: true,
            ),
          ),

          // AR Info Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AR Status: ${_isARActive ? "Active" : "Inactive"}',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Detected Planes: $_planeCount',
                    style: TextStyle(color: Colors.white),
                  ),
                  if (_planeCount == 0 && _isARActive)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Move your device to detect surfaces',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Placement instructions
          if (_isARActive && _planeCount > 0)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tap to place objects',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isARActive
          ? FloatingActionButton(
        onPressed: _requestPlaneCount,
        child: Icon(Icons.refresh),
      )
          : null,
    );
  }

  void _onEngineCreated(GameEngineController controller) {
    setState(() {
      _controller = controller;
    });

    // Start AR automatically
    Future.delayed(Duration(milliseconds: 500), () {
      _startAR();
    });
  }

  void _onMessage(GameEngineMessage message) {
    if (message.method == 'onARStarted') {
      setState(() {
        _isARActive = true;
      });
    } else if (message.method == 'onARStopped') {
      setState(() {
        _isARActive = false;
        _planeCount = 0;
      });
    } else if (message.method == 'onPlanesChanged') {
      final data = message.asJson();
      setState(() {
        _planeCount = data['totalPlanes'] ?? 0;
      });
    } else if (message.method == 'onObjectPlaced') {
      final data = message.asJson();
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Object placed successfully!')),
        );
      }
    } else if (message.method == 'onPlaneCount') {
      setState(() {
        _planeCount = int.tryParse(message.data) ?? 0;
      });
    }
  }

  void _startAR() async {
    await _controller?.sendMessage('ARManager', 'StartAR', '');
  }

  void _stopAR() async {
    await _controller?.sendMessage('ARManager', 'StopAR', '');
  }

  void _toggleAR() {
    if (_isARActive) {
      _stopAR();
    } else {
      _startAR();
    }
  }

  void _requestPlaneCount() async {
    await _controller?.sendMessage('ARManager', 'GetPlaneCount', '');
  }

  // Handle tap to place
  void _onTap(TapUpDetails details) async {
    if (!_isARActive || _planeCount == 0) return;

    final screenPoint = {
      'x': details.globalPosition.dx,
      'y': details.globalPosition.dy,
    };

    await _controller?.sendJsonMessage(
      'ARManager',
      'PlaceObject',
      screenPoint,
    );
  }

  @override
  void dispose() {
    _stopAR();
    _controller?.dispose();
    super.dispose();
  }
}
```

---

## Platform-Specific Configuration

### Android (ARCore)

**AndroidManifest.xml additions:**

```xml
<!-- AR Core -->
<meta-data android:name="unityplayer.UnityActivity" android:value="true" />

<meta-data android:name="com.google.ar.core" android:value="required" />

    <!-- Camera permission -->
<uses-permission android:name="android.permission.CAMERA" />

<uses-feature android:name="android.hardware.camera.ar" android:required="true" />
```

**Minimum Android version:** API 24 (Android 7.0)

### iOS (ARKit)

**Info.plist additions:**

```xml

<key>NSCameraUsageDescription</key><string>This app uses the camera for AR experiences</string>

<key>UIRequiredDeviceCapabilities</key><array>
<string>arkit</string>
</array>
```

**Minimum iOS version:** 12.0

---

## Features

### Plane Detection

The AR system automatically detects horizontal and vertical planes:

```dart
// Planes are reported via onPlanesChanged messages
controller.messageStream.listen
(
(message) {
if (message.method == 'onPlanesChanged') {
final data = message.asJson();
print('Total planes: ${data['totalPlanes']}');
print('Added: ${data['addedCount']}');
print('Updated: ${data['updatedCount']}');
}
});
```

### Object Placement

Place virtual objects on detected surfaces:

```dart
// Send tap coordinates to Unity
await
controller.sendJsonMessage
('ARManager', 'PlaceObject', {
'x': tapPosition.dx,
'y': tapPosition.dy,
});

// Receive placement result
controller.messageStream.listen((message) {
if (message.method == 'onObjectPlaced') {
final data = message.asJson();
if (data['success']) {
final pos = data['position'];
print('Placed at: ${pos['x']}, ${pos['y']}, ${pos['z']}');
}
}
});
```

### Image Tracking

Track images in the real world:

```csharp
// In Unity
public class FlutterARImageTracking : MonoBehaviour
{
    public ARTrackedImageManager imageManager;

    void OnEnable()
    {
        imageManager.trackedImagesChanged += OnTrackedImagesChanged;
    }

    void OnTrackedImagesChanged(ARTrackedImagesChangedEventArgs args)
    {
        foreach (var image in args.added)
        {
            FlutterBridge.Instance.SendToFlutter(
                "ARManager",
                "onImageTracked",
                image.referenceImage.name
            );
        }
    }
}
```

---

## Best Practices

### 1. Permission Handling

Always request camera permissions in Flutter before starting AR:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestCameraPermission() async {
  final status = await Permission.camera.request();
  return status.isGranted;
}

// Before starting AR
if (
await requestCameraPermission()) {
_startAR();
} else {
// Show permission denied message
}
```

### 2. Performance Optimization

- Use lower AR frame rates if full 60fps isn't needed
- Limit the number of tracked planes
- Disable features you don't use (point cloud, image tracking, etc.)

```csharp
// In Unity
planeManager.requestedDetectionMode = PlaneDetectionMode.Horizontal;
planeManager.maximumNumberOfPlanes = 10;
```

### 3. User Guidance

Provide clear instructions to users:

```dart
// Show coaching UI for first-time users
if (isFirstTime && planesDetected == 0) {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: Text('Find a Surface'),
content: Text(
'Move your phone slowly to help detect flat surfaces'
),
),
);
}
```

### 4. Error Handling

```csharp
// In Unity
void CheckARAvailability()
{
    var availability = ARSession.state;

    if (availability == ARSessionState.Unsupported)
    {
        FlutterBridge.Instance.SendError("AR is not supported on this device");
    }
    else if (availability == ARSessionState.NeedsInstall)
    {
        FlutterBridge.Instance.SendToFlutter(
            "ARManager",
            "onARNeedsInstall",
            "true"
        );
    }
}
```

---

## Troubleshooting

### AR not starting on Android

1. Check that ARCore is installed on the device
2. Verify camera permission is granted
3. Check minimum Android version (7.0+)
4. Ensure device supports ARCore: https://developers.google.com/ar/devices

### AR not starting on iOS

1. Verify device supports ARKit (iPhone 6S and later)
2. Check camera permission in Info.plist
3. Ensure iOS version is 12.0+
4. Test on physical device (AR doesn't work in simulator)

### Poor tracking quality

1. Ensure good lighting conditions
2. Use textured surfaces (not plain white/reflective)
3. Move device slowly
4. Keep camera lens clean

---

## Examples

See `examples/ar_example/` for complete AR integration examples.

---

## Additional Resources

- [Unity AR Foundation Documentation](https://docs.unity3d.com/Packages/com.unity.xr.arfoundation@5.0/manual/index.html)
- [ARCore Developer Guide](https://developers.google.com/ar)
- [ARKit Documentation](https://developer.apple.com/augmented-reality/)

---

## License

See LICENSE file in the repository root.
