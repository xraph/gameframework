// Every bridge call must be a safe no-op when UnrealFramework is not loaded.

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "UnrealBridge.h"

int main(void) {
    @autoreleasepool {
        UnrealBridge* bridge = UnrealBridge.shared;
        if (!bridge) { printf("FAIL: no shared instance\n"); return 1; }
        printf("PASS: shared instance created\n");

        BOOL created = [bridge createWithConfig:@{} controller:bridge];
        printf("%s: createWithConfig returned %s with framework absent\n",
               created ? "FAIL" : "PASS", created ? "YES" : "NO");
        if (created) return 1;

        [bridge sendMessageWithTarget:@"T" method:@"M" data:@"{}"];
        [bridge sendBinaryWithTarget:@"T" method:@"M" data:[NSData data]];
        [bridge executeConsoleCommand:@"stat fps"];
        [bridge loadLevel:@"Main"];
        [bridge applyQualitySettings:@{@"qualityLevel": @3}];
        [bridge pause];
        [bridge resume];

        NSDictionary* q = [bridge getQualitySettings];
        printf("%s: getQualitySettings returned %lu keys (expected 0)\n",
               (q.count == 0) ? "PASS" : "FAIL", (unsigned long)q.count);

        [bridge quit];
        printf("PASS: all bridge calls survived with no framework loaded\n");
        return 0;
    }
}
