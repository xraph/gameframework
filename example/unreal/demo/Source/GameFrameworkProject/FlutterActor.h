// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FlutterActor.generated.h"

// Forward declarations
class AFlutterBridge;
class UFlutterMessageRouter;

/**
 * Flutter Actor - Base class for Actors that integrate with Flutter
 *
 * Provides automatic registration with the Flutter message router
 * and convenient methods for Flutter communication.
 *
 * Usage:
 * 1. Create a subclass of AFlutterActor
 * 2. Override GetFlutterTargetName() to set your target name
 * 3. Implement HandleFlutterMessage() for custom message handling
 * 4. Use SendToFlutter() to send messages back
 *
 * Example:
 * ```cpp
 * UCLASS()
 * class AMyGameActor : public AFlutterActor
 * {
 *     GENERATED_BODY()
 *
 * protected:
 *     virtual FString GetFlutterTargetName() const override { return TEXT("MyGameActor"); }
 *
 *     virtual void HandleFlutterMessage_Implementation(const FString& Method, const FString& Data) override
 *     {
 *         if (Method == TEXT("doAction"))
 *         {
 *             // Handle action
 *             SendToFlutter(TEXT("actionComplete"), TEXT("{}"));
 *         }
 *     }
 * };
 * ```
 */
UCLASS(Abstract, Blueprintable, BlueprintType)
class AFlutterActor : public AActor
{
	GENERATED_BODY()

public:
	AFlutterActor();

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:
	// ============================================================
	// MARK: - Flutter Configuration
	// ============================================================

	/**
	 * Get the target name this actor registers as
	 * Override in subclasses to set custom target name
	 */
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Flutter")
	FString GetFlutterTargetName() const;
	virtual FString GetFlutterTargetName_Implementation() const;

	/**
	 * Whether this actor should auto-register with the Flutter router
	 */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Flutter")
	bool bAutoRegister;

	/**
	 * Whether this is a singleton (only one instance can be registered)
	 */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Flutter")
	bool bIsSingleton;

	// ============================================================
	// MARK: - Message Handling
	// ============================================================

	/**
	 * Called when a message is received from Flutter
	 * Override in subclasses or Blueprint to handle messages
	 */
	UFUNCTION(BlueprintNativeEvent, Category = "Flutter")
	void HandleFlutterMessage(const FString& Method, const FString& Data);
	virtual void HandleFlutterMessage_Implementation(const FString& Method, const FString& Data);

	/**
	 * Called when binary data is received from Flutter
	 */
	UFUNCTION(BlueprintNativeEvent, Category = "Flutter")
	void HandleFlutterBinaryMessage(const FString& Method, const TArray<uint8>& Data);
	virtual void HandleFlutterBinaryMessage_Implementation(const FString& Method, const TArray<uint8>& Data);

	// ============================================================
	// MARK: - Sending Messages
	// ============================================================

	/**
	 * Send a message to Flutter
	 * @param Method - The method name (e.g., "onStateChanged")
	 * @param Data - The data to send (JSON string)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	void SendToFlutter(const FString& Method, const FString& Data);

	/**
	 * Send JSON data to Flutter
	 * @param Method - The method name
	 * @param JsonData - Key-value pairs to send as JSON
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	void SendJsonToFlutter(const FString& Method, const TMap<FString, FString>& JsonData);

	/**
	 * Send binary data to Flutter
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	void SendBinaryToFlutter(const FString& Method, const TArray<uint8>& Data);

	// ============================================================
	// MARK: - Utilities
	// ============================================================

	/**
	 * Check if Flutter bridge is available
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	bool IsFlutterAvailable() const;

	/**
	 * Get the Flutter bridge instance
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	AFlutterBridge* GetFlutterBridge() const;

	/**
	 * Get the Flutter message router
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	UFlutterMessageRouter* GetFlutterRouter() const;

protected:
	/**
	 * Register this actor with the Flutter router
	 */
	virtual void RegisterWithFlutter();

	/**
	 * Unregister this actor from the Flutter router
	 */
	virtual void UnregisterFromFlutter();

	/**
	 * Internal callback for message routing
	 */
	UFUNCTION()
	void OnFlutterMessageInternal(const FString& Method, const FString& Data);

	/**
	 * Internal callback for binary message routing
	 */
	UFUNCTION()
	void OnFlutterBinaryMessageInternal(const FString& Method, const TArray<uint8>& Data);

private:
	// Cached references
	UPROPERTY()
	AFlutterBridge* CachedBridge;

	UPROPERTY()
	UFlutterMessageRouter* CachedRouter;

	// Registration state
	bool bIsRegistered;
};
