//
//  UnrealBridge.h
//  gameframework_unreal (macOS)
//
//  Objective-C face of the UnrealFramework bridge.
//
//  This header exists so Swift can call the bridge directly. The iOS pod
//  reaches its equivalent class through NSClassFromString and NSInvocation
//  because it has no header to import; declaring the interface here is the
//  same thing without the reflection. If the two pods are ever merged into a
//  shared darwin/ directory, this is the shape to keep.
//
//  NS_SWIFT_NAME keeps the Swift call sites reading naturally, so
//  UnrealEngineController can say UnrealBridge.shared.create(config:controller:)
//  rather than createWithConfig(_:controller:).
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface UnrealBridge : NSObject

@property (class, nonatomic, readonly) UnrealBridge *shared;

/// Register the controller and wire up callbacks from Unreal.
/// Returns NO when UnrealFramework is not loaded into this process.
- (BOOL)createWithConfig:(NSDictionary *)config
              controller:(id)controller NS_SWIFT_NAME(create(config:controller:));

/// Unreal owns its own window on macOS, so this is always nil today. It stays
/// on the interface because the controller's view plumbing expects it.
- (nullable NSView *)getView;

- (void)pause;
- (void)resume;
- (void)quit;

- (void)sendMessageWithTarget:(NSString *)target
                       method:(NSString *)method
                         data:(NSString *)data NS_SWIFT_NAME(sendMessage(target:method:data:));

- (void)sendBinaryWithTarget:(NSString *)target
                      method:(NSString *)method
                        data:(NSData *)data NS_SWIFT_NAME(sendBinary(target:method:data:));

- (void)executeConsoleCommand:(NSString *)command;

- (void)loadLevel:(NSString *)levelName;

- (void)applyQualitySettings:(NSDictionary *)settings;

- (NSDictionary *)getQualitySettings;

@end

NS_ASSUME_NONNULL_END
