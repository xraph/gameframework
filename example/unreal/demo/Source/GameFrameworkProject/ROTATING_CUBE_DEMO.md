# Rotating Cube Demo - Unreal Engine

This guide demonstrates how to create a rotating cube in Unreal Engine that communicates with Flutter, matching the Unity rotating cube demo.

## Overview

The demo creates a simple 3D cube that:
- Rotates continuously in Unreal Engine
- Receives rotation speed commands from Flutter
- Sends rotation state updates to Flutter
- Can be paused/resumed from Flutter

## Quick Setup

### 1. Create the Rotating Cube Actor

Create a new C++ class inheriting from `AFlutterActor`:

**RotatingCubeActor.h**
```cpp
#pragma once

#include "CoreMinimal.h"
#include "FlutterActor.h"
#include "RotatingCubeActor.generated.h"

UCLASS(Blueprintable)
class ARotatingCubeActor : public AFlutterActor
{
    GENERATED_BODY()

public:
    ARotatingCubeActor();

protected:
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaTime) override;

    virtual FString GetFlutterTargetName() const override;
    virtual void HandleFlutterMessage_Implementation(const FString& Method, const FString& Data) override;

public:
    // Configuration
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Rotation")
    float RotationSpeed;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Rotation")
    FVector RotationAxis;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Rotation")
    bool bIsRotating;

    // Control methods
    UFUNCTION(BlueprintCallable, Category = "Rotation")
    void SetRotationSpeed(float Speed);

    UFUNCTION(BlueprintCallable, Category = "Rotation")
    void SetRotationAxis(const FVector& Axis);

    UFUNCTION(BlueprintCallable, Category = "Rotation")
    void StartRotation();

    UFUNCTION(BlueprintCallable, Category = "Rotation")
    void StopRotation();

    UFUNCTION(BlueprintCallable, Category = "Rotation")
    void ToggleRotation();

private:
    // Visual component
    UPROPERTY(VisibleAnywhere)
    UStaticMeshComponent* CubeMesh;

    // State reporting
    float TimeSinceLastUpdate;
    float UpdateInterval;
    void SendStateUpdate();
};
```

**RotatingCubeActor.cpp**
```cpp
#include "RotatingCubeActor.h"
#include "Components/StaticMeshComponent.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

ARotatingCubeActor::ARotatingCubeActor()
{
    PrimaryActorTick.bCanEverTick = true;
    
    RotationSpeed = 45.0f; // degrees per second
    RotationAxis = FVector(0, 0, 1); // Z-axis
    bIsRotating = true;
    TimeSinceLastUpdate = 0.0f;
    UpdateInterval = 0.1f; // 10 updates per second

    // Create cube mesh
    CubeMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CubeMesh"));
    RootComponent = CubeMesh;

    // Load default cube mesh
    static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMeshAsset(
        TEXT("/Engine/BasicShapes/Cube"));
    if (CubeMeshAsset.Succeeded())
    {
        CubeMesh->SetStaticMesh(CubeMeshAsset.Object);
    }

    // Load default material
    static ConstructorHelpers::FObjectFinder<UMaterial> CubeMaterial(
        TEXT("/Engine/BasicShapes/BasicShapeMaterial"));
    if (CubeMaterial.Succeeded())
    {
        CubeMesh->SetMaterial(0, CubeMaterial.Object);
    }

    CubeMesh->SetWorldScale3D(FVector(0.5f, 0.5f, 0.5f));
}

void ARotatingCubeActor::BeginPlay()
{
    Super::BeginPlay();
    
    // Send initial state
    SendStateUpdate();
}

void ARotatingCubeActor::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    // Rotate cube
    if (bIsRotating)
    {
        FRotator DeltaRotation = FRotator(
            RotationAxis.X * RotationSpeed * DeltaTime,
            RotationAxis.Y * RotationSpeed * DeltaTime,
            RotationAxis.Z * RotationSpeed * DeltaTime
        );
        AddActorLocalRotation(DeltaRotation);
    }

    // Send periodic updates
    TimeSinceLastUpdate += DeltaTime;
    if (TimeSinceLastUpdate >= UpdateInterval)
    {
        TimeSinceLastUpdate = 0.0f;
        SendStateUpdate();
    }
}

FString ARotatingCubeActor::GetFlutterTargetName() const
{
    return TEXT("RotatingCube");
}

void ARotatingCubeActor::HandleFlutterMessage_Implementation(
    const FString& Method, const FString& Data)
{
    // Parse JSON data
    TSharedPtr<FJsonObject> JsonObject;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Data);

    if (Method == TEXT("setSpeed"))
    {
        if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
        {
            float Speed = JsonObject->GetNumberField(TEXT("speed"));
            SetRotationSpeed(Speed);
        }
    }
    else if (Method == TEXT("setAxis"))
    {
        if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
        {
            float X = JsonObject->GetNumberField(TEXT("x"));
            float Y = JsonObject->GetNumberField(TEXT("y"));
            float Z = JsonObject->GetNumberField(TEXT("z"));
            SetRotationAxis(FVector(X, Y, Z));
        }
    }
    else if (Method == TEXT("start"))
    {
        StartRotation();
    }
    else if (Method == TEXT("stop"))
    {
        StopRotation();
    }
    else if (Method == TEXT("toggle"))
    {
        ToggleRotation();
    }
    else if (Method == TEXT("getState"))
    {
        SendStateUpdate();
    }
}

void ARotatingCubeActor::SetRotationSpeed(float Speed)
{
    RotationSpeed = Speed;
    SendStateUpdate();
}

void ARotatingCubeActor::SetRotationAxis(const FVector& Axis)
{
    RotationAxis = Axis.GetSafeNormal();
    SendStateUpdate();
}

void ARotatingCubeActor::StartRotation()
{
    bIsRotating = true;
    SendToFlutter(TEXT("started"), TEXT("{}"));
    SendStateUpdate();
}

void ARotatingCubeActor::StopRotation()
{
    bIsRotating = false;
    SendToFlutter(TEXT("stopped"), TEXT("{}"));
    SendStateUpdate();
}

void ARotatingCubeActor::ToggleRotation()
{
    if (bIsRotating)
        StopRotation();
    else
        StartRotation();
}

void ARotatingCubeActor::SendStateUpdate()
{
    FRotator CurrentRotation = GetActorRotation();

    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    JsonObject->SetBoolField(TEXT("isRotating"), bIsRotating);
    JsonObject->SetNumberField(TEXT("speed"), RotationSpeed);
    
    // Rotation axis
    TSharedPtr<FJsonObject> AxisObject = MakeShareable(new FJsonObject);
    AxisObject->SetNumberField(TEXT("x"), RotationAxis.X);
    AxisObject->SetNumberField(TEXT("y"), RotationAxis.Y);
    AxisObject->SetNumberField(TEXT("z"), RotationAxis.Z);
    JsonObject->SetObjectField(TEXT("axis"), AxisObject);
    
    // Current rotation
    TSharedPtr<FJsonObject> RotationObject = MakeShareable(new FJsonObject);
    RotationObject->SetNumberField(TEXT("pitch"), CurrentRotation.Pitch);
    RotationObject->SetNumberField(TEXT("yaw"), CurrentRotation.Yaw);
    RotationObject->SetNumberField(TEXT("roll"), CurrentRotation.Roll);
    JsonObject->SetObjectField(TEXT("rotation"), RotationObject);

    FString JsonString;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

    SendToFlutter(TEXT("stateUpdate"), JsonString);
}
```

### 2. Flutter Integration

**Dart Code:**
```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gameframework_unreal/gameframework_unreal.dart';

class RotatingCubeController extends StatefulWidget {
  final UnrealController controller;

  const RotatingCubeController({required this.controller});

  @override
  _RotatingCubeControllerState createState() => _RotatingCubeControllerState();
}

class _RotatingCubeControllerState extends State<RotatingCubeController> {
  bool isRotating = true;
  double rotationSpeed = 45.0;
  Map<String, double> rotationAxis = {'x': 0, 'y': 0, 'z': 1};
  Map<String, double> currentRotation = {'pitch': 0, 'yaw': 0, 'roll': 0};

  @override
  void initState() {
    super.initState();
    _listenToUpdates();
  }

  void _listenToUpdates() {
    widget.controller.messageStream.listen((message) {
      final metadata = message.metadata;
      if (metadata['target'] == 'RotatingCube') {
        final method = metadata['method'] as String?;
        
        if (method == 'stateUpdate') {
          final data = jsonDecode(message.data);
          setState(() {
            isRotating = data['isRotating'] ?? false;
            rotationSpeed = (data['speed'] ?? 45.0).toDouble();
            rotationAxis = {
              'x': (data['axis']?['x'] ?? 0).toDouble(),
              'y': (data['axis']?['y'] ?? 0).toDouble(),
              'z': (data['axis']?['z'] ?? 1).toDouble(),
            };
            currentRotation = {
              'pitch': (data['rotation']?['pitch'] ?? 0).toDouble(),
              'yaw': (data['rotation']?['yaw'] ?? 0).toDouble(),
              'roll': (data['rotation']?['roll'] ?? 0).toDouble(),
            };
          });
        }
      }
    });
  }

  Future<void> _setSpeed(double speed) async {
    await widget.controller.sendJsonMessage(
      'RotatingCube',
      'setSpeed',
      {'speed': speed},
    );
  }

  Future<void> _toggle() async {
    await widget.controller.sendMessage('RotatingCube', 'toggle', '{}');
  }

  Future<void> _setAxis(double x, double y, double z) async {
    await widget.controller.sendJsonMessage(
      'RotatingCube',
      'setAxis',
      {'x': x, 'y': y, 'z': z},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rotating Cube', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            
            // Status
            Row(
              children: [
                Icon(
                  isRotating ? Icons.play_arrow : Icons.pause,
                  color: isRotating ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                Text(isRotating ? 'Rotating' : 'Paused'),
              ],
            ),
            SizedBox(height: 16),
            
            // Speed slider
            Text('Speed: ${rotationSpeed.toStringAsFixed(1)}°/s'),
            Slider(
              value: rotationSpeed,
              min: 0,
              max: 180,
              onChanged: (value) {
                setState(() => rotationSpeed = value);
                _setSpeed(value);
              },
            ),
            
            // Toggle button
            ElevatedButton.icon(
              onPressed: _toggle,
              icon: Icon(isRotating ? Icons.pause : Icons.play_arrow),
              label: Text(isRotating ? 'Pause' : 'Start'),
            ),
            
            SizedBox(height: 16),
            
            // Current rotation display
            Text('Current Rotation:'),
            Text('  Pitch: ${currentRotation['pitch']?.toStringAsFixed(1)}°'),
            Text('  Yaw: ${currentRotation['yaw']?.toStringAsFixed(1)}°'),
            Text('  Roll: ${currentRotation['roll']?.toStringAsFixed(1)}°'),
            
            SizedBox(height: 16),
            
            // Axis presets
            Text('Rotation Axis:'),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _setAxis(1, 0, 0),
                  child: Text('X'),
                ),
                ElevatedButton(
                  onPressed: () => _setAxis(0, 1, 0),
                  child: Text('Y'),
                ),
                ElevatedButton(
                  onPressed: () => _setAxis(0, 0, 1),
                  child: Text('Z'),
                ),
                ElevatedButton(
                  onPressed: () => _setAxis(1, 1, 1),
                  child: Text('XYZ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3. Blueprint Version

For a Blueprint-only implementation:

1. Create a new Blueprint Actor
2. Add a Static Mesh Component with a cube mesh
3. Add the following variables:
   - `RotationSpeed` (Float, default 45.0)
   - `RotationAxis` (Vector, default 0,0,1)
   - `bIsRotating` (Boolean, default true)
4. In Event Tick:
   - Add Delta Rotation using speed * delta time * axis
5. Implement Flutter message handling via the message router

## Message Protocol

### From Flutter to Unreal

| Method | Data | Description |
|--------|------|-------------|
| setSpeed | {speed: float} | Set rotation speed in degrees/second |
| setAxis | {x, y, z: float} | Set rotation axis |
| start | {} | Start rotation |
| stop | {} | Stop rotation |
| toggle | {} | Toggle rotation |
| getState | {} | Request current state |

### From Unreal to Flutter

| Method | Data | Description |
|--------|------|-------------|
| stateUpdate | {isRotating, speed, axis, rotation} | Full state update |
| started | {} | Rotation started |
| stopped | {} | Rotation stopped |

## Testing

1. Add the RotatingCubeActor to your level
2. Run the Flutter app with the Unreal widget
3. Use the Flutter controls to:
   - Adjust rotation speed
   - Change rotation axis
   - Start/stop rotation
4. Observe real-time updates in the Flutter UI

## Comparison with Unity Demo

| Feature | Unity | Unreal |
|---------|-------|--------|
| Base Class | FlutterMonoBehaviour | FlutterActor |
| Message Attribute | [FlutterMethod] | HandleFlutterMessage override |
| Rotation | transform.Rotate() | AddActorLocalRotation() |
| JSON Parsing | JsonUtility | FJsonSerializer |
| Update Rate | Configurable | Configurable |

The API and message protocol are identical, ensuring consistent Flutter integration across both engines.
