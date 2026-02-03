// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "FlutterMessageRouter.generated.h"

// Forward declarations
class AFlutterBridge;

/**
 * Delegate for handling Flutter messages
 */
DECLARE_DYNAMIC_DELEGATE_TwoParams(FFlutterMethodDelegate, const FString&, Method, const FString&, Data);

/**
 * Delegate for handling Flutter binary messages
 */
DECLARE_DYNAMIC_DELEGATE_TwoParams(FFlutterBinaryMethodDelegate, const FString&, Method, const TArray<uint8>&, Data);

/**
 * Registration info for a Flutter target
 */
USTRUCT(BlueprintType)
struct FFlutterTargetInfo
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	FString TargetName;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	UObject* TargetObject;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	bool bIsSingleton;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	int32 RegisteredMethods;

	FFlutterTargetInfo()
		: TargetObject(nullptr)
		, bIsSingleton(false)
		, RegisteredMethods(0)
	{}
};

/**
 * Statistics for the message router
 */
USTRUCT(BlueprintType)
struct FFlutterRouterStatistics
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	int32 MessagesRouted;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	int32 MessagesDropped;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	int32 RegisteredTargets;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	int32 CachedDelegates;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter")
	int32 QueuedMessages;

	FFlutterRouterStatistics()
		: MessagesRouted(0)
		, MessagesDropped(0)
		, RegisteredTargets(0)
		, CachedDelegates(0)
		, QueuedMessages(0)
	{}
};

/**
 * Queued message for pre-ready delivery
 */
struct FQueuedFlutterMessage
{
	FString Target;
	FString Method;
	FString Data;
	bool bIsBinary;
	TArray<uint8> BinaryData;

	FQueuedFlutterMessage()
		: bIsBinary(false)
	{}
};

/**
 * Flutter Message Router
 *
 * High-performance message router with cached delegates for zero-reflection dispatch.
 * Supports singleton and multi-instance targets, attribute-based method registration,
 * and pre-ready message queuing.
 *
 * Usage:
 * ```cpp
 * // Register a target
 * UFlutterMessageRouter* Router = UFlutterMessageRouter::Get(this);
 * Router->RegisterTarget("GameManager", this, true);
 *
 * // Register a method handler
 * FFlutterMethodDelegate Delegate;
 * Delegate.BindDynamic(this, &AMyActor::OnPlayerAction);
 * Router->RegisterMethod("GameManager", "onPlayerAction", Delegate);
 * ```
 */
UCLASS(BlueprintType)
class FLUTTERPLUGIN_API UFlutterMessageRouter : public UObject
{
	GENERATED_BODY()

public:
	UFlutterMessageRouter();

	// ============================================================
	// MARK: - Singleton Access
	// ============================================================

	/**
	 * Get the global message router instance
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router", meta = (WorldContext = "WorldContextObject"))
	static UFlutterMessageRouter* Get(const UObject* WorldContextObject);

	// ============================================================
	// MARK: - Target Registration
	// ============================================================

	/**
	 * Register a target object that can receive Flutter messages
	 * @param Name - The target name (e.g., "GameManager")
	 * @param Target - The object to receive messages
	 * @param bIsSingleton - If true, only one instance can be registered with this name
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void RegisterTarget(const FString& Name, UObject* Target, bool bIsSingleton = true);

	/**
	 * Unregister a target
	 * @param Name - The target name to unregister
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void UnregisterTarget(const FString& Name);

	/**
	 * Check if a target is registered
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	bool IsTargetRegistered(const FString& Name) const;

	/**
	 * Get all registered targets
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	TArray<FFlutterTargetInfo> GetRegisteredTargets() const;

	// ============================================================
	// MARK: - Method Registration
	// ============================================================

	/**
	 * Register a method handler for a target
	 * @param TargetName - The target that receives the method call
	 * @param MethodName - The method name to handle
	 * @param Delegate - The delegate to call when the method is received
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void RegisterMethod(const FString& TargetName, const FString& MethodName, FFlutterMethodDelegate Delegate);

	/**
	 * Register a binary method handler for a target
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void RegisterBinaryMethod(const FString& TargetName, const FString& MethodName, FFlutterBinaryMethodDelegate Delegate);

	/**
	 * Unregister a method handler
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void UnregisterMethod(const FString& TargetName, const FString& MethodName);

	// ============================================================
	// MARK: - Message Routing
	// ============================================================

	/**
	 * Route a message to the appropriate target
	 * @param Target - The target name
	 * @param Method - The method name
	 * @param Data - The message data (JSON string)
	 * @return True if the message was routed successfully
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	bool RouteMessage(const FString& Target, const FString& Method, const FString& Data);

	/**
	 * Route a binary message to the appropriate target
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	bool RouteBinaryMessage(const FString& Target, const FString& Method, const TArray<uint8>& Data);

	// ============================================================
	// MARK: - Message Queuing
	// ============================================================

	/**
	 * Queue a message for later delivery (e.g., before targets are registered)
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void QueueMessage(const FString& Target, const FString& Method, const FString& Data);

	/**
	 * Flush all queued messages to their targets
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void FlushQueue();

	/**
	 * Clear all queued messages without delivering them
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void ClearQueue();

	// ============================================================
	// MARK: - Statistics
	// ============================================================

	/**
	 * Get routing statistics
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	FFlutterRouterStatistics GetStatistics() const;

	/**
	 * Reset statistics
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void ResetStatistics();

	// ============================================================
	// MARK: - Configuration
	// ============================================================

	/**
	 * Enable or disable message queuing for unknown targets
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void SetQueueUnknownTargets(bool bEnable);

	/**
	 * Set maximum queue size
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Router")
	void SetMaxQueueSize(int32 Size);

private:
	// Singleton instance
	static UFlutterMessageRouter* Instance;

	// Registered targets
	TMap<FString, UObject*> Targets;
	TMap<FString, bool> SingletonFlags;

	// Cached delegates for fast lookup
	TMap<FString, FFlutterMethodDelegate> CachedDelegates;
	TMap<FString, FFlutterBinaryMethodDelegate> CachedBinaryDelegates;

	// Message queue for pre-ready messages
	TArray<FQueuedFlutterMessage> MessageQueue;

	// Configuration
	bool bQueueUnknownTargets;
	int32 MaxQueueSize;

	// Statistics
	mutable FFlutterRouterStatistics Statistics;

	// Helper to generate cache key
	FString GetCacheKey(const FString& Target, const FString& Method) const;

	// Try to route via cached delegate
	bool TryRouteCached(const FString& CacheKey, const FString& Method, const FString& Data);
	bool TryRouteBinaryCached(const FString& CacheKey, const FString& Method, const TArray<uint8>& Data);
};

/**
 * Macro for easy method registration in constructors
 */
#define FLUTTER_REGISTER_METHOD(Router, Target, MethodName, Function) \
	{ \
		FFlutterMethodDelegate Delegate; \
		Delegate.BindDynamic(this, &Function); \
		Router->RegisterMethod(Target, MethodName, Delegate); \
	}
