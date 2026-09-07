// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterActor.h"
#include "FlutterBridge.h"
#include "FlutterMessageRouter.h"
#include "FlutterBlueprintLibrary.h"

AFlutterActor::AFlutterActor()
{
	PrimaryActorTick.bCanEverTick = false;
	bAutoRegister = true;
	bIsSingleton = true;
	bIsRegistered = false;
	CachedBridge = nullptr;
	CachedRouter = nullptr;
}

void AFlutterActor::BeginPlay()
{
	Super::BeginPlay();

	if (bAutoRegister)
	{
		RegisterWithFlutter();
	}
}

void AFlutterActor::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (bIsRegistered)
	{
		UnregisterFromFlutter();
	}

	Super::EndPlay(EndPlayReason);
}

// ============================================================
// MARK: - Flutter Configuration
// ============================================================

FString AFlutterActor::GetFlutterTargetName_Implementation() const
{
	// Default to class name
	return GetClass()->GetName();
}

// ============================================================
// MARK: - Message Handling
// ============================================================

void AFlutterActor::HandleFlutterMessage_Implementation(const FString& Method, const FString& Data)
{
	// Default implementation - log message
	UE_LOG(LogTemp, Log, TEXT("[FlutterActor] %s received: Method=%s"), *GetFlutterTargetName(), *Method);
}

void AFlutterActor::HandleFlutterBinaryMessage_Implementation(const FString& Method, const TArray<uint8>& Data)
{
	// Default implementation - log message
	UE_LOG(LogTemp, Log, TEXT("[FlutterActor] %s received binary: Method=%s, Size=%d"), *GetFlutterTargetName(), *Method, Data.Num());
}

// ============================================================
// MARK: - Sending Messages
// ============================================================

void AFlutterActor::SendToFlutter(const FString& Method, const FString& Data)
{
	AFlutterBridge* Bridge = GetFlutterBridge();
	if (Bridge)
	{
		Bridge->SendToFlutter(GetFlutterTargetName(), Method, Data);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterActor] Cannot send message - Flutter bridge not available"));
	}
}

void AFlutterActor::SendJsonToFlutter(const FString& Method, const TMap<FString, FString>& JsonData)
{
	FString JsonString = UFlutterBlueprintLibrary::MapToJsonString(JsonData);
	SendToFlutter(Method, JsonString);
}

void AFlutterActor::SendBinaryToFlutter(const FString& Method, const TArray<uint8>& Data)
{
	AFlutterBridge* Bridge = GetFlutterBridge();
	if (Bridge)
	{
		Bridge->SendBinaryToFlutter(GetFlutterTargetName(), Method, Data);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterActor] Cannot send binary - Flutter bridge not available"));
	}
}

// ============================================================
// MARK: - Utilities
// ============================================================

bool AFlutterActor::IsFlutterAvailable() const
{
	return GetFlutterBridge() != nullptr;
}

AFlutterBridge* AFlutterActor::GetFlutterBridge() const
{
	if (CachedBridge)
	{
		return CachedBridge;
	}

	// Cast away const for caching
	AFlutterActor* MutableThis = const_cast<AFlutterActor*>(this);
	MutableThis->CachedBridge = AFlutterBridge::GetInstance(this);
	return CachedBridge;
}

UFlutterMessageRouter* AFlutterActor::GetFlutterRouter() const
{
	if (CachedRouter)
	{
		return CachedRouter;
	}

	// Cast away const for caching
	AFlutterActor* MutableThis = const_cast<AFlutterActor*>(this);
	MutableThis->CachedRouter = UFlutterMessageRouter::Get(this);
	return CachedRouter;
}

// ============================================================
// MARK: - Registration
// ============================================================

void AFlutterActor::RegisterWithFlutter()
{
	UFlutterMessageRouter* Router = GetFlutterRouter();
	if (Router)
	{
		FString TargetName = GetFlutterTargetName();
		
		// Register target
		Router->RegisterTarget(TargetName, this, bIsSingleton);

		// Register message handler
		FFlutterMethodDelegate MessageDelegate;
		MessageDelegate.BindDynamic(this, &AFlutterActor::OnFlutterMessageInternal);
		Router->RegisterMethod(TargetName, TEXT("*"), MessageDelegate); // Wildcard registration

		bIsRegistered = true;
		UE_LOG(LogTemp, Log, TEXT("[FlutterActor] Registered: %s"), *TargetName);
	}
}

void AFlutterActor::UnregisterFromFlutter()
{
	UFlutterMessageRouter* Router = GetFlutterRouter();
	if (Router && bIsRegistered)
	{
		FString TargetName = GetFlutterTargetName();
		Router->UnregisterTarget(TargetName);
		bIsRegistered = false;
		UE_LOG(LogTemp, Log, TEXT("[FlutterActor] Unregistered: %s"), *TargetName);
	}
}

void AFlutterActor::OnFlutterMessageInternal(const FString& Method, const FString& Data)
{
	// Call the overridable handler
	HandleFlutterMessage(Method, Data);
}

void AFlutterActor::OnFlutterBinaryMessageInternal(const FString& Method, const TArray<uint8>& Data)
{
	// Call the overridable handler
	HandleFlutterBinaryMessage(Method, Data);
}
