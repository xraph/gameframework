#import <Foundation/Foundation.h>

// Forward declaration for Unity framework
@protocol UnityFrameworkListener;
@interface UnityFramework : NSObject
- (void)sendMessageToGOWithName:(const char*)goName functionName:(const char*)name message:(const char*)msg;
@end

// Reference to the UnityEngineController
static id unityEngineController = nil;

// Called from Swift to set the controller reference
extern "C" {
    void SetFlutterBridgeController(void* controller) {
        unityEngineController = (__bridge id)controller;
    }
}

// Called from Unity C# to send message to Flutter
extern "C" {
    void SendMessageToFlutter(const char* target, const char* method, const char* data) {
        if (unityEngineController == nil) {
            NSLog(@"FlutterBridge: Controller not set");
            return;
        }

        NSString* targetStr = [NSString stringWithUTF8String:target];
        NSString* methodStr = [NSString stringWithUTF8String:method];
        NSString* dataStr = [NSString stringWithUTF8String:data];

        // Call the controller's onUnityMessage method
        SEL selector = NSSelectorFromString(@"onUnityMessage:method:data:");
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
            NSLog(@"FlutterBridge: Controller does not respond to onUnityMessage");
        }
    }
}
