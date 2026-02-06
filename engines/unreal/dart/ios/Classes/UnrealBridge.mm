// Copyright Epic Games, Inc. All Rights Reserved.

// Check if UnrealFramework is available
#if __has_include("FlutterBridge.h")

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "FlutterBridge.h"

// Forward declare the Swift controller class
@class UnrealEngineController;

// Reference to FlutterBridge instance (Unreal Engine side)
static AFlutterBridge* GFlutterBridgeInstance = nullptr;

// Reference to UnrealEngineController (Swift side)
static id GUnrealEngineController = nil;

// ============================================================
// MARK: - Helper Functions
// ============================================================

NSString* FStringToNSString(const FString& String)
{
    return [NSString stringWithUTF8String:TCHAR_TO_UTF8(*String)];
}

FString NSStringToFString(NSString* String)
{
    if (!String) return FString();
    return FString(UTF8_TO_TCHAR([String UTF8String]));
}

TMap<FString, FString> NSDictionaryToTMap(NSDictionary* Dictionary)
{
    TMap<FString, FString> Result;
    if (!Dictionary) return Result;

    for (NSString* key in Dictionary)
    {
        id value = [Dictionary objectForKey:key];
        NSString* valueStr = [value isKindOfClass:[NSString class]] ? value : [NSString stringWithFormat:@"%@", value];
        Result.Add(NSStringToFString(key), NSStringToFString(valueStr));
    }
    return Result;
}

NSDictionary* TMapToNSDictionary(const TMap<FString, int32>& Map)
{
    NSMutableDictionary* Dictionary = [NSMutableDictionary dictionary];
    for (const auto& Entry : Map)
    {
        [Dictionary setObject:@(Entry.Value) forKey:FStringToNSString(Entry.Key)];
    }
    return Dictionary;
}

// ============================================================
// MARK: - UnrealBridge Implementation (with Unreal Framework)
// ============================================================

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
    NSLog(@"[UnrealBridge] create called with config");

    // Store controller reference
    GUnrealEngineController = controller;

    // Unreal Engine initialization happens automatically when framework loads
    NSLog(@"[UnrealBridge] Unreal Engine initialized, controller registered");

    return YES;
}

- (UIView*)getView {
    NSLog(@"[UnrealBridge] getView called");
    // On iOS, Unreal Engine manages its own view hierarchy
    // Return nil - the view is handled by Unreal's window
    return nil;
}

- (void)pause {
    NSLog(@"[UnrealBridge] pause called");
    if (GFlutterBridgeInstance) {
        GFlutterBridgeInstance->OnEnginePause();
    }
}

- (void)resume {
    NSLog(@"[UnrealBridge] resume called");
    if (GFlutterBridgeInstance) {
        GFlutterBridgeInstance->OnEngineResume();
    }
}

- (void)quit {
    NSLog(@"[UnrealBridge] quit called");
    if (GFlutterBridgeInstance) {
        GFlutterBridgeInstance->OnEngineQuit();
    }
    GUnrealEngineController = nil;
    GFlutterBridgeInstance = nullptr;
}

- (void)sendMessageWithTarget:(NSString*)target method:(NSString*)method data:(NSString*)data {
    NSLog(@"[UnrealBridge] sendMessage: Target=%@, Method=%@", target, method);

    if (GFlutterBridgeInstance) {
        FString TargetString = NSStringToFString(target);
        FString MethodString = NSStringToFString(method);
        FString DataString = NSStringToFString(data);
        GFlutterBridgeInstance->ReceiveFromFlutter(TargetString, MethodString, DataString);
    } else {
        NSLog(@"[UnrealBridge] Warning: FlutterBridge instance not set");
    }
}

- (void)executeConsoleCommand:(NSString*)command {
    NSLog(@"[UnrealBridge] executeConsoleCommand: %@", command);
    if (GFlutterBridgeInstance) {
        GFlutterBridgeInstance->ExecuteConsoleCommand(NSStringToFString(command));
    }
}

- (void)loadLevel:(NSString*)levelName {
    NSLog(@"[UnrealBridge] loadLevel: %@", levelName);
    if (GFlutterBridgeInstance) {
        GFlutterBridgeInstance->LoadLevel(NSStringToFString(levelName));
    }
}

- (void)applyQualitySettings:(NSDictionary*)settings {
    NSLog(@"[UnrealBridge] applyQualitySettings called");
    if (!GFlutterBridgeInstance) return;

    TMap<FString, FString> SettingsMap = NSDictionaryToTMap(settings);

    int32 QualityLevel = SettingsMap.Contains(TEXT("qualityLevel")) ? FCString::Atoi(*SettingsMap[TEXT("qualityLevel")]) : -1;
    int32 AntiAliasing = SettingsMap.Contains(TEXT("antiAliasingQuality")) ? FCString::Atoi(*SettingsMap[TEXT("antiAliasingQuality")]) : -1;
    int32 Shadow = SettingsMap.Contains(TEXT("shadowQuality")) ? FCString::Atoi(*SettingsMap[TEXT("shadowQuality")]) : -1;
    int32 PostProcess = SettingsMap.Contains(TEXT("postProcessQuality")) ? FCString::Atoi(*SettingsMap[TEXT("postProcessQuality")]) : -1;
    int32 Texture = SettingsMap.Contains(TEXT("textureQuality")) ? FCString::Atoi(*SettingsMap[TEXT("textureQuality")]) : -1;
    int32 Effects = SettingsMap.Contains(TEXT("effectsQuality")) ? FCString::Atoi(*SettingsMap[TEXT("effectsQuality")]) : -1;
    int32 Foliage = SettingsMap.Contains(TEXT("foliageQuality")) ? FCString::Atoi(*SettingsMap[TEXT("foliageQuality")]) : -1;
    int32 ViewDistance = SettingsMap.Contains(TEXT("viewDistanceQuality")) ? FCString::Atoi(*SettingsMap[TEXT("viewDistanceQuality")]) : -1;

    GFlutterBridgeInstance->ApplyQualitySettings(QualityLevel, AntiAliasing, Shadow, PostProcess, Texture, Effects, Foliage, ViewDistance);
}

- (NSDictionary*)getQualitySettings {
    NSLog(@"[UnrealBridge] getQualitySettings called");
    if (!GFlutterBridgeInstance) return @{};
    return TMapToNSDictionary(GFlutterBridgeInstance->GetQualitySettings());
}

@end

// ============================================================
// MARK: - C++ Interface for Unreal Engine Callbacks
// ============================================================

void FlutterBridge_SendToFlutter_iOS(const FString& Target, const FString& Method, const FString& Data)
{
    NSString* nsTarget = FStringToNSString(Target);
    NSString* nsMethod = FStringToNSString(Method);
    NSString* nsData = FStringToNSString(Data);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (GUnrealEngineController) {
            SEL selector = NSSelectorFromString(@"onMessageFromUnrealWithTarget:method:data:");
            if ([GUnrealEngineController respondsToSelector:selector]) {
                NSMethodSignature* sig = [GUnrealEngineController methodSignatureForSelector:selector];
                NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:GUnrealEngineController];
                [inv setSelector:selector];
                [inv setArgument:&nsTarget atIndex:2];
                [inv setArgument:&nsMethod atIndex:3];
                [inv setArgument:&nsData atIndex:4];
                [inv invoke];
            } else {
                NSLog(@"[UnrealBridge] Controller doesn't respond to onMessageFromUnrealWithTarget:method:data:");
            }
        } else {
            NSLog(@"[UnrealBridge] Warning: Controller not set");
        }
    });

    UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_iOS] Message sent to Flutter: Target=%s, Method=%s"), *Target, *Method);
}

void FlutterBridge_NotifyLevelLoaded_iOS(const FString& LevelName, int32 BuildIndex)
{
    NSString* nsLevelName = FStringToNSString(LevelName);
    NSNumber* nsBuildIndex = @(BuildIndex);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (GUnrealEngineController) {
            SEL selector = NSSelectorFromString(@"onLevelLoadedWithLevelName:buildIndex:");
            if ([GUnrealEngineController respondsToSelector:selector]) {
                NSMethodSignature* sig = [GUnrealEngineController methodSignatureForSelector:selector];
                NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:GUnrealEngineController];
                [inv setSelector:selector];
                [inv setArgument:&nsLevelName atIndex:2];
                NSInteger buildIndexVal = [nsBuildIndex integerValue];
                [inv setArgument:&buildIndexVal atIndex:3];
                [inv invoke];
            }
        }
    });

    UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_iOS] Level loaded: %s"), *LevelName);
}

void FlutterBridge_SetInstance_iOS(AFlutterBridge* Instance)
{
    GFlutterBridgeInstance = Instance;
    UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_iOS] FlutterBridge instance set"));
}

#else
// ============================================================
// MARK: - Stub Implementation (UnrealFramework not available)
// ============================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Reference to controller for stub mode
static id GUnrealEngineController = nil;

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
    GUnrealEngineController = controller;
    // Return NO to indicate Unreal is not actually available
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
    GUnrealEngineController = nil;
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

@end

#endif // __has_include("FlutterBridge.h")
