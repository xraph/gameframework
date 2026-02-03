// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterBlueprintLibrary.h"
#include "FlutterBridge.h"
#include "FlutterMessageRouter.h"
#include "Misc/Base64.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

// ============================================================
// MARK: - Messaging
// ============================================================

void UFlutterBlueprintLibrary::SendFlutterMessage(const UObject* WorldContextObject, const FString& Target, const FString& Method, const FString& Data)
{
	AFlutterBridge* Bridge = GetFlutterBridge(WorldContextObject);
	if (Bridge)
	{
		Bridge->SendToFlutter(Target, Method, Data);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBlueprintLibrary] Flutter bridge not available"));
	}
}

void UFlutterBlueprintLibrary::SendFlutterJsonMessage(const UObject* WorldContextObject, const FString& Target, const FString& Method, const TMap<FString, FString>& JsonObject)
{
	FString JsonString = MapToJsonString(JsonObject);
	SendFlutterMessage(WorldContextObject, Target, Method, JsonString);
}

void UFlutterBlueprintLibrary::SendFlutterBinaryMessage(const UObject* WorldContextObject, const FString& Target, const FString& Method, const TArray<uint8>& Data)
{
	AFlutterBridge* Bridge = GetFlutterBridge(WorldContextObject);
	if (Bridge)
	{
		Bridge->SendBinaryToFlutter(Target, Method, Data);
	}
	else
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBlueprintLibrary] Flutter bridge not available"));
	}
}

// ============================================================
// MARK: - Router Registration
// ============================================================

void UFlutterBlueprintLibrary::RegisterFlutterTarget(const UObject* WorldContextObject, const FString& TargetName, UObject* Target, bool bIsSingleton)
{
	UFlutterMessageRouter* Router = GetFlutterRouter(WorldContextObject);
	if (Router)
	{
		Router->RegisterTarget(TargetName, Target, bIsSingleton);
	}
}

void UFlutterBlueprintLibrary::UnregisterFlutterTarget(const UObject* WorldContextObject, const FString& TargetName)
{
	UFlutterMessageRouter* Router = GetFlutterRouter(WorldContextObject);
	if (Router)
	{
		Router->UnregisterTarget(TargetName);
	}
}

bool UFlutterBlueprintLibrary::IsFlutterTargetRegistered(const UObject* WorldContextObject, const FString& TargetName)
{
	UFlutterMessageRouter* Router = GetFlutterRouter(WorldContextObject);
	if (Router)
	{
		return Router->IsTargetRegistered(TargetName);
	}
	return false;
}

TArray<FFlutterTargetInfo> UFlutterBlueprintLibrary::GetRegisteredFlutterTargets(const UObject* WorldContextObject)
{
	UFlutterMessageRouter* Router = GetFlutterRouter(WorldContextObject);
	if (Router)
	{
		return Router->GetRegisteredTargets();
	}
	return TArray<FFlutterTargetInfo>();
}

FFlutterRouterStatistics UFlutterBlueprintLibrary::GetFlutterRouterStatistics(const UObject* WorldContextObject)
{
	UFlutterMessageRouter* Router = GetFlutterRouter(WorldContextObject);
	if (Router)
	{
		return Router->GetStatistics();
	}
	return FFlutterRouterStatistics();
}

// ============================================================
// MARK: - Quality Settings
// ============================================================

void UFlutterBlueprintLibrary::ApplyFlutterQualityPreset(const UObject* WorldContextObject, int32 QualityLevel)
{
	AFlutterBridge* Bridge = GetFlutterBridge(WorldContextObject);
	if (Bridge)
	{
		Bridge->ApplyQualitySettingsBP(QualityLevel);
	}
}

void UFlutterBlueprintLibrary::ApplyFlutterQualitySettings(
	const UObject* WorldContextObject,
	int32 AntiAliasing,
	int32 Shadows,
	int32 PostProcess,
	int32 Textures,
	int32 Effects,
	int32 Foliage,
	int32 ViewDistance)
{
	AFlutterBridge* Bridge = GetFlutterBridge(WorldContextObject);
	if (Bridge)
	{
		Bridge->ApplyQualitySettings(-1, AntiAliasing, Shadows, PostProcess, Textures, Effects, Foliage, ViewDistance);
	}
}

TMap<FString, int32> UFlutterBlueprintLibrary::GetFlutterQualitySettings(const UObject* WorldContextObject)
{
	AFlutterBridge* Bridge = GetFlutterBridge(WorldContextObject);
	if (Bridge)
	{
		return Bridge->GetQualitySettings();
	}
	return TMap<FString, int32>();
}

// ============================================================
// MARK: - Lifecycle
// ============================================================

void UFlutterBlueprintLibrary::LoadFlutterLevel(const UObject* WorldContextObject, const FString& LevelName)
{
	AFlutterBridge* Bridge = GetFlutterBridge(WorldContextObject);
	if (Bridge)
	{
		Bridge->LoadLevelBP(LevelName);
	}
}

void UFlutterBlueprintLibrary::ExecuteFlutterConsoleCommand(const UObject* WorldContextObject, const FString& Command)
{
	AFlutterBridge* Bridge = GetFlutterBridge(WorldContextObject);
	if (Bridge)
	{
		Bridge->ExecuteConsoleCommandBP(Command);
	}
}

// ============================================================
// MARK: - Bridge Access
// ============================================================

AFlutterBridge* UFlutterBlueprintLibrary::GetFlutterBridge(const UObject* WorldContextObject)
{
	return AFlutterBridge::GetInstance(WorldContextObject);
}

UFlutterMessageRouter* UFlutterBlueprintLibrary::GetFlutterRouter(const UObject* WorldContextObject)
{
	return UFlutterMessageRouter::Get(WorldContextObject);
}

bool UFlutterBlueprintLibrary::IsFlutterBridgeAvailable(const UObject* WorldContextObject)
{
	return GetFlutterBridge(WorldContextObject) != nullptr;
}

// ============================================================
// MARK: - Utilities
// ============================================================

FString UFlutterBlueprintLibrary::MapToJsonString(const TMap<FString, FString>& Map)
{
	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);

	for (const auto& Pair : Map)
	{
		JsonObject->SetStringField(Pair.Key, Pair.Value);
	}

	FString OutputString;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&OutputString);
	FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

	return OutputString;
}

TMap<FString, FString> UFlutterBlueprintLibrary::JsonStringToMap(const FString& JsonString)
{
	TMap<FString, FString> Result;

	TSharedPtr<FJsonObject> JsonObject;
	TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonString);

	if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
	{
		for (const auto& Pair : JsonObject->Values)
		{
			FString Value;
			if (Pair.Value->TryGetString(Value))
			{
				Result.Add(Pair.Key, Value);
			}
			else
			{
				// Convert non-string values to string representation
				Result.Add(Pair.Key, Pair.Value->AsString());
			}
		}
	}

	return Result;
}

FString UFlutterBlueprintLibrary::EncodeBase64(const TArray<uint8>& Data)
{
	return FBase64::Encode(Data);
}

TArray<uint8> UFlutterBlueprintLibrary::DecodeBase64(const FString& Base64String)
{
	TArray<uint8> Result;
	FBase64::Decode(Base64String, Result);
	return Result;
}
