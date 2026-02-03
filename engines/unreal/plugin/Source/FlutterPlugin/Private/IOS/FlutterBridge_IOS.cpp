// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterBridge.h"

#if PLATFORM_IOS

// Reference to FlutterBridge instance
static AFlutterBridge* GFlutterBridgeInstance = nullptr;

// ============================================================
// MARK: - Platform Bridge Functions
// ============================================================

/**
 * Send message to Flutter via iOS
 * Called from AFlutterBridge::SendToFlutter()
 * 
 * Note: In a real implementation, this would communicate with the Flutter app
 * via method channels or a custom IPC mechanism.
 */
void FlutterBridge_SendToFlutter_iOS(const FString& Target, const FString& Method, const FString& Data)
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_iOS] SendToFlutter: Target=%s, Method=%s, Data=%s"), 
		*Target, *Method, *Data);
	
	// TODO: Implement actual communication with Flutter
	// This would typically use method channels via the Flutter engine
}

/**
 * Set the FlutterBridge instance
 * Called from AFlutterBridge::BeginPlay()
 */
void FlutterBridge_SetInstance_iOS(AFlutterBridge* Instance)
{
	GFlutterBridgeInstance = Instance;
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_iOS] FlutterBridge instance set"));
}

/**
 * Get the FlutterBridge instance
 */
AFlutterBridge* FlutterBridge_GetInstance_iOS()
{
	return GFlutterBridgeInstance;
}

/**
 * Receive a message from Flutter
 * This should be called from the Flutter side when a message needs to be sent to Unreal
 */
void FlutterBridge_ReceiveFromFlutter_iOS(const FString& Target, const FString& Method, const FString& Data)
{
	if (GFlutterBridgeInstance)
	{
		GFlutterBridgeInstance->ReceiveFromFlutter(Target, Method, Data);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_iOS] Cannot receive from Flutter: Bridge instance not set"));
	}
}

#endif // PLATFORM_IOS
