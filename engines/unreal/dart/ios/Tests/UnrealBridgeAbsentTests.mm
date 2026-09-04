#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

int main(void) {
    @autoreleasepool {
        Class cls = NSClassFromString(@"UnrealBridge");
        if (!cls) { printf("FAIL: UnrealBridge class not found\n"); return 1; }
        printf("PASS: NSClassFromString found UnrealBridge\n");

        id shared = ((id(*)(id, SEL))objc_msgSend)(cls, NSSelectorFromString(@"shared"));
        if (!shared) { printf("FAIL: shared returned nil\n"); return 1; }
        printf("PASS: shared instance created\n");

        BOOL created = ((BOOL(*)(id, SEL, id, id))objc_msgSend)(
            shared, NSSelectorFromString(@"createWithConfig:controller:"), @{}, (id)shared);
        printf("%s: createWithConfig returned %s with framework absent\n",
               created ? "FAIL" : "PASS", created ? "YES" : "NO");
        if (created) return 1;

        // Everything below must be a safe no-op, not a crash.
        ((void(*)(id, SEL, id, id, id))objc_msgSend)(
            shared, NSSelectorFromString(@"sendMessageWithTarget:method:data:"), @"T", @"M", @"{}");
        ((void(*)(id, SEL, id))objc_msgSend)(
            shared, NSSelectorFromString(@"executeConsoleCommand:"), @"stat fps");
        ((void(*)(id, SEL, id))objc_msgSend)(
            shared, NSSelectorFromString(@"loadLevel:"), @"Main");
        ((void(*)(id, SEL, id))objc_msgSend)(
            shared, NSSelectorFromString(@"applyQualitySettings:"), @{@"qualityLevel": @3});
        ((void(*)(id, SEL))objc_msgSend)(shared, NSSelectorFromString(@"pause"));
        ((void(*)(id, SEL))objc_msgSend)(shared, NSSelectorFromString(@"resume"));

        id q = ((id(*)(id, SEL))objc_msgSend)(shared, NSSelectorFromString(@"getQualitySettings"));
        printf("%s: getQualitySettings returned %lu keys (expected 0)\n",
               ([q count] == 0) ? "PASS" : "FAIL", (unsigned long)[q count]);

        ((void(*)(id, SEL))objc_msgSend)(shared, NSSelectorFromString(@"quit"));
        printf("PASS: all bridge calls survived with no framework loaded\n");
        return 0;
    }
}
