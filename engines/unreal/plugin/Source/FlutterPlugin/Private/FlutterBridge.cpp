// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterBridge.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "Kismet/GameplayStatics.h"
#include "Scalability.h"
#include "GameFramework/GameUserSettings.h"

// Initialize static instance
AFlutterBridge* AFlutterBridge::Instance = nullptr;

AFlutterBridge::AFlutterBridge()
{
	PrimaryActorTick.bCanEverTick = true;
	bIsPaused = false;
}

void AFlutterBridge::BeginPlay()
{
	Super::BeginPlay();

	// Set as singleton instance
	Instance = this;

	// Initialize platform-specific bridge
	InitializePlatformBridge();

	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Initialized"));
}

void AFlutterBridge::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	// Clear singleton
	if (Instance == this)
	{
		Instance = nullptr;
	}

	Super::EndPlay(EndPlayReason);
}

void AFlutterBridge::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
}

// ============================================================
// MARK: - Singleton Access
// ============================================================

AFlutterBridge* AFlutterBridge::GetInstance(const UObject* WorldContextObject)
{
	if (Instance)
	{
		return Instance;
	}

	// Try to find in world
	if (WorldContextObject)
	{
		UWorld* World = WorldContextObject->GetWorld();
		if (World)
		{
			TArray<AActor*> FoundActors;
			UGameplayStatics::GetAllActorsOfClass(World, AFlutterBridge::StaticClass(), FoundActors);

			if (FoundActors.Num() > 0)
			{
				Instance = Cast<AFlutterBridge>(FoundActors[0]);
				return Instance;
			}
		}
	}

	return nullptr;
}

// ============================================================
// MARK: - Message Communication
// ============================================================

void AFlutterBridge::SendToFlutter(const FString& Target, const FString& Method, const FString& Data)
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Sending to Flutter: Target=%s, Method=%s"), *Target, *Method);

	// This will be implemented in platform-specific code
	// See FlutterBridge_Android.cpp and FlutterBridge_iOS.mm
#if PLATFORM_ANDROID
	// JNI call to Java: UnrealEngineController.onMessageFromUnreal()
	extern void FlutterBridge_SendToFlutter_Android(const FString& Target, const FString& Method, const FString& Data);
	FlutterBridge_SendToFlutter_Android(Target, Method, Data);
#elif PLATFORM_IOS
	// Objective-C++ call to Swift: UnrealBridge.notifyMessage()
	extern void FlutterBridge_SendToFlutter_iOS(const FString& Target, const FString& Method, const FString& Data);
	FlutterBridge_SendToFlutter_iOS(Target, Method, Data);
#elif PLATFORM_MAC
	// Objective-C++ call to Swift: UnrealBridge.notifyMessage()
	extern void FlutterBridge_SendToFlutter_Mac(const FString& Target, const FString& Method, const FString& Data);
	FlutterBridge_SendToFlutter_Mac(Target, Method, Data);
#else
	UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge] SendToFlutter not implemented for this platform"));
#endif
}

void AFlutterBridge::ReceiveFromFlutter(const FString& Target, const FString& Method, const FString& Data)
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Received from Flutter: Target=%s, Method=%s"), *Target, *Method);

	// Fire Blueprint event
	OnMessageFromFlutter(Target, Method, Data);
}

// ============================================================
// MARK: - Console Commands
// ============================================================

void AFlutterBridge::ExecuteConsoleCommand(const FString& Command)
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Executing console command: %s"), *Command);

	if (GEngine && GEngine->GameViewport)
	{
		GEngine->GameViewport->ConsoleCommand(Command);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge] Cannot execute console command: GameViewport not available"));
	}
}

void AFlutterBridge::ExecuteConsoleCommandBP(const FString& Command)
{
	ExecuteConsoleCommand(Command);
}

// ============================================================
// MARK: - Quality Settings
// ============================================================

void AFlutterBridge::ApplyQualitySettings(
	int32 QualityLevel,
	int32 AntiAliasing,
	int32 Shadow,
	int32 PostProcess,
	int32 Texture,
	int32 Effects,
	int32 Foliage,
	int32 ViewDistance)
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Applying quality settings: Level=%d"), QualityLevel);

	// Apply overall quality level if specified
	if (QualityLevel >= 0)
	{
		SetScalabilityQuality(QualityLevel);
	}

	// Apply individual settings if specified
	if (AntiAliasing >= 0) SetAntiAliasingQuality(AntiAliasing);
	if (Shadow >= 0) SetShadowQuality(Shadow);
	if (PostProcess >= 0) SetPostProcessQuality(PostProcess);
	if (Texture >= 0) SetTextureQuality(Texture);
	if (Effects >= 0) SetEffectsQuality(Effects);
	if (Foliage >= 0) SetFoliageQuality(Foliage);
	if (ViewDistance >= 0) SetViewDistanceQuality(ViewDistance);

	// Save settings
	if (UGameUserSettings* Settings = GEngine->GetGameUserSettings())
	{
		Settings->ApplySettings(false);
	}
}

void AFlutterBridge::ApplyQualitySettingsBP(int32 QualityLevel)
{
	ApplyQualitySettings(QualityLevel, -1, -1, -1, -1, -1, -1, -1);
}

TMap<FString, int32> AFlutterBridge::GetQualitySettings()
{
	TMap<FString, int32> Settings;

	Settings.Add(TEXT("antiAliasing"), GetAntiAliasingQuality());
	Settings.Add(TEXT("shadow"), GetShadowQuality());
	Settings.Add(TEXT("postProcess"), GetPostProcessQuality());
	Settings.Add(TEXT("texture"), GetTextureQuality());
	Settings.Add(TEXT("effects"), GetEffectsQuality());
	Settings.Add(TEXT("foliage"), GetFoliageQuality());
	Settings.Add(TEXT("viewDistance"), GetViewDistanceQuality());

	return Settings;
}

TMap<FString, int32> AFlutterBridge::GetQualitySettingsBP()
{
	return GetQualitySettings();
}

// ============================================================
// MARK: - Level Loading
// ============================================================

void AFlutterBridge::LoadLevel(const FString& LevelName)
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Loading level: %s"), *LevelName);

	CurrentLevelName = LevelName;

	if (UWorld* World = GetWorld())
	{
		UGameplayStatics::OpenLevel(World, FName(*LevelName));
	}
}

void AFlutterBridge::LoadLevelBP(const FString& LevelName)
{
	LoadLevel(LevelName);
}

void AFlutterBridge::OnLevelLoaded()
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Level loaded: %s"), *CurrentLevelName);

	// Notify Flutter
	SendToFlutter(TEXT("FlutterBridge"), TEXT("onLevelLoaded"), CurrentLevelName);

	// Fire Blueprint event
	OnLevelLoadedBP(CurrentLevelName);
}

// ============================================================
// MARK: - Lifecycle Events
// ============================================================

void AFlutterBridge::OnEnginePause()
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Engine paused"));
	bIsPaused = true;
	OnEnginePausedBP();
}

void AFlutterBridge::OnEngineResume()
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Engine resumed"));
	bIsPaused = false;
	OnEngineResumedBP();
}

void AFlutterBridge::OnEngineQuit()
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Engine quitting"));
	OnEngineQuitBP();
}

// ============================================================
// MARK: - Platform Bridge Initialization
// ============================================================

void AFlutterBridge::InitializePlatformBridge()
{
#if PLATFORM_ANDROID
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Initializing Android bridge"));
	extern void FlutterBridge_SetInstance_Android(AFlutterBridge* Instance);
	FlutterBridge_SetInstance_Android(this);
#elif PLATFORM_IOS
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Initializing iOS bridge"));
	extern void FlutterBridge_SetInstance_iOS(AFlutterBridge* Instance);
	FlutterBridge_SetInstance_iOS(this);
#elif PLATFORM_MAC
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] Initializing macOS bridge"));
	extern void FlutterBridge_SetInstance_Mac(AFlutterBridge* Instance);
	FlutterBridge_SetInstance_Mac(this);
#else
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge] No platform bridge available"));
#endif
}

// ============================================================
// MARK: - Quality Settings Helpers
// ============================================================

void AFlutterBridge::SetScalabilityQuality(int32 Level)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.SetFromSingleQualityLevel(Level);
	Scalability::SetQualityLevels(QualityLevels);
}

void AFlutterBridge::SetAntiAliasingQuality(int32 Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.AntiAliasingQuality = Quality;
	Scalability::SetQualityLevels(QualityLevels);
}

void AFlutterBridge::SetShadowQuality(int32 Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.ShadowQuality = Quality;
	Scalability::SetQualityLevels(QualityLevels);
}

void AFlutterBridge::SetPostProcessQuality(int32 Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.PostProcessQuality = Quality;
	Scalability::SetQualityLevels(QualityLevels);
}

void AFlutterBridge::SetTextureQuality(int32 Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.TextureQuality = Quality;
	Scalability::SetQualityLevels(QualityLevels);
}

void AFlutterBridge::SetEffectsQuality(int32 Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.EffectsQuality = Quality;
	Scalability::SetQualityLevels(QualityLevels);
}

void AFlutterBridge::SetFoliageQuality(int32 Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.FoliageQuality = Quality;
	Scalability::SetQualityLevels(QualityLevels);
}

void AFlutterBridge::SetViewDistanceQuality(int32 Quality)
{
	Scalability::FQualityLevels QualityLevels = Scalability::GetQualityLevels();
	QualityLevels.ViewDistanceQuality = Quality;
	Scalability::SetQualityLevels(QualityLevels);
}

int32 AFlutterBridge::GetAntiAliasingQuality() const
{
	return Scalability::GetQualityLevels().AntiAliasingQuality;
}

int32 AFlutterBridge::GetShadowQuality() const
{
	return Scalability::GetQualityLevels().ShadowQuality;
}

int32 AFlutterBridge::GetPostProcessQuality() const
{
	return Scalability::GetQualityLevels().PostProcessQuality;
}

int32 AFlutterBridge::GetTextureQuality() const
{
	return Scalability::GetQualityLevels().TextureQuality;
}

int32 AFlutterBridge::GetEffectsQuality() const
{
	return Scalability::GetQualityLevels().EffectsQuality;
}

int32 AFlutterBridge::GetFoliageQuality() const
{
	return Scalability::GetQualityLevels().FoliageQuality;
}

int32 AFlutterBridge::GetViewDistanceQuality() const
{
	return Scalability::GetQualityLevels().ViewDistanceQuality;
}
