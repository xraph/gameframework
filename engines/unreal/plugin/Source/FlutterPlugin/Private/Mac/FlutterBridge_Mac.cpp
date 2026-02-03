// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterBridge.h"

#if PLATFORM_MAC

// Reference to FlutterBridge instance
static AFlutterBridge* GFlutterBridgeInstance = nullptr;

// ============================================================
// MARK: - Platform Bridge Functions
// ============================================================

/**
 * Send message to Flutter via macOS
 * Called from AFlutterBridge::SendToFlutter()
 * 
 * Note: In a real implementation, this would communicate with the Flutter app
 * via method channels or a custom IPC mechanism.
 */
void FlutterBridge_SendToFlutter_Mac(const FString& Target, const FString& Method, const FString& Data)
{
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Mac] SendToFlutter: Target=%s, Method=%s, Data=%s"), 
		*Target, *Method, *Data);
	
	// TODO: Implement actual communication with Flutter
	// This would typically use NSNotificationCenter, method channels, or a custom bridge
}

/**
 * Set the FlutterBridge instance
 * Called from AFlutterBridge::BeginPlay()
 */
void FlutterBridge_SetInstance_Mac(AFlutterBridge* Instance)
{
	GFlutterBridgeInstance = Instance;
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Mac] FlutterBridge instance set"));
}

/**
 * Get the FlutterBridge instance
 */
AFlutterBridge* FlutterBridge_GetInstance_Mac()
{
	return GFlutterBridgeInstance;
}

/**
 * Receive a message from Flutter
 * This should be called from the Flutter side when a message needs to be sent to Unreal
 */
void FlutterBridge_ReceiveFromFlutter_Mac(const FString& Target, const FString& Method, const FString& Data)
{
	if (GFlutterBridgeInstance)
	{
		GFlutterBridgeInstance->ReceiveFromFlutter(Target, Method, Data);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Mac] Cannot receive from Flutter: Bridge instance not set"));
	}
}

#endif // PLATFORM_MAC
