// Starting Unreal, and getting a view out of it, on macOS.
//
// None of this mirrors the iOS path, because the engine does not offer the same
// thing twice. On iOS Epic wrote an embedded mode: FIOSView, a delegate that
// caches itself, and StartupEmbeddedUnreal to boot the lot. On Mac there is no
// embedded anything. BUILD_EMBEDDED_APP is defined only by UEBuildIOS, and the
// only embedded view code in the engine sits under ApplicationCore/*/IOS.
//
// So this does by hand what the Mac app delegate normally does. It starts the
// game thread the same way LaunchMac does, then waits for the engine to make
// its own window and lends the host that window's view. The engine still
// believes it owns a window; it simply never gets shown.

#include "CoreMinimal.h"

#if PLATFORM_MAC

#include "UnrealBridge.h"

#include "Mac/CocoaThread.h"
#include "Mac/CocoaWindow.h"
#include "Misc/CommandLine.h"

#import <Cocoa/Cocoa.h>

#include <atomic>

/// The engine's entry point, as LaunchMac declares it.
extern int32 GuardedMain(const TCHAR* CmdLine);

namespace
{
	std::atomic<bool> GEngineStartRequested{false};

	/// The view lent to the host, and the window it came from.
	NSView* GEmbeddedView = nil;
	FCocoaWindow* GEngineWindow = nil;

	/// The command line handed to GuardedMain.
	///
	/// Mac keeps its own in LaunchMac.cpp as a file-static, so there is nothing
	/// to share, and the engine takes it as an argument anyway. Held here rather
	/// than on the stack because the game thread reads it after this returns.
	FString GEmbeddedCommandLine;

	/// Find the window the engine made for itself.
	///
	/// It arrives some time after the game thread starts, so this returns nil
	/// until it does and the host keeps asking, the same as on iOS.
	FCocoaWindow* FindEngineWindow()
	{
		for (NSWindow* Window in [NSApp windows])
		{
			if ([Window isKindOfClass:[FCocoaWindow class]])
			{
				return (FCocoaWindow*)Window;
			}
		}
		return nil;
	}
}

/// Runs GuardedMain, so the game thread has something to call.
@interface FlutterUnrealLauncher : NSObject
- (void)runGameThread:(id)Argument;
@end

@implementation FlutterUnrealLauncher
- (void)runGameThread:(id)Argument
{
	GuardedMain(*GEmbeddedCommandLine);
}
@end

extern "C" {

int32_t UnrealBridge_StartEngine(void)
{
	if (GEngineStartRequested.exchange(true))
	{
		return 1;
	}

	// The command line normally comes from argv. There is no argv in a library,
	// so the engine gets an empty one and reads the rest from its own config.
	GEmbeddedCommandLine = TEXT("");

	// Start the game thread the way LaunchMac does. RunGameThread registers the
	// calling thread as the main one and puts GuardedMain on a thread of its
	// own, which is what every later assumption about game and main threads
	// depends on.
	static FlutterUnrealLauncher* Launcher = [[FlutterUnrealLauncher alloc] init];
	RunGameThread(Launcher, @selector(runGameThread:));

	UE_LOG(LogTemp, Log, TEXT("[FlutterView_Mac] Engine start requested"));
	return 1;
}

void* UnrealBridge_CreateView(float Width, float Height, float Scale)
{
	if (![NSThread isMainThread])
	{
		UE_LOG(LogTemp, Error,
			TEXT("[FlutterView_Mac] UnrealBridge_CreateView must be called on the main thread"));
		return nullptr;
	}

	if (!GEngineStartRequested.load())
	{
		return nullptr;
	}

	if (GEmbeddedView != nil)
	{
		UnrealBridge_ResizeView(Width, Height, Scale);
		return (void*)GEmbeddedView;
	}

	FCocoaWindow* Window = FindEngineWindow();
	if (Window == nil)
	{
		// Still starting. The host asks again next frame.
		return nullptr;
	}

	NSView* Content = [Window contentView];
	if (Content == nil)
	{
		return nullptr;
	}

	// Borrow the view rather than build one. The engine already made a window
	// with a Metal layer set up the way it wants, and taking that view is far
	// less likely to be wrong than assembling a second one beside it. Reparented
	// into the host's hierarchy, it renders where Flutter puts it.
	GEngineWindow = Window;
	GEmbeddedView = [Content retain];

	// The window it came from would otherwise sit on screen, empty, next to the
	// Flutter one.
	[Window orderOut:nil];

	UnrealBridge_ResizeView(Width, Height, Scale);

	UE_LOG(LogTemp, Log, TEXT("[FlutterView_Mac] Lent the engine's view at %.0fx%.0f"), Width, Height);
	return (void*)GEmbeddedView;
}

void UnrealBridge_ResizeView(float Width, float Height, float Scale)
{
	if (GEmbeddedView == nil || Width <= 0.0f || Height <= 0.0f)
	{
		return;
	}

	// Points here, unlike iOS. AppKit scales for the backing store itself, and
	// multiplying by the scale factor a second time would render at four times
	// the area on any Retina display.
	[GEmbeddedView setFrame:NSMakeRect(0.0, 0.0, Width, Height)];
}

void UnrealBridge_DestroyView(void)
{
	if (GEmbeddedView == nil)
	{
		return;
	}

	// Hand it back to the window that owns it. Releasing it while the engine
	// still holds a viewport pointing at it would leave the renderer drawing
	// into freed memory.
	if (GEngineWindow != nil)
	{
		[GEngineWindow setContentView:GEmbeddedView];
	}

	[GEmbeddedView release];
	GEmbeddedView = nil;
	GEngineWindow = nil;

	UE_LOG(LogTemp, Log, TEXT("[FlutterView_Mac] Returned the engine's view"));
}

int32_t UnrealBridge_IsViewReady(void)
{
	return GEmbeddedView != nil ? 1 : 0;
}

} // extern "C"

#endif // PLATFORM_MAC
