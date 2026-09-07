// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "FlutterMessageRouter.h"
#include "FlutterBlueprintLibrary.generated.h"

/**
 * Flutter Blueprint Function Library
 *
 * Provides Blueprint-accessible functions for Flutter integration.
 * Includes utilities for messaging, quality settings, and router configuration.
 *
 * Usage in Blueprints:
 * - Send Flutter Message: Send a message to Flutter
 * - Send Flutter Binary: Send binary data to Flutter
 * - Register Flutter Target: Register an object to receive Flutter messages
 * - Get Flutter Bridge: Get the FlutterBridge actor instance
 */
UCLASS()
class FLUTTERPLUGIN_API UFlutterBlueprintLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	// ============================================================
	// MARK: - Messaging
	// ============================================================

	/**
	 * Send a message to Flutter
	 * @param Target - The target object in Flutter (e.g., "GameManager")
	 * @param Method - The method name to call (e.g., "onGameStateChanged")
	 * @param Data - The data to send (JSON string)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Messaging", meta = (WorldContext = "WorldContextObject"))
	static void SendFlutterMessage(const UObject* WorldContextObject, const FString& Target, const FString& Method, const FString& Data);

	/**
	 * Send a JSON object to Flutter
	 * @param Target - The target object in Flutter
	 * @param Method - The method name to call
	 * @param JsonObject - Map of key-value pairs to send as JSON
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Messaging", meta = (WorldContext = "WorldContextObject"))
	static void SendFlutterJsonMessage(const UObject* WorldContextObject, const FString& Target, const FString& Method, const TMap<FString, FString>& JsonObject);

	/**
	 * Send binary data to Flutter
	 * @param Target - The target object in Flutter
	 * @param Method - The method name to call
	 * @param Data - The binary data to send
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Messaging", meta = (WorldContext = "WorldContextObject"))
	static void SendFlutterBinaryMessage(const UObject* WorldContextObject, const FString& Target, const FString& Method, const TArray<uint8>& Data);

	// ============================================================
	// MARK: - Router Registration
	// ============================================================

	/**
	 * Register a target to receive Flutter messages
	 * @param TargetName - The name to register (e.g., "GameManager")
	 * @param Target - The object to receive messages
	 * @param bIsSingleton - If true, only one instance can be registered
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router", meta = (WorldContext = "WorldContextObject"))
	static void RegisterFlutterTarget(const UObject* WorldContextObject, const FString& TargetName, UObject* Target, bool bIsSingleton = true);

	/**
	 * Unregister a target from receiving Flutter messages
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router", meta = (WorldContext = "WorldContextObject"))
	static void UnregisterFlutterTarget(const UObject* WorldContextObject, const FString& TargetName);

	/**
	 * Check if a target is registered
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router", meta = (WorldContext = "WorldContextObject"))
	static bool IsFlutterTargetRegistered(const UObject* WorldContextObject, const FString& TargetName);

	/**
	 * Get all registered Flutter targets
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router", meta = (WorldContext = "WorldContextObject"))
	static TArray<FFlutterTargetInfo> GetRegisteredFlutterTargets(const UObject* WorldContextObject);

	/**
	 * Get router statistics
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router", meta = (WorldContext = "WorldContextObject"))
	static FFlutterRouterStatistics GetFlutterRouterStatistics(const UObject* WorldContextObject);

	// ============================================================
	// MARK: - Quality Settings
	// ============================================================

	/**
	 * Apply a quality preset
	 * @param QualityLevel - 0=Low, 1=Medium, 2=High, 3=Epic, 4=Cinematic
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Quality", meta = (WorldContext = "WorldContextObject"))
	static void ApplyFlutterQualityPreset(const UObject* WorldContextObject, int32 QualityLevel);

	/**
	 * Apply custom quality settings
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Quality", meta = (WorldContext = "WorldContextObject"))
	static void ApplyFlutterQualitySettings(
		const UObject* WorldContextObject,
		int32 AntiAliasing,
		int32 Shadows,
		int32 PostProcess,
		int32 Textures,
		int32 Effects,
		int32 Foliage,
		int32 ViewDistance
	);

	/**
	 * Get current quality settings
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Quality", meta = (WorldContext = "WorldContextObject"))
	static TMap<FString, int32> GetFlutterQualitySettings(const UObject* WorldContextObject);

	// ============================================================
	// MARK: - Lifecycle
	// ============================================================

	/**
	 * Request to load a level
	 * This will notify Flutter and load the level
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Level", meta = (WorldContext = "WorldContextObject"))
	static void LoadFlutterLevel(const UObject* WorldContextObject, const FString& LevelName);

	/**
	 * Execute a console command via Flutter bridge
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Console", meta = (WorldContext = "WorldContextObject"))
	static void ExecuteFlutterConsoleCommand(const UObject* WorldContextObject, const FString& Command);

	// ============================================================
	// MARK: - Bridge Access
	// ============================================================

	/**
	 * Get the Flutter Bridge actor instance
	 * Returns null if not found
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter", meta = (WorldContext = "WorldContextObject"))
	static class AFlutterBridge* GetFlutterBridge(const UObject* WorldContextObject);

	/**
	 * Get the Flutter Message Router instance
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router", meta = (WorldContext = "WorldContextObject"))
	static UFlutterMessageRouter* GetFlutterRouter(const UObject* WorldContextObject);

	/**
	 * Check if Flutter bridge is available
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter", meta = (WorldContext = "WorldContextObject"))
	static bool IsFlutterBridgeAvailable(const UObject* WorldContextObject);

	// ============================================================
	// MARK: - Utilities
	// ============================================================

	/**
	 * Convert a map to JSON string
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Utilities")
	static FString MapToJsonString(const TMap<FString, FString>& Map);

	/**
	 * Parse JSON string to map
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Utilities")
	static TMap<FString, FString> JsonStringToMap(const FString& JsonString);

	/**
	 * Encode bytes to Base64 string
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Utilities")
	static FString EncodeBase64(const TArray<uint8>& Data);

	/**
	 * Decode Base64 string to bytes
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Utilities")
	static TArray<uint8> DecodeBase64(const FString& Base64String);
};
