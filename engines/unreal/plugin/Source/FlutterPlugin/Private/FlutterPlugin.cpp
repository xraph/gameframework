// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterPlugin.h"

#define LOCTEXT_NAMESPACE "FFlutterPluginModule"

#if PLATFORM_IOS || PLATFORM_MAC
// Defined in Private/FlutterBridge_Apple.cpp.
extern void FlutterBridge_ListenForEngineReady();
#endif

void FFlutterPluginModule::StartupModule()
{
	// This code will execute after your module is loaded into memory
	UE_LOG(LogTemp, Log, TEXT("FlutterPlugin module started"));

#if PLATFORM_IOS || PLATFORM_MAC
	// Subscribe before FAppEntry gets far enough to announce that the config is
	// loaded. This module loads in the PreDefault phase, so it is early enough;
	// registering any later would miss a one-shot broadcast.
	FlutterBridge_ListenForEngineReady();
#endif
}

void FFlutterPluginModule::ShutdownModule()
{
	// This function may be called during shutdown to clean up your module
	UE_LOG(LogTemp, Log, TEXT("FlutterPlugin module shutdown"));
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(FFlutterPluginModule, FlutterPlugin)
