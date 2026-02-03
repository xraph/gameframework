// Copyright Epic Games, Inc. All Rights Reserved.

// Check if UnrealFramework is available
#if __has_include("FlutterBridge.h")

#import <Foundation/Foundation.h>
#include "FlutterBridge.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Reference to FlutterBridge instance
static AFlutterBridge* GFlutterBridgeInstance = nullptr;

// Reference to UnrealEngineController
static UnrealEngineController* GUnrealEngineController = nullptr;

// ============================================================
// MARK: - Helper Functions
// ============================================================

/**
 * Convert FString to NSString
 */
NSString* FStringToNSString(const FString& String)
{
    return [NSString stringWithUTF8String:TCHAR_TO_UTF8(*String)];
}

/**
 * Convert NSString to FString
 */
FString NSStringToFString(NSString* String)
{
    if (!String)
    {
        return FString();
    }
    return FString(UTF8_TO_TCHAR([String UTF8String]));
}

/**
 * Convert NSDictionary to TMap
 */
TMap<FString, FString> NSDictionaryToTMap(NSDictionary* Dictionary)
{
    TMap<FString, FString> Result;

    if (!Dictionary)
    {
        return Result;
    }

    for (NSString* key in Dictionary)
    {
        NSString* value = [Dictionary objectForKey:key];
        if ([value isKindOfClass:[NSString class]])
        {
            Result.Add(NSStringToFString(key), NSStringToFString(value));
        }
        else
        {
            // Convert other types to string
            NSString* valueStr = [NSString stringWithFormat:@"%@", value];
            Result.Add(NSStringToFString(key), NSStringToFString(valueStr));
        }
    }

    return Result;
}

/**
 * Convert TMap to NSDictionary
 */
NSDictionary* TMapToNSDictionary(const TMap<FString, int32>& Map)
{
    NSMutableDictionary* Dictionary = [NSMutableDictionary dictionary];

    for (const auto& Entry : Map)
    {
        NSString* key = FStringToNSString(Entry.Key);
        NSNumber* value = [NSNumber numberWithInt:Entry.Value];
        [Dictionary setObject:value forKey:key];
    }

    return Dictionary;
}

// ============================================================
// MARK: - UnrealBridge Implementation
// ============================================================

@implementation UnrealBridge

+ (UnrealBridge*)shared {
    static UnrealBridge* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UnrealBridge alloc] init];
    });
    return instance;
}

- (BOOL)createWithConfig:(NSDictionary*)config controller:(UnrealEngineController*)controller {
    NSLog(@"[UnrealBridge] create called");

    // Store controller reference
    GUnrealEngineController = controller;

    // Parse config if needed
    // TMap<FString, FString> ConfigMap = NSDictionaryToTMap(config);

    // Unreal Engine initialization happens automatically
    // This is called after Unreal has already started
    NSLog(@"[UnrealBridge] Unreal Engine initialized");

    return YES;
}

- (UIView*)getView {
    NSLog(@"[UnrealBridge] getView called");

    // On iOS, Unreal Engine manages its own view
    // This would return the Unreal rendering view
    // For now, return nil - the view is handled by Unreal's UIView
    return nil;
}

- (void)pause {
    NSLog(@"[UnrealBridge] pause called");

    if (GFlutterBridgeInstance)
    {
        GFlutterBridgeInstance->OnEnginePause();
    }

    // Pause Unreal Engine rendering
    // This will be handled by Unreal's lifecycle automatically
}

- (void)resume {
    NSLog(@"[UnrealBridge] resume called");

    if (GFlutterBridgeInstance)
    {
        GFlutterBridgeInstance->OnEngineResume();
    }

    // Resume Unreal Engine rendering
    // This will be handled by Unreal's lifecycle automatically
}

- (void)quit {
    NSLog(@"[UnrealBridge] quit called");

    if (GFlutterBridgeInstance)
    {
        GFlutterBridgeInstance->OnEngineQuit();
    }

    // Clean up references
    GUnrealEngineController = nil;
    GFlutterBridgeInstance = nullptr;
}

- (void)sendMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSString*)data {
    FString TargetString = NSStringToFString(target);
    FString MethodString = NSStringToFString(method);
    FString DataString = NSStringToFString(data);

    NSLog(@"[UnrealBridge] sendMessage: Target=%@, Method=%@", target, method);

    if (GFlutterBridgeInstance)
    {
        GFlutterBridgeInstance->ReceiveFromFlutter(TargetString, MethodString, DataString);
    }
    else
    {
        NSLog(@"[UnrealBridge] Warning: FlutterBridge instance not set");
    }
}

- (void)executeConsoleCommand:(NSString*)command {
    FString CommandString = NSStringToFString(command);

    NSLog(@"[UnrealBridge] executeConsoleCommand: %@", command);

    if (GFlutterBridgeInstance)
    {
        GFlutterBridgeInstance->ExecuteConsoleCommand(CommandString);
    }
    else
    {
        NSLog(@"[UnrealBridge] Warning: FlutterBridge instance not set");
    }
}

- (void)loadLevel:(NSString*)levelName {
    FString LevelNameString = NSStringToFString(levelName);

    NSLog(@"[UnrealBridge] loadLevel: %@", levelName);

    if (GFlutterBridgeInstance)
    {
        GFlutterBridgeInstance->LoadLevel(LevelNameString);
    }
    else
    {
        NSLog(@"[UnrealBridge] Warning: FlutterBridge instance not set");
    }
}

- (void)applyQualitySettings:(NSDictionary*)settings {
    NSLog(@"[UnrealBridge] applyQualitySettings called");

    if (!GFlutterBridgeInstance)
    {
        NSLog(@"[UnrealBridge] Warning: FlutterBridge instance not set");
        return;
    }

    // Parse settings
    TMap<FString, FString> SettingsMap = NSDictionaryToTMap(settings);

    // Extract quality settings
    int32 QualityLevel = SettingsMap.Contains(TEXT("qualityLevel")) ?
        FCString::Atoi(*SettingsMap[TEXT("qualityLevel")]) : -1;
    int32 AntiAliasing = SettingsMap.Contains(TEXT("antiAliasingQuality")) ?
        FCString::Atoi(*SettingsMap[TEXT("antiAliasingQuality")]) : -1;
    int32 Shadow = SettingsMap.Contains(TEXT("shadowQuality")) ?
        FCString::Atoi(*SettingsMap[TEXT("shadowQuality")]) : -1;
    int32 PostProcess = SettingsMap.Contains(TEXT("postProcessQuality")) ?
        FCString::Atoi(*SettingsMap[TEXT("postProcessQuality")]) : -1;
    int32 Texture = SettingsMap.Contains(TEXT("textureQuality")) ?
        FCString::Atoi(*SettingsMap[TEXT("textureQuality")]) : -1;
    int32 Effects = SettingsMap.Contains(TEXT("effectsQuality")) ?
        FCString::Atoi(*SettingsMap[TEXT("effectsQuality")]) : -1;
    int32 Foliage = SettingsMap.Contains(TEXT("foliageQuality")) ?
        FCString::Atoi(*SettingsMap[TEXT("foliageQuality")]) : -1;
    int32 ViewDistance = SettingsMap.Contains(TEXT("viewDistanceQuality")) ?
        FCString::Atoi(*SettingsMap[TEXT("viewDistanceQuality")]) : -1;

    // Apply settings
    GFlutterBridgeInstance->ApplyQualitySettings(
        QualityLevel,
        AntiAliasing,
        Shadow,
        PostProcess,
        Texture,
        Effects,
        Foliage,
        ViewDistance
    );
}

- (NSDictionary*)getQualitySettings {
    NSLog(@"[UnrealBridge] getQualitySettings called");

    if (!GFlutterBridgeInstance)
    {
        NSLog(@"[UnrealBridge] Warning: FlutterBridge instance not set");
        return @{};
    }

    // Get quality settings from Unreal
    TMap<FString, int32> Settings = GFlutterBridgeInstance->GetQualitySettings();

    // Convert to NSDictionary
    return TMapToNSDictionary(Settings);
}

// ============================================================
// MARK: - Callbacks from Unreal to Flutter
// ============================================================

- (void)notifyMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSString*)data {
    NSLog(@"[UnrealBridge] notifyMessage: Target=%@, Method=%@", target, method);

    if (GUnrealEngineController)
    {
        [GUnrealEngineController onMessageFromUnrealWithTarget:target method:method data:data];
    }
    else
    {
        NSLog(@"[UnrealBridge] Warning: UnrealEngineController not set");
    }
}

- (void)notifyLevelLoadedWithLevelName:(NSString*)levelName buildIndex:(NSInteger)buildIndex {
    NSLog(@"[UnrealBridge] notifyLevelLoaded: %@", levelName);

    if (GUnrealEngineController)
    {
        [GUnrealEngineController onLevelLoadedWithLevelName:levelName buildIndex:(int)buildIndex];
    }
    else
    {
        NSLog(@"[UnrealBridge] Warning: UnrealEngineController not set");
    }
}

@end

// ============================================================
// MARK: - C++ Interface for Unreal Engine
// ============================================================

/**
 * Send message to Flutter via Objective-C++
 * Called from AFlutterBridge::SendToFlutter()
 */
void FlutterBridge_SendToFlutter_iOS(const FString& Target, const FString& Method, const FString& Data)
{
    NSString* nsTarget = FStringToNSString(Target);
    NSString* nsMethod = FStringToNSString(Method);
    NSString* nsData = FStringToNSString(Data);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[UnrealBridge shared] notifyMessageWithTarget:nsTarget method:nsMethod data:nsData];
    });

    UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_iOS] Message sent to Flutter: Target=%s, Method=%s"),
        *Target, *Method);
}

/**
 * Notify Flutter that a level has been loaded
 */
void FlutterBridge_NotifyLevelLoaded_iOS(const FString& LevelName, int32 BuildIndex)
{
    NSString* nsLevelName = FStringToNSString(LevelName);

    dispatch_async(dispatch_get_main_queue(), ^{
        [[UnrealBridge shared] notifyLevelLoadedWithLevelName:nsLevelName buildIndex:BuildIndex];
    });

    UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_iOS] Level loaded notification sent: %s"), *LevelName);
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

#else
// Stub implementation when UnrealFramework is not available
// This allows the plugin to compile during development without Unreal Engine

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Forward declare the Swift class to avoid import issues
@class UnrealEngineController;

@interface UnrealBridge : NSObject
+ (UnrealBridge*)shared;
- (BOOL)createWithConfig:(NSDictionary*)config controller:(id)controller;
- (UIView*)getView;
- (void)pause;
- (void)resume;
- (void)quit;
- (void)sendMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSString*)data;
- (void)executeConsoleCommand:(NSString*)command;
- (void)loadLevel:(NSString*)levelName;
- (void)applyQualitySettings:(NSDictionary*)settings;
- (NSDictionary*)getQualitySettings;
- (void)sendBinaryMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSData*)data checksum:(NSInteger)checksum;
- (void)binaryChunkHeaderWithTarget:(NSString*)target method:(NSString*)method transferId:(NSString*)transferId totalSize:(NSInteger)totalSize totalChunks:(NSInteger)totalChunks checksum:(NSInteger)checksum;
- (void)binaryChunkDataWithTarget:(NSString*)target method:(NSString*)method transferId:(NSString*)transferId chunkIndex:(NSInteger)chunkIndex data:(NSData*)data;
- (void)binaryChunkFooterWithTarget:(NSString*)target method:(NSString*)method transferId:(NSString*)transferId totalChunks:(NSInteger)totalChunks checksum:(NSInteger)checksum;
- (void)setBinaryChunkSize:(NSInteger)size;
@end

@implementation UnrealBridge

+ (UnrealBridge*)shared {
    static UnrealBridge* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UnrealBridge alloc] init];
    });
    return instance;
}

- (BOOL)createWithConfig:(NSDictionary*)config controller:(id)controller {
    NSLog(@"[UnrealBridge] Stub: create called (UnrealFramework not available)");
    return NO;
}

- (UIView*)getView {
    NSLog(@"[UnrealBridge] Stub: getView called (UnrealFramework not available)");
    return nil;
}

- (void)pause {
    NSLog(@"[UnrealBridge] Stub: pause called (UnrealFramework not available)");
}

- (void)resume {
    NSLog(@"[UnrealBridge] Stub: resume called (UnrealFramework not available)");
}

- (void)quit {
    NSLog(@"[UnrealBridge] Stub: quit called (UnrealFramework not available)");
}

- (void)sendMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSString*)data {
    NSLog(@"[UnrealBridge] Stub: sendMessage called (UnrealFramework not available)");
}

- (void)executeConsoleCommand:(NSString*)command {
    NSLog(@"[UnrealBridge] Stub: executeConsoleCommand called (UnrealFramework not available)");
}

- (void)loadLevel:(NSString*)levelName {
    NSLog(@"[UnrealBridge] Stub: loadLevel called (UnrealFramework not available)");
}

- (void)applyQualitySettings:(NSDictionary*)settings {
    NSLog(@"[UnrealBridge] Stub: applyQualitySettings called (UnrealFramework not available)");
}

- (NSDictionary*)getQualitySettings {
    NSLog(@"[UnrealBridge] Stub: getQualitySettings called (UnrealFramework not available)");
    return @{};
}

- (void)sendBinaryMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSData*)data checksum:(NSInteger)checksum {
    NSLog(@"[UnrealBridge] Stub: sendBinaryMessage called (UnrealFramework not available)");
}

- (void)binaryChunkHeaderWithTarget:(NSString*)target method:(NSString*)method transferId:(NSString*)transferId totalSize:(NSInteger)totalSize totalChunks:(NSInteger)totalChunks checksum:(NSInteger)checksum {
    NSLog(@"[UnrealBridge] Stub: binaryChunkHeader called (UnrealFramework not available)");
}

- (void)binaryChunkDataWithTarget:(NSString*)target method:(NSString*)method transferId:(NSString*)transferId chunkIndex:(NSInteger)chunkIndex data:(NSData*)data {
    NSLog(@"[UnrealBridge] Stub: binaryChunkData called (UnrealFramework not available)");
}

- (void)binaryChunkFooterWithTarget:(NSString*)target method:(NSString*)method transferId:(NSString*)transferId totalChunks:(NSInteger)totalChunks checksum:(NSInteger)checksum {
    NSLog(@"[UnrealBridge] Stub: binaryChunkFooter called (UnrealFramework not available)");
}

- (void)setBinaryChunkSize:(NSInteger)size {
    NSLog(@"[UnrealBridge] Stub: setBinaryChunkSize called (UnrealFramework not available)");
}

@end

#endif // __has_include("FlutterBridge.h")
