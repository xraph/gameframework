// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterBridge.h"
#include "UnrealEngine.h"
#include "Engine/Engine.h"
#include "Containers/Ticker.h"
#include "Engine/GameViewportClient.h"
#include "Slate/SceneViewport.h"

#include <atomic>

#if PLATFORM_IOS

#include "UnrealBridge.h"

#import <UIKit/UIKit.h>

#include "IOS/IOSAppDelegate.h"
#include "IOS/IOSView.h"

#if BUILD_EMBEDDED_APP

// Defined in Private/FlutterBridge_Apple.cpp.
extern bool FlutterBridge_IsEngineReadyForView();

// ============================================================
// MARK: - Embedded render view
// ============================================================
//
// Unreal's embedded mode does not create its own view. LaunchIOS.cpp says so:
// "For embedded apps, the UEEmbeddedView must have been created and set into
// the AppDelegate as IOSView", and the branch that would have built one is
// compiled out under BUILD_EMBEDDED_APP.
//
// So this does what the non-embedded path in FAppEntry does, minus the part
// that parents the view. The host owns placement, because in a Flutter app the
// view belongs to a platform view inside the widget tree.
//
// This file lives under Private/IOS so UnrealBuildTool leaves it out of every
// other platform's build.

/// The view handed to the host. The app delegate holds the only owning
/// reference, so this is a plain observing pointer.
///
/// Not __weak: Unreal compiles Objective-C++ under manual reference counting,
/// where weak references are a compile error rather than a nicety. It is
/// cleared in UnrealBridge_DestroyView so it cannot outlive the view.
static FIOSView* GEmbeddedView = nil;

/// Whether UnrealBridge_StartEngine has been called.
///
/// FAppEntry blocks the game thread waiting for AppDelegate.IOSView, and it
/// only announces readiness from the main thread once config is loaded. A host
/// that waits for that announcement before building the view is relying on the
/// two crossing in the right order. Creating the view up front is the other
/// way round, so both are allowed: before the engine is started, or after it
/// says it is ready.
static bool GEngineStartRequested = false;

/// Apply the size Unreal should render at.
///
/// The size the host wants, in pixels, and the size the engine was last told
/// about.
static std::atomic<int32> GDesiredPixelWidth{0};
static std::atomic<int32> GDesiredPixelHeight{0};
static int32 GAppliedPixelWidth = 0;
static int32 GAppliedPixelHeight = 0;
static FTSTicker::FDelegateHandle GResolutionTicker;

/// Make the engine's render target match the view it renders into.
///
/// The engine creates its viewport before the host's view exists, at a default
/// 1280x720, and nothing in an embedded build ever corrects it. It then renders
/// that 16:9 frame into a correctly sized portrait surface, which looks like the
/// scene has been cropped into a band rather than like a render target that is
/// the wrong shape.
///
/// Resizing the scene viewport is what actually moves it. Asking for a
/// resolution change instead does not: the console manager refuses the r.SetRes
/// write on priority grounds and says so in the log, and calling it off the game
/// thread aborts the process inside the CVar change.
///
/// Compares against the viewport's real size every tick rather than remembering
/// what it last asked for, so it corrects itself if the engine resizes back, and
/// a rotation puts itself right. In the steady state it is one comparison.
static bool ApplyPendingResolution(float)
{
	const int32 Width = GDesiredPixelWidth.load(std::memory_order_acquire);
	const int32 Height = GDesiredPixelHeight.load(std::memory_order_acquire);
	if (Width <= 0 || Height <= 0)
	{
		return true;
	}

	if (GEngine == nullptr || GEngine->GameViewport == nullptr)
	{
		return true;
	}

	FSceneViewport* Viewport = GEngine->GameViewport->GetGameViewport();
	if (Viewport == nullptr)
	{
		return true;
	}

	const FIntPoint Current = Viewport->GetSizeXY();
	if (Current.X == Width && Current.Y == Height)
	{
		return true;
	}

	Viewport->ResizeFrame((uint32)Width, (uint32)Height, EWindowMode::Fullscreen);

	UE_LOG(LogTemp, Log, TEXT("[FlutterView_IOS] Render target was %dx%d, resized to %dx%d"),
		Current.X, Current.Y, Width, Height);

	return true;
}

/// Record the size the host wants. Applied later, on the game thread.
static void RequestPixelSize(int32 PixelWidth, int32 PixelHeight)
{
	if (PixelWidth <= 0 || PixelHeight <= 0)
	{
		return;
	}

	GDesiredPixelWidth.store(PixelWidth, std::memory_order_release);
	GDesiredPixelHeight.store(PixelHeight, std::memory_order_release);

	if (!GResolutionTicker.IsValid())
	{
		GResolutionTicker = FTSTicker::GetCoreTicker().AddTicker(
			FTickerDelegate::CreateStatic(&ApplyPendingResolution), 0.0f);
	}
}

/// The engine works in pixels while the host talks in points, so the scale
/// The engine works in pixels while the host talks in points, so the scale
/// factor has to be applied here or the engine renders at the wrong resolution
/// on every device with a retina display, which is all of them.
static void ApplyViewSize(FIOSView* View, float Width, float Height, float Scale)
{
	if (View == nil)
	{
		return;
	}

	const CGFloat EffectiveScale = (Scale > 0.0f) ? (CGFloat)Scale : [UIScreen mainScreen].scale;

	View.frame = CGRectMake(0, 0, (CGFloat)Width, (CGFloat)Height);
	View.contentScaleFactor = EffectiveScale;
	View.ViewSize = CGSizeMake((CGFloat)Width * EffectiveScale,
		(CGFloat)Height * EffectiveScale);

	const int32 PixelWidth = (int32)(Width * EffectiveScale);
	const int32 PixelHeight = (int32)(Height * EffectiveScale);

	[View CalculateContentScaleFactor:PixelWidth ScreenHeight:PixelHeight];
	[View UpdateRenderWidth:(unsigned int)PixelWidth andHeight:(unsigned int)PixelHeight];

	// Sizing the view is not enough. The engine keeps its own idea of the
	// resolution, and in an embedded build nothing tells it ours, so it stays
	// on the default 1280x720. That is landscape, and rendering it into a
	// portrait view is what crops the scene into a band across the middle.
	// Recorded, not applied. Changing the resolution has to happen on the game
	// thread, and this runs on the main one.
	RequestPixelSize(PixelWidth, PixelHeight);
}

extern "C" {

int32_t UnrealBridge_StartEngine(void)
{
	if (![NSThread isMainThread])
	{
		UE_LOG(LogTemp, Error,
			TEXT("[FlutterView_IOS] UnrealBridge_StartEngine must be called on the main thread"));
		return 0;
	}

	if (GEngineStartRequested)
	{
		return 1;
	}

	// StartupEmbeddedUnreal is the engine's own "LaunchIOS replacement": it
	// seeds the command line and starts the game thread. Without it nothing
	// boots, the readiness signal never fires, and a host can tick an engine
	// that was never running.
	//
	// It reaches for [IOSAppDelegate GetDelegate], which is Fatal if the app's
	// delegate does not subclass IOSAppDelegate.
	GEngineStartRequested = true;
	[FIOSView StartupEmbeddedUnreal];

	UE_LOG(LogTemp, Log, TEXT("[FlutterView_IOS] Engine start requested"));
	return 1;
}

void* UnrealBridge_CreateView(float Width, float Height, float Scale)
{
	if (![NSThread isMainThread])
	{
		UE_LOG(LogTemp, Error,
			TEXT("[FlutterView_IOS] UnrealBridge_CreateView must be called on the main thread"));
		return nullptr;
	}

	IOSAppDelegate* AppDelegate = [IOSAppDelegate GetDelegate];
	if (AppDelegate == nil)
	{
		UE_LOG(LogTemp, Error, TEXT("[FlutterView_IOS] No IOSAppDelegate yet"));
		return nullptr;
	}

	// Do not wait for the engine to announce readiness. It cannot arrive in
	// time, and relying on it deadlocks.
	//
	// FEngineLoop::PreInit calls FPlatformMisc::PlatformInit (which on iOS is
	// FAppEntry::PlatformInit) at around line 2886. That broadcasts
	// "inisareready" and then blocks, spinning until AppDelegate.IOSView
	// exists. Plugin modules for the PreDefault phase do not load until around
	// line 4675, which execution never reaches. So the broadcast happens before
	// anything in this plugin is alive to hear it, and the engine then waits
	// for a view that a host listening for that broadcast will never create.
	//
	// The engine polls for the view, so the host can simply make one once the
	// engine has been started, and the wait loop picks it up. Before
	// StartEngine is too early: Metal comes up as part of engine startup, and
	// building a view without it crashes.
	if (!GEngineStartRequested)
	{
		UE_LOG(LogTemp, Warning,
			TEXT("[FlutterView_IOS] Call UnrealBridge_StartEngine before creating a view; "
				 "Metal is not up until the engine starts"));
		return nullptr;
	}

	// Already made one. Resize it rather than stranding the engine on a view
	// the host has thrown away.
	if (AppDelegate.IOSView != nil)
	{
		ApplyViewSize(AppDelegate.IOSView, Width, Height, Scale);
		GEmbeddedView = AppDelegate.IOSView;
		return (void*)AppDelegate.IOSView;
	}

	const CGFloat EffectiveScale = (Scale > 0.0f) ? (CGFloat)Scale : [UIScreen mainScreen].scale;
	FIOSView* View = [[FIOSView alloc] initWithFrame:CGRectMake(0, 0, Width, Height)];
	if (View == nil)
	{
		UE_LOG(LogTemp, Error, TEXT("[FlutterView_IOS] Failed to create FIOSView"));
		return nullptr;
	}

	// Mirrors what FAppEntry does for a normal build.
	View.clearsContextBeforeDrawing = NO;
#if !PLATFORM_TVOS
	View.multipleTouchEnabled = YES;
#endif
	View.contentScaleFactor = EffectiveScale;

	// The delegate holds the strong reference, and the engine finds the view
	// through it. Assign before creating the framebuffer, because the RHI
	// reaches back through the delegate while initialising.
	//
	// Under manual reference counting the alloc above is +1 and the retain
	// property adds another, so hand our own reference to the pool. That also
	// keeps View valid through the failure path below, where the property gets
	// cleared.
	AppDelegate.IOSView = View;
	[View autorelease];

	ApplyViewSize(View, Width, Height, Scale);

	if (![View CreateFramebuffer])
	{
		UE_LOG(LogTemp, Error,
			TEXT("[FlutterView_IOS] CreateFramebuffer failed, the engine has nothing to render into"));
		AppDelegate.IOSView = nil;
		return nullptr;
	}

	GEmbeddedView = View;
	UE_LOG(LogTemp, Log,
		TEXT("[FlutterView_IOS] Embedded render view created at %.0fx%.0f @%.1fx"),
		Width, Height, (float)EffectiveScale);

	// Returned unretained. The delegate owns it; the host must not release it.
	return (void*)View;
}

void UnrealBridge_ResizeView(float Width, float Height, float Scale)
{
	if (![NSThread isMainThread])
	{
		UE_LOG(LogTemp, Warning,
			TEXT("[FlutterView_IOS] UnrealBridge_ResizeView called off the main thread, ignoring"));
		return;
	}

	IOSAppDelegate* AppDelegate = [IOSAppDelegate GetDelegate];
	FIOSView* View = (AppDelegate != nil) ? AppDelegate.IOSView : nil;
	if (View == nil)
	{
		return;
	}

	ApplyViewSize(View, Width, Height, Scale);
	[View forceLayoutSubviews];
}

void UnrealBridge_DestroyView(void)
{
	if (![NSThread isMainThread])
	{
		UE_LOG(LogTemp, Warning,
			TEXT("[FlutterView_IOS] UnrealBridge_DestroyView called off the main thread, ignoring"));
		return;
	}

	IOSAppDelegate* AppDelegate = [IOSAppDelegate GetDelegate];
	FIOSView* View = (AppDelegate != nil) ? AppDelegate.IOSView : nil;
	if (View == nil)
	{
		return;
	}

	[View DestroyFramebuffer];
	[View removeFromSuperview];
	AppDelegate.IOSView = nil;
	GEmbeddedView = nil;

	UE_LOG(LogTemp, Log, TEXT("[FlutterView_IOS] Embedded render view destroyed"));
}

int32_t UnrealBridge_IsViewReady(void)
{
	FIOSView* View = GEmbeddedView;
	// bIsInitialized is what FAppEntry itself waits on before letting the RHI
	// start, so it is the honest answer to "can this render yet".
	return (View != nil && View->bIsInitialized) ? 1 : 0;
}

} // extern "C"

#else // !BUILD_EMBEDDED_APP

// Not an embedded build, so the engine makes and owns its own view and the
// embedded entry points it would need are compiled out of IOSView.h. Keep the
// ABI present so a host can call it unconditionally and get an honest answer.

extern "C" {

int32_t UnrealBridge_StartEngine(void) { return 0; }

void* UnrealBridge_CreateView(float, float, float)
{
	UE_LOG(LogTemp, Warning,
		TEXT("[FlutterView_IOS] Not an embedded build. Set bBuildAsFramework=True "
			 "under [/Script/IOSRuntimeSettings.IOSRuntimeSettings] in "
			 "DefaultEngine.ini to build a framework with an embeddable view."));
	return nullptr;
}

void UnrealBridge_ResizeView(float, float, float) {}
void UnrealBridge_DestroyView(void) {}
int32_t UnrealBridge_IsViewReady(void) { return 0; }

} // extern "C"

#endif // BUILD_EMBEDDED_APP

#endif // PLATFORM_IOS
