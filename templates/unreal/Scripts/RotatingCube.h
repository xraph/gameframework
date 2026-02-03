#pragma once

#include "CoreMinimal.h"
#include "FlutterActor.h"
#include "RotatingCube.generated.h"

/**
 * Rotating cube demo actor for Flutter-Unreal integration.
 * Demonstrates bidirectional communication between Flutter and Unreal.
 * 
 * Features:
 * - Responds to Flutter commands (setSpeed, setAxis, setColor, reset, getState)
 * - Sends state updates back to Flutter (onSpeedChanged, onState, onReset)
 * - Configurable rotation speed and axis
 * - Blueprint-friendly with exposed properties
 */
UCLASS(Blueprintable, ClassGroup=(Flutter), meta=(BlueprintSpawnableComponent))
class ARotatingCube : public AFlutterActor
{
    GENERATED_BODY()

public:
    ARotatingCube();

    // ==================== EXPOSED PROPERTIES ====================

    /** Current rotation speed in degrees per second */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Rotation", meta = (ClampMin = "-360", ClampMax = "360"))
    float RotationSpeed = 50.0f;

    /** Rotation axis (normalized) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Rotation")
    FVector RotationAxis = FVector(0.0f, 1.0f, 0.0f);

    /** Cube color */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Appearance")
    FLinearColor CubeColor = FLinearColor(0.5f, 0.5f, 1.0f, 1.0f);

    /** Whether the cube is currently rotating */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Rotation")
    bool bIsRotating = true;

    /** Auto-sync state to Flutter at this interval (0 = disabled) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Flutter")
    float SyncIntervalSeconds = 0.0f;

    // ==================== BLUEPRINT EVENTS ====================

    /** Called when speed changes from Flutter */
    UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
    void OnSpeedChanged_Blueprint(float NewSpeed);

    /** Called when axis changes from Flutter */
    UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
    void OnAxisChanged_Blueprint(FVector NewAxis);

    /** Called when color changes from Flutter */
    UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
    void OnColorChanged_Blueprint(FLinearColor NewColor);

    /** Called when reset is requested from Flutter */
    UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
    void OnReset_Blueprint();

    // ==================== BLUEPRINT CALLABLE FUNCTIONS ====================

    /** Set the rotation speed */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Cube")
    void SetSpeed(float NewSpeed);

    /** Set the rotation axis */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Cube")
    void SetAxis(FVector NewAxis);

    /** Set the cube color */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Cube")
    void SetColor(FLinearColor NewColor);

    /** Reset cube to default state */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Cube")
    void Reset();

    /** Get the current state as JSON string */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Cube")
    FString GetStateJson() const;

    /** Start/stop rotation */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Cube")
    void SetRotating(bool bShouldRotate);

    /** Get current RPM (rotations per minute) */
    UFUNCTION(BlueprintPure, Category = "Flutter|Cube")
    float GetRPM() const;

    /** Send current state to Flutter */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Cube")
    void SyncStateToFlutter();

protected:
    // ==================== OVERRIDES ====================

    virtual void BeginPlay() override;
    virtual void Tick(float DeltaTime) override;
    virtual FString GetFlutterTargetName() const override;
    virtual void OnFlutterMessage_Implementation(const FString& Method, const FString& Data) override;

    // ==================== INTERNAL ====================

    /** The static mesh component for the cube */
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    UStaticMeshComponent* CubeMesh;

    /** Dynamic material instance for color changes */
    UPROPERTY()
    UMaterialInstanceDynamic* DynamicMaterial;

    /** Timer handle for auto-sync */
    FTimerHandle SyncTimerHandle;

private:
    /** Apply current color to material */
    void UpdateMaterialColor();

    /** Parse axis from JSON */
    FVector ParseAxisFromJson(const FString& JsonData);

    /** Parse color from JSON */
    FLinearColor ParseColorFromJson(const FString& JsonData);

    /** Current rotation angle (for state tracking) */
    float CurrentRotationAngle = 0.0f;

    /** Default values for reset */
    float DefaultSpeed = 50.0f;
    FVector DefaultAxis = FVector(0.0f, 1.0f, 0.0f);
    FLinearColor DefaultColor = FLinearColor(0.5f, 0.5f, 1.0f, 1.0f);
};
