#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Forward declaration for Unity framework
@protocol UnityFrameworkListener;
@interface UnityFramework : NSObject
- (void)sendMessageToGOWithName:(const char*)goName functionName:(const char*)name message:(const char*)msg;
- (void)unloadApplication;
- (void)quitApplication;
- (void)pause:(bool)pause;
@end

// Reference to the UnityEngineController - set via Objective-C runtime lookup
static id unityEngineController = nil;
static UnityFramework* unityFramework = nil;

// Dynamic controller lookup using Objective-C runtime
// This avoids the need for dlsym and works reliably across modules
static id getFlutterController() {
    // First check if we have a cached controller
    if (unityEngineController != nil) {
        return unityEngineController;
    }
    
    // Try to find the registry class from the Flutter plugin
    // The class name includes the module prefix
    NSArray* classNames = @[
        @"gameframework_unity.FlutterBridgeRegistry",
        @"FlutterBridgeRegistry",
        @"_TtC19gameframework_unity21FlutterBridgeRegistry"
    ];
    
    for (NSString* className in classNames) {
        Class registryClass = NSClassFromString(className);
        if (registryClass) {
            SEL selector = NSSelectorFromString(@"sharedController");
            if ([registryClass respondsToSelector:selector]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id controller = [registryClass performSelector:selector];
                #pragma clang diagnostic pop
                if (controller) {
                    NSLog(@"✅ FlutterBridge: Found controller via %@", className);
                    unityEngineController = controller;
                    return controller;
                }
            }
        }
    }
    
    return nil;
}

// Get cached UnityFramework
static UnityFramework* getUnityFrameworkInstance() {
    if (unityFramework != nil) {
        return unityFramework;
    }
    
    // Try to find via registry
    NSArray* classNames = @[
        @"gameframework_unity.FlutterBridgeRegistry",
        @"FlutterBridgeRegistry",
        @"_TtC19gameframework_unity21FlutterBridgeRegistry"
    ];
    
    for (NSString* className in classNames) {
        Class registryClass = NSClassFromString(className);
        if (registryClass) {
            SEL selector = NSSelectorFromString(@"sharedUnityFramework");
            if ([registryClass respondsToSelector:selector]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id framework = [registryClass performSelector:selector];
                #pragma clang diagnostic pop
                if (framework) {
                    NSLog(@"✅ FlutterBridge: Found UnityFramework via %@", className);
                    unityFramework = (UnityFramework*)framework;
                    return unityFramework;
                }
            }
        }
    }
    
    return nil;
}

// Keep the C functions for backwards compatibility, but they're now optional
extern "C" {
    __attribute__((visibility("default")))
    void SetFlutterBridgeController(void* controller) {
        unityEngineController = (__bridge id)controller;
        if (controller != nil) {
            NSLog(@"✅ FlutterBridge: Controller registered via SetFlutterBridgeController");
        } else {
            NSLog(@"⚠️  FlutterBridge: Controller unregistered");
        }
    }
    
    __attribute__((visibility("default")))
    void SetUnityFramework(void* framework) {
        unityFramework = (__bridge UnityFramework*)framework;
        if (framework != nil) {
            NSLog(@"✅ FlutterBridge: Unity framework registered via SetUnityFramework");
        } else {
            NSLog(@"⚠️  FlutterBridge: Unity framework unregistered");
        }
    }
}

// Called from Unity C# to send message to Flutter (structured with target, method, data)
extern "C" {
    __attribute__((visibility("default")))
    void SendMessageToFlutter(const char* target, const char* method, const char* data) {
        // Try to get controller dynamically
        id controller = getFlutterController();
        
        if (controller == nil) {
            NSLog(@"❌ FlutterBridge ERROR: Controller not set - message dropped!");
            NSLog(@"   Target: %s, Method: %s", target ? target : "(null)", method ? method : "(null)");
            NSLog(@"   Fix: Ensure FlutterBridgeRegistry.register() is called before Unity sends messages");
            return;
        }

        NSString* targetStr = target ? [NSString stringWithUTF8String:target] : @"";
        NSString* methodStr = method ? [NSString stringWithUTF8String:method] : @"";
        NSString* dataStr = data ? [NSString stringWithUTF8String:data] : @"";

        NSLog(@"✅ FlutterBridge: Sending message %@.%@", targetStr, methodStr);

        // Call the controller's onUnityMessage method
        SEL selector = NSSelectorFromString(@"onUnityMessageWithTarget:method:data:");
        if ([controller respondsToSelector:selector]) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                [controller methodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:controller];
            [invocation setArgument:&targetStr atIndex:2];
            [invocation setArgument:&methodStr atIndex:3];
            [invocation setArgument:&dataStr atIndex:4];
            [invocation invoke];
        } else {
            NSLog(@"❌ FlutterBridge ERROR: Controller does not respond to onUnityMessage selector");
            NSLog(@"   Available methods on controller:");
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList([controller class], &methodCount);
            for (unsigned int i = 0; i < methodCount && i < 10; i++) {
                NSLog(@"   - %@", NSStringFromSelector(method_getName(methods[i])));
            }
            if (methods) free(methods);
        }
    }
}

// NativeAPI Methods - Additional Flutter communication methods

// Send a simple message to Flutter (single string)
extern "C" {
    __attribute__((visibility("default")))
    void _sendMessageToFlutter(const char* message) {
        id controller = getFlutterController();
        
        if (controller == nil) {
            NSLog(@"❌ NativeAPI ERROR: Controller not set - message dropped!");
            NSLog(@"   Message: %s", message ? message : "(null)");
            return;
        }

        NSString* messageStr = message ? [NSString stringWithUTF8String:message] : @"";
        
        // Send as Unity:onMessage
        NSString* targetStr = @"Unity";
        NSString* methodStr = @"onMessage";
        
        NSLog(@"✅ NativeAPI: Sending simple message to Flutter");
        
        SEL selector = NSSelectorFromString(@"onUnityMessageWithTarget:method:data:");
        if ([controller respondsToSelector:selector]) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                [controller methodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:controller];
            [invocation setArgument:&targetStr atIndex:2];
            [invocation setArgument:&methodStr atIndex:3];
            [invocation setArgument:&messageStr atIndex:4];
            [invocation invoke];
        } else {
            NSLog(@"❌ NativeAPI ERROR: Controller does not respond to onUnityMessage selector");
        }
    }
}

// Show the Flutter host window
extern "C" {
    __attribute__((visibility("default")))
    void _showHostMainWindow() {
        dispatch_async(dispatch_get_main_queue(), ^{
            id controller = getFlutterController();
            if (controller == nil) return;
            
            SEL selector = NSSelectorFromString(@"showHostWindow");
            if ([controller respondsToSelector:selector]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [controller performSelector:selector];
                #pragma clang diagnostic pop
            } else {
                NSLog(@"NativeAPI: Controller does not respond to showHostWindow");
            }
        });
    }
}

// Unload Unity
extern "C" {
    __attribute__((visibility("default")))
    void _unloadUnity() {
        UnityFramework* framework = getUnityFrameworkInstance();
        if (framework != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [framework unloadApplication];
                NSLog(@"NativeAPI: Unity unloaded");
            });
        } else {
            NSLog(@"NativeAPI: Unity framework not set");
        }
    }
}

// Quit Unity
extern "C" {
    __attribute__((visibility("default")))
    void _quitUnity() {
        UnityFramework* framework = getUnityFrameworkInstance();
        if (framework != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [framework quitApplication];
                NSLog(@"NativeAPI: Unity quit");
            });
        } else {
            NSLog(@"NativeAPI: Unity framework not set");
        }
    }
}

// Notify Flutter that Unity is ready
extern "C" {
    __attribute__((visibility("default")))
    void _notifyUnityReady() {
        id controller = getFlutterController();
        
        if (controller == nil) {
            NSLog(@"❌ NativeAPI ERROR: Controller not set - Unity ready notification dropped!");
            NSLog(@"   This is a critical error - Flutter will not know Unity is ready");
            return;
        }
        
        NSString* targetStr = @"Unity";
        NSString* methodStr = @"onReady";
        NSString* dataStr = @"true";
        
        SEL selector = NSSelectorFromString(@"onUnityMessageWithTarget:method:data:");
        if ([controller respondsToSelector:selector]) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                [controller methodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:controller];
            [invocation setArgument:&targetStr atIndex:2];
            [invocation setArgument:&methodStr atIndex:3];
            [invocation setArgument:&dataStr atIndex:4];
            [invocation invoke];
            
            NSLog(@"✅ NativeAPI: Notified Flutter that Unity is ready");
        } else {
            NSLog(@"❌ NativeAPI ERROR: Controller does not respond to onUnityMessage selector");
        }
    }
}

// Clear cached references (call when controller is being destroyed)
extern "C" {
    __attribute__((visibility("default")))
    void ClearFlutterBridgeReferences() {
        unityEngineController = nil;
        unityFramework = nil;
        NSLog(@"✅ FlutterBridge: References cleared");
    }
}
