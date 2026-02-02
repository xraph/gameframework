#import <Foundation/Foundation.h>

// Forward declaration for Unity framework
@protocol UnityFrameworkListener;
@interface UnityFramework : NSObject
- (void)sendMessageToGOWithName:(const char*)goName functionName:(const char*)name message:(const char*)msg;
- (void)unloadApplication;
- (void)quitApplication;
- (void)pause:(bool)pause;
@end

// Reference to the UnityEngineController
static id unityEngineController = nil;
static UnityFramework* unityFramework = nil;

// Called from Swift to set the controller reference
extern "C" {
    void SetFlutterBridgeController(void* controller) {
        unityEngineController = (__bridge id)controller;
        if (controller != nil) {
            NSLog(@"✅ FlutterBridge: Controller registered successfully");
        } else {
            NSLog(@"⚠️  FlutterBridge: Controller unregistered");
        }
    }
    
    void SetUnityFramework(void* framework) {
        unityFramework = (__bridge UnityFramework*)framework;
        if (framework != nil) {
            NSLog(@"✅ FlutterBridge: Unity framework registered");
        } else {
            NSLog(@"⚠️  FlutterBridge: Unity framework unregistered");
        }
    }
}

// Called from Unity C# to send message to Flutter (structured with target, method, data)
extern "C" {
    void SendMessageToFlutter(const char* target, const char* method, const char* data) {
        if (unityEngineController == nil) {
            NSLog(@"❌ FlutterBridge ERROR: Controller not set - message dropped!");
            NSLog(@"   Target: %s, Method: %s", target ? target : "(null)", method ? method : "(null)");
            NSLog(@"   Fix: Ensure UnityEngineController.registerAsActive() is called before Unity sends messages");
            return;
        }

        NSString* targetStr = target ? [NSString stringWithUTF8String:target] : @"";
        NSString* methodStr = method ? [NSString stringWithUTF8String:method] : @"";
        NSString* dataStr = data ? [NSString stringWithUTF8String:data] : @"";

        NSLog(@"✅ FlutterBridge: Sending message %@.%@", targetStr, methodStr);

        // Call the controller's onUnityMessage method
        SEL selector = NSSelectorFromString(@"onUnityMessageWithTarget:method:data:");
        if ([unityEngineController respondsToSelector:selector]) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                [unityEngineController methodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:unityEngineController];
            [invocation setArgument:&targetStr atIndex:2];
            [invocation setArgument:&methodStr atIndex:3];
            [invocation setArgument:&dataStr atIndex:4];
            [invocation invoke];
        } else {
            NSLog(@"❌ FlutterBridge ERROR: Controller does not respond to onUnityMessage selector");
            NSLog(@"   This may indicate a version mismatch between Unity plugin and Flutter plugin");
        }
    }
}

// NativeAPI Methods - Additional Flutter communication methods

// Send a simple message to Flutter (single string)
extern "C" {
    void _sendMessageToFlutter(const char* message) {
        if (unityEngineController == nil) {
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
        if ([unityEngineController respondsToSelector:selector]) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                [unityEngineController methodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:unityEngineController];
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
    void _showHostMainWindow() {
        dispatch_async(dispatch_get_main_queue(), ^{
            SEL selector = NSSelectorFromString(@"showHostWindow");
            if ([unityEngineController respondsToSelector:selector]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [unityEngineController performSelector:selector];
                #pragma clang diagnostic pop
            } else {
                NSLog(@"NativeAPI: Controller does not respond to showHostWindow");
            }
        });
    }
}

// Unload Unity
extern "C" {
    void _unloadUnity() {
        if (unityFramework != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [unityFramework unloadApplication];
                NSLog(@"NativeAPI: Unity unloaded");
            });
        } else {
            NSLog(@"NativeAPI: Unity framework not set");
        }
    }
}

// Quit Unity
extern "C" {
    void _quitUnity() {
        if (unityFramework != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [unityFramework quitApplication];
                NSLog(@"NativeAPI: Unity quit");
            });
        } else {
            NSLog(@"NativeAPI: Unity framework not set");
        }
    }
}

// Notify Flutter that Unity is ready
extern "C" {
    void _notifyUnityReady() {
        if (unityEngineController == nil) {
            NSLog(@"❌ NativeAPI ERROR: Controller not set - Unity ready notification dropped!");
            NSLog(@"   This is a critical error - Flutter will not know Unity is ready");
            return;
        }
        
        NSString* targetStr = @"Unity";
        NSString* methodStr = @"onReady";
        NSString* dataStr = @"true";
        
        SEL selector = NSSelectorFromString(@"onUnityMessageWithTarget:method:data:");
        if ([unityEngineController respondsToSelector:selector]) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                [unityEngineController methodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:unityEngineController];
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
