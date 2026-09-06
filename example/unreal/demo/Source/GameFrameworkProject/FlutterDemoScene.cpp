#include "FlutterDemoScene.h"

#include "RotatingCube.h"
#include "FlutterBridge.h"

#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Engine/GameViewportClient.h"
#include "Slate/SceneViewport.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/Engine.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMesh.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/GameViewportClient.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "Materials/Material.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"

namespace
{
	/// The ring of shapes around the cube.
	constexpr float OrbitRadius = 320.0f;
	constexpr float OrbitDegreesPerSecond = 18.0f;
	constexpr float OrbitBobHeight = 35.0f;

	/// How far a drag across the screen swings the camera.
	constexpr float DegreesPerPixelYaw = 0.32f;
	constexpr float DegreesPerPixelPitch = 0.22f;

	/// Until someone touches the screen, drift slowly so the scene reads as
	/// alive rather than as a still frame.
	constexpr float IdleDriftDegreesPerSecond = 4.0f;

	/// Keep the camera out of the floor and off the top of the sky.
	constexpr float MinPitch = -70.0f;
	constexpr float MaxPitch = 12.0f;

	/// How close and how far a pinch can take the camera.
	constexpr float MinDistance = 260.0f;
	constexpr float MaxDistance = 1800.0f;

	constexpr float FocusHeight = 60.0f;
}

AFlutterDemoScene::AFlutterDemoScene()
{
	PrimaryActorTick.bCanEverTick = true;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

UMaterialInterface* AFlutterDemoScene::FindTintableMaterial()
{
	static UMaterialInterface* Cached = nullptr;
	static bool bSearched = false;
	if (bSearched)
	{
		return Cached;
	}
	bSearched = true;

	// The shape meshes do not arrive with a tintable material. Their own
	// material is not cooked into this build, so they fall back to
	// WorldGridMaterial and DefaultMaterial, neither of which exposes a colour,
	// which is how you end up with a scene of identical grey checkerboards.
	//
	// So find one that does. Ask each candidate what it exposes rather than
	// trusting a parameter name, because setting a name a material does not
	// have fails silently and looks exactly like this bug.
	TArray<UMaterialInterface*> Candidates;
	if (GEngine != nullptr)
	{
		// These are TObjectPtr<UMaterial>, so unwrap before the upcast.
		Candidates.Add(GEngine->LevelColorationLitMaterial.Get());
		Candidates.Add(GEngine->VertexColorMaterial.Get());
		Candidates.Add(GEngine->DebugMeshMaterial.Get());
	}
	Candidates.Add(LoadObject<UMaterialInterface>(
		nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial")));

	for (UMaterialInterface* Candidate : Candidates)
	{
		if (Candidate == nullptr)
		{
			continue;
		}

		TArray<FMaterialParameterInfo> Infos;
		TArray<FGuid> Guids;
		Candidate->GetAllVectorParameterInfo(Infos, Guids);

		FString Names;
		for (const FMaterialParameterInfo& Info : Infos)
		{
			Names += Info.Name.ToString() + TEXT(" ");
		}
		UE_LOG(LogTemp, Log, TEXT("[FlutterDemoScene] %s vector params: [%s]"),
			*GetNameSafe(Candidate), *Names);

		if (Infos.Num() > 0)
		{
			Cached = Candidate;
			return Cached;
		}
	}

	UE_LOG(LogTemp, Warning,
		TEXT("[FlutterDemoScene] No tintable material in this build, so the shapes stay grey"));
	return nullptr;
}

void AFlutterDemoScene::TintMesh(UStaticMeshComponent* MeshComponent, const FLinearColor& Color)
{
	if (MeshComponent == nullptr)
	{
		return;
	}

	UMaterialInterface* Parent = FindTintableMaterial();
	if (Parent == nullptr)
	{
		return;
	}

	UMaterialInstanceDynamic* Material = UMaterialInstanceDynamic::Create(Parent, this);
	if (Material == nullptr)
	{
		return;
	}

	TArray<FMaterialParameterInfo> Infos;
	TArray<FGuid> Guids;
	Material->GetAllVectorParameterInfo(Infos, Guids);
	if (Infos.Num() == 0)
	{
		return;
	}

	// Prefer an obviously colour-shaped name, otherwise take the first one.
	static const FName Preferred[] = {
		FName(TEXT("Color")), FName(TEXT("Colour")),
		FName(TEXT("BaseColor")), FName(TEXT("Base Color")), FName(TEXT("Tint"))
	};

	FMaterialParameterInfo Chosen = Infos[0];
	for (const FName& Name : Preferred)
	{
		const FMaterialParameterInfo* Match = Infos.FindByPredicate(
			[&Name](const FMaterialParameterInfo& Info) { return Info.Name == Name; });
		if (Match != nullptr)
		{
			Chosen = *Match;
			break;
		}
	}

	Material->SetVectorParameterValue(Chosen.Name, Color);
	MeshComponent->SetMaterial(0, Material);
}

AStaticMeshActor* AFlutterDemoScene::SpawnShape(const TCHAR* MeshPath,
	const FVector& Location, const FVector& Scale, const FLinearColor& Color)
{
	UWorld* World = GetWorld();
	if (World == nullptr)
	{
		return nullptr;
	}

	UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, MeshPath);
	if (Mesh == nullptr)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterDemoScene] %s is not cooked into this build"), MeshPath);
		return nullptr;
	}

	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	AStaticMeshActor* Actor = World->SpawnActor<AStaticMeshActor>(
		AStaticMeshActor::StaticClass(), FTransform(Location), Params);
	if (Actor == nullptr)
	{
		return nullptr;
	}

	UStaticMeshComponent* MeshComponent = Actor->GetStaticMeshComponent();

	// Anything spawned at runtime has to be Movable, the floor included. A
	// Static actor expects baked lighting, and a level built in code has none,
	// so it would render unlit.
	MeshComponent->SetMobility(EComponentMobility::Movable);
	MeshComponent->SetStaticMesh(Mesh);
	Actor->SetActorScale3D(Scale);
	TintMesh(MeshComponent, Color);

	return Actor;
}

void AFlutterDemoScene::BuildSky()
{
	UWorld* World = GetWorld();
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	// A computed sky rather than a cubemap. SkyAtmosphere scatters light from
	// the sun direction, so there is no texture to author and nothing extra to
	// cook, and turning the sun changes the sky with it.
	World->SpawnActor<ASkyAtmosphere>(ASkyAtmosphere::StaticClass(), FTransform::Identity, Params);

	// Let the sky light the scene. Real-time capture means it picks up the
	// atmosphere above instead of needing a cubemap of its own.
	if (ASkyLight* Sky = World->SpawnActor<ASkyLight>(
			ASkyLight::StaticClass(), FTransform(FVector(0.0f, 0.0f, 200.0f)), Params))
	{
		if (USkyLightComponent* Component = Sky->GetLightComponent())
		{
			Component->SetMobility(EComponentMobility::Movable);
			Component->SetRealTimeCaptureEnabled(true);
			Component->SetIntensity(1.0f);
		}
	}

	// A little haze, so the floor fades out instead of ending on a hard line.
	if (AExponentialHeightFog* Fog = World->SpawnActor<AExponentialHeightFog>(
			AExponentialHeightFog::StaticClass(),
			FTransform(FVector(0.0f, 0.0f, -200.0f)), Params))
	{
		if (UExponentialHeightFogComponent* Component = Fog->GetComponent())
		{
			Component->SetFogDensity(0.015f);
			Component->SetFogInscatteringColor(FLinearColor(0.42f, 0.55f, 0.78f));
			Component->SetStartDistance(600.0f);
		}
	}
}

void AFlutterDemoScene::BuildLights()
{
	UWorld* World = GetWorld();
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	// The sun. Low and warm, which gives the shapes long shadows and stops the
	// scene reading as a flat product render.
	SunLight = World->SpawnActor<ADirectionalLight>(
		ADirectionalLight::StaticClass(),
		FTransform(FRotator(-32.0f, -40.0f, 0.0f)), Params);
	if (SunLight != nullptr)
	{
		SunLight->SetMobility(EComponentMobility::Movable);
		if (UDirectionalLightComponent* Light = Cast<UDirectionalLightComponent>(SunLight->GetLightComponent()))
		{
			Light->SetIntensity(5.0f);
			Light->SetLightColor(FLinearColor(1.0f, 0.93f, 0.82f));
			Light->SetCastShadows(true);

			// This is what makes SkyAtmosphere treat it as the sun, so the sky
			// brightens around the direction the light points from.
			Light->SetAtmosphereSunLight(true);
		}
	}

	// Cool fill from behind, so the shadowed faces read as shape rather than
	// as black.
	if (ADirectionalLight* Fill = World->SpawnActor<ADirectionalLight>(
			ADirectionalLight::StaticClass(),
			FTransform(FRotator(-18.0f, 145.0f, 0.0f)), Params))
	{
		Fill->SetMobility(EComponentMobility::Movable);
		if (UDirectionalLightComponent* Light = Cast<UDirectionalLightComponent>(Fill->GetLightComponent()))
		{
			Light->SetIntensity(1.2f);
			Light->SetLightColor(FLinearColor(0.42f, 0.56f, 1.0f));
			Light->SetCastShadows(false);
		}
	}
}

void AFlutterDemoScene::BuildShapes()
{
	UWorld* World = GetWorld();
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	// Floor, wide enough to catch the shadows and to run out into the fog.
	SpawnShape(TEXT("/Engine/BasicShapes/Plane"), FVector(0.0f, 0.0f, -110.0f),
		FVector(40.0f, 40.0f, 1.0f), FLinearColor(0.10f, 0.12f, 0.16f));

	// The hero cube. This is the actor Flutter sends setSpeed, setAxis and
	// setColor to, so it is spawned rather than dropped in a level.
	HeroCube = World->SpawnActor<ARotatingCube>(ARotatingCube::StaticClass(),
		FTransform(FVector(0.0f, 0.0f, 40.0f)), Params);
	if (HeroCube != nullptr)
	{
		HeroCube->SetActorScale3D(FVector(1.6f));
	}

	struct FOrbiter
	{
		const TCHAR* Mesh;
		FLinearColor Color;
		float Scale;
	};
	static const FOrbiter Ring[] = {
		{TEXT("/Engine/BasicShapes/Sphere"),   FLinearColor(0.92f, 0.28f, 0.32f), 0.7f},
		{TEXT("/Engine/BasicShapes/Cone"),     FLinearColor(0.98f, 0.72f, 0.20f), 0.8f},
		{TEXT("/Engine/BasicShapes/Cylinder"), FLinearColor(0.24f, 0.82f, 0.60f), 0.7f},
		{TEXT("/Engine/BasicShapes/Cube"),     FLinearColor(0.34f, 0.52f, 0.96f), 0.7f},
		{TEXT("/Engine/BasicShapes/Sphere"),   FLinearColor(0.72f, 0.38f, 0.95f), 0.6f},
	};

	const int32 Count = UE_ARRAY_COUNT(Ring);
	for (int32 Index = 0; Index < Count; ++Index)
	{
		const float Angle = (360.0f / Count) * Index;
		const FVector Location(
			OrbitRadius * FMath::Cos(FMath::DegreesToRadians(Angle)),
			OrbitRadius * FMath::Sin(FMath::DegreesToRadians(Angle)),
			0.0f);

		if (AStaticMeshActor* Shape = SpawnShape(Ring[Index].Mesh, Location,
				FVector(Ring[Index].Scale), Ring[Index].Color))
		{
			Orbiters.Add(Shape);
		}
	}
}

void AFlutterDemoScene::BuildCamera()
{
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	Camera = GetWorld()->SpawnActor<ACameraActor>(
		ACameraActor::StaticClass(), FTransform::Identity, Params);

	if (Camera != nullptr)
	{
		// ACameraActor's constructor pins the camera to 16:9 and turns on the
		// aspect ratio constraint, and the engine then adds black bars to fill
		// whatever it is rendering into. On a phone held upright that is most
		// of the screen, and it looks exactly like the scene has been cropped
		// into a landscape band, which sends you hunting through resolutions
		// and viewports instead. Let it fill the view it is given.
		UCameraComponent* Component = Camera->GetCameraComponent();
		Component->SetConstraintAspectRatio(false);

		// With the constraint off, which axis the FOV is held on decides what a
		// tall screen shows. The component's own setting is ignored unless this
		// override is on, and the player's default holds the vertical FOV,
		// which squeezes the horizontal one on a portrait screen and looks like
		// a zoomed-in landscape crop. Hold the horizontal FOV instead, so a
		// taller screen shows more of the scene rather than less.
		Component->bOverrideAspectRatioAxisConstraint = true;
		Component->SetAspectRatioAxisConstraint(EAspectRatioAxisConstraint::AspectRatio_MaintainXFOV);
	}

	PositionCamera();
}

void AFlutterDemoScene::PositionCamera()
{
	if (Camera == nullptr)
	{
		return;
	}

	// A phone held upright has a tall, narrow viewport, and a framing chosen
	// for a wide one puts the ring of shapes off both edges. So widen the lens
	// and back off as the viewport gets narrower, which keeps the same subject
	// in frame in either orientation.
	float Aspect = 1.0f;
	if (GEngine != nullptr && GEngine->GameViewport != nullptr)
	{
		FVector2D Size;
		GEngine->GameViewport->GetViewportSize(Size);
		if (Size.X > 0.0f && Size.Y > 0.0f)
		{
			Aspect = Size.X / Size.Y;
		}
	}

	const bool bPortrait = Aspect < 1.0f;
	const float FieldOfView = bPortrait ? 88.0f : 70.0f;
	const float Distance = OrbitDistance * (bPortrait ? 1.28f : 1.0f);

	const float YawRadians = FMath::DegreesToRadians(OrbitYaw);
	const float PitchRadians = FMath::DegreesToRadians(OrbitPitch);

	const float Horizontal = Distance * FMath::Cos(PitchRadians);
	const FVector Focus(0.0f, 0.0f, FocusHeight);
	const FVector Location = Focus + FVector(
		-Horizontal * FMath::Cos(YawRadians),
		-Horizontal * FMath::Sin(YawRadians),
		-Distance * FMath::Sin(PitchRadians));

	Camera->SetActorLocation(Location);
	Camera->SetActorRotation((Focus - Location).Rotation());
	Camera->GetCameraComponent()->SetFieldOfView(FieldOfView);
}

void AFlutterDemoScene::BeginPlay()
{
	Super::BeginPlay();

	if (GetWorld() == nullptr)
	{
		return;
	}

	BuildSky();
	BuildLights();
	BuildShapes();
	BuildCamera();
	TakeOverTheView();

	UE_LOG(LogTemp, Log, TEXT("[FlutterDemoScene] Scene built: %d orbiters, cube %s"),
		Orbiters.Num(), HeroCube ? TEXT("yes") : TEXT("no"));
}

void AFlutterDemoScene::TakeOverTheView()
{
	if (bViewClaimed || Camera == nullptr)
	{
		return;
	}

	APlayerController* Controller = GetWorld()->GetFirstPlayerController();
	if (Controller == nullptr)
	{
		return;
	}

	Controller->SetViewTarget(Camera);

	// Touch has to be switched on explicitly, and the engine's own on-screen
	// stick is off, so the whole surface is free for dragging.
	Controller->bShowMouseCursor = false;
	Controller->bEnableTouchEvents = true;
	Controller->bEnableTouchOverEvents = true;

	// Remove the engine's on-screen sticks. Setting DefaultTouchInterface in
	// the ini would need a re-cook, and this is the same thing at runtime.
	// They are right for a game you drive by hand and wrong for a view sitting
	// under Flutter controls, where they only steal touches from the orbit.
	Controller->ActivateTouchInterface(nullptr);

	bViewClaimed = true;
	UE_LOG(LogTemp, Log, TEXT("[FlutterDemoScene] Camera is the view target"));
}

void AFlutterDemoScene::UpdateOrbitFromTouch(float DeltaSeconds)
{
	APlayerController* Controller = GetWorld()->GetFirstPlayerController();
	if (Controller == nullptr)
	{
		return;
	}

	float X1 = 0.0f, Y1 = 0.0f, X2 = 0.0f, Y2 = 0.0f;
	bool bFirst = false, bSecond = false;
	Controller->GetInputTouchState(ETouchIndex::Touch1, X1, Y1, bFirst);
	Controller->GetInputTouchState(ETouchIndex::Touch2, X2, Y2, bSecond);

	// Two fingers pinch to zoom. Checked first, because during a pinch the
	// first finger is also moving and would otherwise swing the camera at the
	// same time.
	if (bFirst && bSecond)
	{
		const float Spread = FVector2D::Distance(FVector2D(X1, Y1), FVector2D(X2, Y2));

		if (bWasPinching && LastPinchSpread > KINDA_SMALL_NUMBER)
		{
			// Move the camera by the ratio the fingers moved, so the zoom feels
			// the same whether they start close together or far apart.
			OrbitDistance = FMath::Clamp(
				OrbitDistance * (LastPinchSpread / Spread), MinDistance, MaxDistance);
			PositionCamera();
		}

		LastPinchSpread = Spread;
		bWasPinching = true;
		bWasTouching = false;
		bViewerHasTakenOver = true;
		return;
	}

	bWasPinching = false;

	if (bFirst)
	{
		const FVector2D Touch(X1, Y1);

		// Only orbit on the second and later frames of a drag. Using the first
		// one would treat wherever the finger landed as a delta and snap the
		// camera across the scene.
		if (bWasTouching)
		{
			const FVector2D Delta = Touch - LastTouch;
			OrbitYaw += Delta.X * DegreesPerPixelYaw;
			OrbitPitch = FMath::Clamp(
				OrbitPitch + Delta.Y * DegreesPerPixelPitch, MinPitch, MaxPitch);
			PositionCamera();
		}

		LastTouch = Touch;
		bWasTouching = true;
		bViewerHasTakenOver = true;
		return;
	}

	bWasTouching = false;

	// Drift until someone takes over, then leave the camera where they put it.
	if (!bViewerHasTakenOver)
	{
		OrbitYaw += IdleDriftDegreesPerSecond * DeltaSeconds;
		PositionCamera();
	}
}

void AFlutterDemoScene::ReportCameraIfMoved()
{
	// Only once the viewer has taken the camera over. Until then it drifts on
	// its own, and drift crosses any sensible threshold several times a second,
	// so reporting it means a steady stream of messages about a camera nobody
	// is touching.
	if (!bViewerHasTakenOver)
	{
		return;
	}

	// Then only when it actually moved, and no faster than the throttle. A
	// message every frame of a drag would flood the channel and the HUD with
	// values nobody can read.
	const bool bMoved =
		!FMath::IsNearlyEqual(OrbitDistance, LastSentDistance, 1.0f) ||
		!FMath::IsNearlyEqual(OrbitYaw, LastSentYaw, 0.5f) ||
		!FMath::IsNearlyEqual(OrbitPitch, LastSentPitch, 0.5f);

	if (!bMoved || CameraReportCooldown > 0.0f)
	{
		return;
	}

	LastSentDistance = OrbitDistance;
	LastSentYaw = OrbitYaw;
	LastSentPitch = OrbitPitch;
	CameraReportCooldown = 0.1f;

	// Zoom as a fraction of the range, which is what a host actually wants:
	// 0 is as close as the camera goes, 1 as far. The raw distance goes too,
	// for anything that needs the real units.
	const float Zoom = FMath::GetRangePct(MinDistance, MaxDistance, OrbitDistance);

	if (AFlutterBridge* Bridge = AFlutterBridge::GetInstance(this))
	{
		Bridge->SendToFlutter(TEXT("Camera"), TEXT("moved"),
			FString::Printf(
				TEXT("{\"zoom\":%.3f,\"distance\":%.0f,\"yaw\":%.1f,\"pitch\":%.1f}"),
				Zoom, OrbitDistance, OrbitYaw, OrbitPitch));
	}
}

void AFlutterDemoScene::ReportRenderState() const
{
	FString CameraState = TEXT("no camera");
	if (Camera != nullptr)
	{
		if (const UCameraComponent* Component = Camera->GetCameraComponent())
		{
			CameraState = FString::Printf(TEXT("constrain=%d fov=%.1f axisOverride=%d axis=%d"),
				Component->bConstrainAspectRatio ? 1 : 0,
				Component->FieldOfView,
				Component->bOverrideAspectRatioAxisConstraint ? 1 : 0,
				(int32)Component->AspectRatioAxisConstraint.GetValue());
		}
	}

	FString ViewportState = TEXT("no game viewport");
	if (GEngine != nullptr && GEngine->GameViewport != nullptr)
	{
		FVector2D Size = FVector2D::ZeroVector;
		GEngine->GameViewport->GetViewportSize(Size);
		ViewportState = FString::Printf(TEXT("client=%.0fx%.0f"), Size.X, Size.Y);

		if (const FSceneViewport* Scene = GEngine->GameViewport->GetGameViewport())
		{
			const FIntPoint SceneSize = Scene->GetSizeXY();
			ViewportState += FString::Printf(TEXT(" scene=%dx%d"), SceneSize.X, SceneSize.Y);
		}
		else
		{
			ViewportState += TEXT(" scene=none");
		}
	}

	UE_LOG(LogTemp, Log, TEXT("[FlutterDemoScene] render: camera[%s] viewport[%s]"),
		*CameraState, *ViewportState);

	// Also send it to Flutter. The engine's log file is buffered and a reinstall
	// wipes the container, so the HUD panel is the one readout that is reliably
	// there while the thing is actually running.
	if (AFlutterBridge* Bridge = AFlutterBridge::GetInstance(this))
	{
		Bridge->SendToFlutter(TEXT("Scene"), TEXT("renderState"),
			FString::Printf(TEXT("%s | %s"), *CameraState, *ViewportState));
	}
}

void AFlutterDemoScene::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	// The player controller may not exist yet when the scene is built, so keep
	// asking until it does rather than assuming the order.
	if (!bViewClaimed)
	{
		TakeOverTheView();
		return;
	}

	UpdateOrbitFromTouch(DeltaSeconds);

	CameraReportCooldown = FMath::Max(0.0f, CameraReportCooldown - DeltaSeconds);
	ReportCameraIfMoved();

	SceneTime += DeltaSeconds;

	// Report what the renderer is actually doing, once a second. The view and
	// the Metal surface measure correctly from the host side, so anything that
	// still letterboxes has to be visible from in here.
	ReportSeconds += DeltaSeconds;
	if (ReportSeconds >= 3.0f)
	{
		ReportSeconds = 0.0f;
		ReportRenderState();
	}

	const int32 Count = Orbiters.Num();
	for (int32 Index = 0; Index < Count; ++Index)
	{
		AStaticMeshActor* Shape = Orbiters[Index];
		if (Shape == nullptr)
		{
			continue;
		}

		const float Angle = (360.0f / Count) * Index + SceneTime * OrbitDegreesPerSecond;
		const float Radians = FMath::DegreesToRadians(Angle);
		const float Bob = OrbitBobHeight * FMath::Sin(SceneTime * 1.3f + Index);

		Shape->SetActorLocation(FVector(
			OrbitRadius * FMath::Cos(Radians),
			OrbitRadius * FMath::Sin(Radians),
			Bob));
		Shape->AddActorLocalRotation(FRotator(0.0f, 40.0f * DeltaSeconds, 0.0f));
	}
}
