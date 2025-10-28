// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FlutterBridge.generated.h"

/**
 * Flutter Bridge Actor
 *
 * Main bridge between Flutter and Unreal Engine.
 * Handles bidirectional communication, console commands, quality settings,
 * and level loading.
 */
UCLASS(Blueprintable, BlueprintType)
class FLUTTERPLUGIN_API AFlutterBridge : public AActor
{
	GENERATED_BODY()

public:
	AFlutterBridge();

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:
	virtual void Tick(float DeltaTime) override;

	// ============================================================
	// MARK: - Message Communication
	// ============================================================

	/**
	 * Send a message to Flutter
	 * @param Target - The target object in Flutter (e.g., "GameManager")
	 * @param Method - The method name to call (e.g., "onGameStateChanged")
	 * @param Data - The data to send (JSON string)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	void SendToFlutter(const FString& Target, const FString& Method, const FString& Data);

	/**
	 * Called when a message is received from Flutter
	 * This is called from native code (JNI/Objective-C++)
	 * @param Target - The target object in Unreal (e.g., "PlayerController")
	 * @param Method - The method name to call
	 * @param Data - The data received (JSON string)
	 */
	void ReceiveFromFlutter(const FString& Target, const FString& Method, const FString& Data);

	/**
	 * Blueprint event fired when a message is received from Flutter
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter")
	void OnMessageFromFlutter(const FString& Target, const FString& Method, const FString& Data);

	// ============================================================
	// MARK: - Console Commands
	// ============================================================

	/**
	 * Execute a console command
	 * Called from Flutter via native bridge
	 * @param Command - The console command to execute (e.g., "stat fps")
	 */
	void ExecuteConsoleCommand(const FString& Command);

	/**
	 * Execute a console command (Blueprint callable)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Console")
	void ExecuteConsoleCommandBP(const FString& Command);

	// ============================================================
	// MARK: - Quality Settings
	// ============================================================

	/**
	 * Apply quality settings from Flutter
	 * @param QualityLevel - Overall quality level (0-4: Low, Medium, High, Epic, Cinematic)
	 * @param AntiAliasing - Anti-aliasing quality (0-4)
	 * @param Shadow - Shadow quality (0-4)
	 * @param PostProcess - Post-processing quality (0-4)
	 * @param Texture - Texture quality (0-4)
	 * @param Effects - Effects quality (0-4)
	 * @param Foliage - Foliage quality (0-4)
	 * @param ViewDistance - View distance quality (0-4)
	 */
	void ApplyQualitySettings(
		int32 QualityLevel,
		int32 AntiAliasing,
		int32 Shadow,
		int32 PostProcess,
		int32 Texture,
		int32 Effects,
		int32 Foliage,
		int32 ViewDistance
	);

	/**
	 * Apply quality settings (Blueprint callable)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Quality")
	void ApplyQualitySettingsBP(int32 QualityLevel);

	/**
	 * Get current quality settings
	 * @return Map of quality setting names to values
	 */
	TMap<FString, int32> GetQualitySettings();

	/**
	 * Get current quality settings (Blueprint callable)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Quality")
	TMap<FString, int32> GetQualitySettingsBP();

	// ============================================================
	// MARK: - Level Loading
	// ============================================================

	/**
	 * Load a level/map
	 * Called from Flutter via native bridge
	 * @param LevelName - Name of the level to load
	 */
	void LoadLevel(const FString& LevelName);

	/**
	 * Load a level (Blueprint callable)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Level")
	void LoadLevelBP(const FString& LevelName);

	/**
	 * Called when a level has finished loading
	 */
	UFUNCTION()
	void OnLevelLoaded();

	/**
	 * Blueprint event fired when a level is loaded
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Level")
	void OnLevelLoadedBP(const FString& LevelName);

	// ============================================================
	// MARK: - Lifecycle Events
	// ============================================================

	/**
	 * Called when the engine is paused by Flutter
	 */
	void OnEnginePause();

	/**
	 * Called when the engine is resumed by Flutter
	 */
	void OnEngineResume();

	/**
	 * Called when the engine is being quit by Flutter
	 */
	void OnEngineQuit();

	/**
	 * Blueprint events for lifecycle
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Lifecycle")
	void OnEnginePausedBP();

	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Lifecycle")
	void OnEngineResumedBP();

	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Lifecycle")
	void OnEngineQuitBP();

	// ============================================================
	// MARK: - Singleton Access
	// ============================================================

	/**
	 * Get the global FlutterBridge instance
	 * Only one instance should exist in the world
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter", meta = (WorldContext = "WorldContextObject"))
	static AFlutterBridge* GetInstance(const UObject* WorldContextObject);

private:
	// Singleton instance
	static AFlutterBridge* Instance;

	// Current level being loaded
	FString CurrentLevelName;

	// Is engine paused?
	bool bIsPaused;

	// Platform-specific bridge initialization
	void InitializePlatformBridge();

	// Quality setting helpers
	void SetScalabilityQuality(int32 Level);
	void SetAntiAliasingQuality(int32 Quality);
	void SetShadowQuality(int32 Quality);
	void SetPostProcessQuality(int32 Quality);
	void SetTextureQuality(int32 Quality);
	void SetEffectsQuality(int32 Quality);
	void SetFoliageQuality(int32 Quality);
	void SetViewDistanceQuality(int32 Quality);

	// Get individual quality settings
	int32 GetAntiAliasingQuality() const;
	int32 GetShadowQuality() const;
	int32 GetPostProcessQuality() const;
	int32 GetTextureQuality() const;
	int32 GetEffectsQuality() const;
	int32 GetFoliageQuality() const;
	int32 GetViewDistanceQuality() const;
};
