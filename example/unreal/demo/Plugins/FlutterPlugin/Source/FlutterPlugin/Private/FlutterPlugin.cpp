// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterPlugin.h"

#define LOCTEXT_NAMESPACE "FFlutterPluginModule"

void FFlutterPluginModule::StartupModule()
{
	// This code will execute after your module is loaded into memory
	UE_LOG(LogTemp, Log, TEXT("FlutterPlugin module started"));
}

void FFlutterPluginModule::ShutdownModule()
{
	// This function may be called during shutdown to clean up your module
	UE_LOG(LogTemp, Log, TEXT("FlutterPlugin module shutdown"));
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(FFlutterPluginModule, FlutterPlugin)
