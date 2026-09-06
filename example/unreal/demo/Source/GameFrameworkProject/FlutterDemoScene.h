#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FlutterDemoScene.generated.h"

class ACameraActor;
class ADirectionalLight;
class ARotatingCube;
class AStaticMeshActor;

/**
 * Builds the demo scene in code, at runtime.
 *
 * There is no .umap here on purpose. A scaffolded project has no level of its
 * own and boots an engine map, which is empty, so anything you want to see has
 * to be spawned. That also keeps the demo working without opening the editor,
 * which matters when the whole point is to run it from Flutter.
 *
 * Nothing here needs an asset you have to make first. The shapes come from
 * /Engine/BasicShapes, and the sky is SkyAtmosphere, which is computed rather
 * than textured, so there is no cubemap to cook.
 */
UCLASS()
class AFlutterDemoScene : public AActor
{
	GENERATED_BODY()

public:
	AFlutterDemoScene();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;

	/** The hero cube, which is what Flutter talks to. */
	UPROPERTY(Transient)
	ARotatingCube* HeroCube = nullptr;

private:
	/** Spawn one tinted shape. Always Movable: see the note in the .cpp. */
	AStaticMeshActor* SpawnShape(const TCHAR* MeshPath, const FVector& Location,
		const FVector& Scale, const FLinearColor& Color);

	/** A material that actually exposes a colour, or null if this build has none. */
	static class UMaterialInterface* FindTintableMaterial();

	/** Tint a mesh, whatever its material happens to call the parameter. */
	void TintMesh(class UStaticMeshComponent* MeshComponent, const FLinearColor& Color);

	void BuildSky();
	void BuildLights();
	void BuildShapes();
	void BuildCamera();

	/** Point the player at our camera. */
	void TakeOverTheView();

	/** Read touch and turn a drag into a camera orbit. */
	void UpdateOrbitFromTouch(float DeltaSeconds);

	/** Place the camera from the current orbit angles and viewport shape. */
	void PositionCamera();

	/** Log what the renderer is doing, so a letterbox can be traced to a cause. */
	void ReportRenderState() const;

	/** Tell Flutter where the camera is, when the viewer has moved it. */
	void ReportCameraIfMoved();

	UPROPERTY(Transient)
	ACameraActor* Camera = nullptr;

	UPROPERTY(Transient)
	ADirectionalLight* SunLight = nullptr;

	UPROPERTY(Transient)
	TArray<AStaticMeshActor*> Orbiters;

	/** Seconds since BeginPlay, which drives the orbit of the shapes. */
	float SceneTime = 0.0f;

	/** Throttles the render state report to once a second. */
	float ReportSeconds = 0.0f;

	/** Throttles camera updates, and what was last sent, so a still camera is silent. */
	float CameraReportCooldown = 0.0f;
	float LastSentDistance = -1.0f;
	float LastSentYaw = 0.0f;
	float LastSentPitch = 0.0f;

	/** Where the camera sits, in orbit terms. Yaw and pitch are degrees. */
	float OrbitYaw = 0.0f;
	float OrbitPitch = -14.0f;
	float OrbitDistance = 640.0f;

	/** Touch tracking, so a drag becomes a delta rather than a jump. */
	bool bWasTouching = false;
	FVector2D LastTouch = FVector2D::ZeroVector;

	/** Pinch tracking. Same reason: a ratio between frames, not an absolute. */
	bool bWasPinching = false;
	float LastPinchSpread = 0.0f;

	/** Idle drift, which stops the first time the viewer touches the screen. */
	bool bViewerHasTakenOver = false;

	/** The view target has to be claimed after the player controller exists. */
	bool bViewClaimed = false;
};
