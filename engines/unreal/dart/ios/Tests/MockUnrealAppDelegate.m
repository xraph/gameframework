/*
 * IOSAppDelegate, as the real UnrealFramework exports it.
 *
 * Shaped to match what UnrealAppDelegate.h redeclares: descends from
 * UIResponder, and carries the Window and IOSView properties. The bridge
 * refuses to start the engine without this class, so the mock framework has to
 * provide it for the same reason the real one does.
 */

#import <UIKit/UIKit.h>

@interface IOSAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, retain, nonatomic) UIWindow* Window;
@property (retain) UIView* IOSView;
@end

@implementation IOSAppDelegate
@end
