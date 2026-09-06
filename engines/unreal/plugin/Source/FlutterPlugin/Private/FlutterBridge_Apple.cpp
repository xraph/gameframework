// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterBridge.h"

#if PLATFORM_IOS || PLATFORM_MAC

#include "UnrealBridge.h"
#include "Async/Async.h"
#include "Misc/EmbeddedCommunication.h"
#include "Misc/CoreDelegates.h"
#include "Misc/ConfigCacheIni.h"

#include <atomic>

// ============================================================
// MARK: - Bridge State
// ============================================================
//
// Shared by iOS and Mac. The two platforms differ only in the names
// AFlutterBridge dispatches to, so the implementation lives here once and the
// platform entry points at the bottom are shims.
//
// The host app links this framework and registers C callbacks. Nothing here
// touches Objective-C, UIKit or AppKit: the boundary is a flat C ABI so the app
// never needs Unreal headers, include paths or symbols of its own.
//
// Two threads are in play. Unreal calls into SendToFlutter from the game
// thread; the app calls the UnrealBridge_* entry points from its main thread.
// Callback pointers are therefore read and written atomically, and every call
// that touches UObjects is marshalled onto the game thread before it runs.

static std::atomic<AFlutterBridge*> GFlutterBridgeInstance{nullptr};

static std::atomic<UnrealMessageCallback> GMessageCallback{nullptr};
static std::atomic<UnrealBinaryCallback> GBinaryCallback{nullptr};

/// Cached quality settings, refreshed on the game thread.
///
/// UnrealBridge_GetQualitySettings is synchronous and can be called from the
/// app's main thread, where blocking on the game thread risks deadlock against
/// a game thread already waiting on the main thread. So the getter serves this
/// cache and schedules a refresh for next time. The lock is only ever held for
/// a memcpy-sized copy, so neither thread stalls on it.
static FCriticalSection GQualityCacheLock;
static int32 GCachedQuality[UNREALBRIDGE_QUALITY_VALUE_COUNT] = {0};
static bool GQualityCacheValid = false;

/// Order must match the documented layout in UnrealBridge.h.
static const TCHAR* const GQualityKeys[UNREALBRIDGE_QUALITY_VALUE_COUNT] = {
	TEXT("antiAliasing"),
	TEXT("shadow"),
	TEXT("postProcess"),
	TEXT("texture"),
	TEXT("effects"),
	TEXT("foliage"),
	TEXT("viewDistance")
};

// ============================================================
// MARK: - Waiting for the engine to be ready for a view
// ============================================================
//
// FAppEntry broadcasts "inisareready" on the embedded-to-native channel once
// the config is loaded, with a comment stating that this is when the view can
// be made. Building the view earlier is a race, so the host is told when
// instead of guessing.
//
// The signal and the host's registration can arrive in either order, so both
// are recorded and whichever comes second does the work.

static std::atomic<bool> GEngineReadyForView{false};
static std::atomic<UnrealEngineReadyCallback> GEngineReadyCallback{nullptr};

static void HandleEmbeddedToNative(const FEmbeddedCallParamsHelper& Params)
{
	if (Params.Command != TEXT("inisareready"))
	{
		return;
	}

	GEngineReadyForView.store(true, std::memory_order_release);
	UE_LOG(LogTemp, Log,
		TEXT("[FlutterBridge_Apple] Engine reports config is ready; a render view can be made"));

	if (UnrealEngineReadyCallback Callback =
			GEngineReadyCallback.load(std::memory_order_acquire))
	{
		Callback();
	}
}

/// Subscribe once, as early as the module loads.
///
/// The plugin is a PreDefault-phase module, so this runs before FAppEntry gets
/// far enough to broadcast. Registering late would mean missing it entirely,
/// which is why this does not wait for the host to call in.
void FlutterBridge_ListenForEngineReady()
{
	static bool bSubscribed = false;
	if (bSubscribed)
	{
		return;
	}
	bSubscribed = true;

	FEmbeddedDelegates::GetEmbeddedToNativeParamsDelegateForSubsystem(TEXT("native"))
		.AddStatic(&HandleEmbeddedToNative);

	UE_LOG(LogTemp, Log,
		TEXT("[FlutterBridge_Apple] Listening for the engine's readiness signal"));
}

/// Whether a render view can be built yet. Used by the iOS view code.
bool FlutterBridge_IsEngineReadyForView()
{
	return GEngineReadyForView.load(std::memory_order_acquire);
}

// ============================================================
// MARK: - Helpers
// ============================================================

/// Convert an incoming C string to FString, tolerating null.
static FString CStringToFString(const char* String)
{
	return String ? FString(UTF8_TO_TCHAR(String)) : FString();
}

/// Run work on the game thread, immediately if already there.
///
/// Everything below reaches into UObjects, which is only legal on the game
/// thread. Calls arriving from the app's main thread get queued.
/// Priority for work queued through FEmbeddedCommunication. Zero is the normal
/// band; higher numbers run first.
static constexpr int GBridgeWorkPriority = 0;

static void RunOnGameThread(TFunction<void()> Work)
{
	if (IsInGameThread())
	{
		Work();
		return;
	}

	// FEmbeddedCommunication::RunOnGameThread is explicitly safe before Init,
	// so a host that calls in during startup gets its work queued rather than
	// dropped. That matters here: the task graph is not safe that early, and an
	// earlier version of this reached straight for AsyncTask and crashed when
	// the engine had not been initialised.
	FEmbeddedCommunication::RunOnGameThread(GBridgeWorkPriority, MoveTemp(Work));
	FEmbeddedCommunication::WakeGameThread();
}

/// Refresh the quality cache. Game thread only.
static void RefreshQualityCache()
{
	check(IsInGameThread());

	AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire);
	if (!Bridge)
	{
		return;
	}

	const TMap<FString, int32> Settings = Bridge->GetQualitySettings();

	FScopeLock Lock(&GQualityCacheLock);
	for (int32 Index = 0; Index < UNREALBRIDGE_QUALITY_VALUE_COUNT; ++Index)
	{
		const int32* Value = Settings.Find(GQualityKeys[Index]);
		GCachedQuality[Index] = Value ? *Value : -1;
	}

	GQualityCacheValid = true;
}

// ============================================================
// MARK: - Unreal to Flutter
// ============================================================

/**
 * Send a message to Flutter.
 * Called from AFlutterBridge::SendToFlutter() on the game thread.
 *
 * The callback receives pointers into a temporary UTF-8 conversion, so the
 * host must copy anything it intends to keep. This is documented on the
 * typedef in UnrealBridge.h.
 */
static void SendToFlutter_Apple(const FString& Target, const FString& Method, const FString& Data)
{
	const UnrealMessageCallback Callback = GMessageCallback.load(std::memory_order_acquire);
	if (!Callback)
	{
		UE_LOG(LogTemp, Verbose,
			TEXT("[FlutterBridge_Apple] Dropping message, no callback registered: Target=%s, Method=%s"),
			*Target, *Method);
		return;
	}

	const FTCHARToUTF8 TargetUtf8(*Target);
	const FTCHARToUTF8 MethodUtf8(*Method);
	const FTCHARToUTF8 DataUtf8(*Data);

	Callback(TargetUtf8.Get(), MethodUtf8.Get(), DataUtf8.Get());
}

/**
 * Send binary data to Flutter.
 * Called from AFlutterBridge::SendBinaryToFlutter() on the game thread.
 */
static void SendBinaryToFlutter_Apple(const FString& Target, const FString& Method, const TArray<uint8>& Data, int32 Checksum)
{
	const UnrealBinaryCallback Callback = GBinaryCallback.load(std::memory_order_acquire);
	if (!Callback)
	{
		UE_LOG(LogTemp, Verbose,
			TEXT("[FlutterBridge_Apple] Dropping binary payload, no callback registered: Target=%s, Method=%s, Size=%d"),
			*Target, *Method, Data.Num());
		return;
	}

	const FTCHARToUTF8 TargetUtf8(*Target);
	const FTCHARToUTF8 MethodUtf8(*Method);

	Callback(TargetUtf8.Get(), MethodUtf8.Get(), Data.GetData(), Data.Num(), Checksum);
}

// ============================================================
// MARK: - Instance Registration
// ============================================================

/**
 * Set the FlutterBridge instance.
 * Called from AFlutterBridge::BeginPlay() on the game thread.
 */
static void SetInstance_Apple(AFlutterBridge* Instance)
{
	GFlutterBridgeInstance.store(Instance, std::memory_order_release);

	if (Instance)
	{
		RefreshQualityCache();
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Apple] FlutterBridge instance set"));
	}
	else
	{
		FScopeLock Lock(&GQualityCacheLock);
		GQualityCacheValid = false;
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Apple] FlutterBridge instance cleared"));
	}
}

// ============================================================
// MARK: - Platform Entry Points
// ============================================================
//
// AFlutterBridge dispatches to a differently named function per platform. iOS
// and Mac share everything above, so these are shims. UnrealBuildTool compiles
// exactly one branch.

#if PLATFORM_IOS

void FlutterBridge_SendToFlutter_iOS(const FString& Target, const FString& Method, const FString& Data)
{
	SendToFlutter_Apple(Target, Method, Data);
}

void FlutterBridge_SendBinaryToFlutter_iOS(const FString& Target, const FString& Method, const TArray<uint8>& Data, int32 Checksum)
{
	SendBinaryToFlutter_Apple(Target, Method, Data, Checksum);
}

void FlutterBridge_SetInstance_iOS(AFlutterBridge* Instance)
{
	SetInstance_Apple(Instance);
}

AFlutterBridge* FlutterBridge_GetInstance_iOS()
{
	return GFlutterBridgeInstance.load(std::memory_order_acquire);
}

#elif PLATFORM_MAC

void FlutterBridge_SendToFlutter_Mac(const FString& Target, const FString& Method, const FString& Data)
{
	SendToFlutter_Apple(Target, Method, Data);
}

void FlutterBridge_SendBinaryToFlutter_Mac(const FString& Target, const FString& Method, const TArray<uint8>& Data, int32 Checksum)
{
	SendBinaryToFlutter_Apple(Target, Method, Data, Checksum);
}

void FlutterBridge_SetInstance_Mac(AFlutterBridge* Instance)
{
	SetInstance_Apple(Instance);
}

AFlutterBridge* FlutterBridge_GetInstance_Mac()
{
	return GFlutterBridgeInstance.load(std::memory_order_acquire);
}

#endif

// ============================================================
// MARK: - C ABI (called by the host app)
// ============================================================

extern "C" {

void UnrealBridge_SetMessageCallback(UnrealMessageCallback Callback)
{
	GMessageCallback.store(Callback, std::memory_order_release);
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Apple] Message callback %s"),
		Callback ? TEXT("registered") : TEXT("cleared"));
}

void UnrealBridge_SetBinaryCallback(UnrealBinaryCallback Callback)
{
	GBinaryCallback.store(Callback, std::memory_order_release);
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Apple] Binary callback %s"),
		Callback ? TEXT("registered") : TEXT("cleared"));
}

void UnrealBridge_SendToUnreal(const char* Target, const char* Method, const char* Data)
{
	const FString TargetString = CStringToFString(Target);
	const FString MethodString = CStringToFString(Method);
	const FString DataString = CStringToFString(Data);

	// Traced back to Flutter rather than logged. The engine's log file is
	// buffered and mostly shows startup, so a message that vanishes between
	// here and the actor leaves nothing to read. These go through the message
	// callback directly, which needs no bridge actor, so they still arrive when
	// the thing being diagnosed is the bridge actor itself.
	SendToFlutter_Apple(TEXT("Trace"), TEXT("queued"),
		FString::Printf(TEXT("%s.%s"), *TargetString, *MethodString));

	RunOnGameThread([TargetString, MethodString, DataString]()
	{
		AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire);

		SendToFlutter_Apple(TEXT("Trace"), TEXT("drained"),
			FString::Printf(TEXT("%s.%s bridge=%s"), *TargetString, *MethodString,
				Bridge != nullptr ? TEXT("yes") : TEXT("null")));

		if (Bridge != nullptr)
		{
			Bridge->ReceiveFromFlutter(TargetString, MethodString, DataString);
		}
		else
		{
			UE_LOG(LogTemp, Warning,
				TEXT("[FlutterBridge_Apple] Dropping message from Flutter, no bridge actor: Target=%s, Method=%s"),
				*TargetString, *MethodString);
		}
	});
}

void UnrealBridge_SendBinaryToUnreal(const char* Target, const char* Method, const void* Data, int32_t Length, int32_t Checksum)
{
	const FString TargetString = CStringToFString(Target);
	const FString MethodString = CStringToFString(Method);

	// Copy now. The caller owns its buffer and is free to release it as soon as
	// this returns, but the work below runs later on the game thread.
	TArray<uint8> Payload;
	if (Data && Length > 0)
	{
		Payload.Append(static_cast<const uint8*>(Data), Length);
	}

	RunOnGameThread([TargetString, MethodString, Payload = MoveTemp(Payload), Checksum]()
	{
		if (AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire))
		{
			Bridge->ReceiveBinaryFromFlutter(TargetString, MethodString, Payload, Checksum);
		}
		else
		{
			UE_LOG(LogTemp, Warning,
				TEXT("[FlutterBridge_Apple] Dropping binary from Flutter, no bridge actor: Target=%s, Method=%s, Size=%d"),
				*TargetString, *MethodString, Payload.Num());
		}
	});
}

void UnrealBridge_ExecuteConsoleCommand(const char* Command)
{
	const FString CommandString = CStringToFString(Command);

	RunOnGameThread([CommandString]()
	{
		if (AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire))
		{
			Bridge->ExecuteConsoleCommand(CommandString);
		}
	});
}

void UnrealBridge_LoadLevel(const char* LevelName)
{
	const FString LevelString = CStringToFString(LevelName);

	RunOnGameThread([LevelString]()
	{
		if (AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire))
		{
			Bridge->LoadLevel(LevelString);
		}
	});
}

void UnrealBridge_ApplyQualitySettings(
	int32_t QualityLevel,
	int32_t AntiAliasing,
	int32_t Shadow,
	int32_t PostProcess,
	int32_t Texture,
	int32_t Effects,
	int32_t Foliage,
	int32_t ViewDistance)
{
	RunOnGameThread([=]()
	{
		AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire);
		if (!Bridge)
		{
			return;
		}

		Bridge->ApplyQualitySettings(
			QualityLevel, AntiAliasing, Shadow, PostProcess,
			Texture, Effects, Foliage, ViewDistance);

		RefreshQualityCache();
	});
}

int32_t UnrealBridge_GetQualitySettings(int32_t* OutValues, int32_t Capacity)
{
	// Schedule a refresh regardless, so a later call sees current values.
	RunOnGameThread([]()
	{
		RefreshQualityCache();
	});

	if (!OutValues || Capacity < UNREALBRIDGE_QUALITY_VALUE_COUNT)
	{
		return 0;
	}

	FScopeLock Lock(&GQualityCacheLock);
	if (!GQualityCacheValid)
	{
		return 0;
	}

	for (int32 Index = 0; Index < UNREALBRIDGE_QUALITY_VALUE_COUNT; ++Index)
	{
		OutValues[Index] = GCachedQuality[Index];
	}

	return UNREALBRIDGE_QUALITY_VALUE_COUNT;
}

#if PLATFORM_MAC

// macOS has no embedded render path. bShouldCompileAsDLL does not define
// BUILD_EMBEDDED_APP there and no Mac runtime code honours it, so there is no
// engine-owned view to hand over. These exist so the ABI is the same shape on
// both platforms and a host can call them unconditionally.

void* UnrealBridge_CreateView(float, float, float)
{
	UE_LOG(LogTemp, Warning,
		TEXT("[FlutterBridge_Apple] Unreal has no embedded render view on macOS"));
	return nullptr;
}

int32_t UnrealBridge_StartEngine(void)
{
	UE_LOG(LogTemp, Warning,
		TEXT("[FlutterBridge_Apple] Unreal has no embedded start path on macOS"));
	return 0;
}

void UnrealBridge_ResizeView(float, float, float) {}
void UnrealBridge_DestroyView(void) {}
int32_t UnrealBridge_IsViewReady(void) { return 0; }

#endif // PLATFORM_MAC

void UnrealBridge_SetEngineReadyCallback(UnrealEngineReadyCallback Callback)
{
	GEngineReadyCallback.store(Callback, std::memory_order_release);

	// Already announced, so tell the host now rather than leaving it waiting on
	// a broadcast that has been and gone.
	if (Callback != nullptr &&
		GEngineReadyForView.load(std::memory_order_acquire))
	{
		Callback();
	}
}

int32_t UnrealBridge_IsReadyForView(void)
{
	return GEngineReadyForView.load(std::memory_order_acquire) ? 1 : 0;
}

void UnrealBridge_Init(void)
{
	static std::atomic<bool> bInitialised{false};
	bool bExpected = false;
	if (!bInitialised.compare_exchange_strong(bExpected, true))
	{
		return;
	}

	FEmbeddedCommunication::Init();
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Apple] Embedded communication initialised"));
}

int32_t UnrealBridge_Tick(float DeltaSeconds)
{
	// GConfig is null until the engine has loaded its inis, and
	// FEmbeddedCommunication::TickGameThread reads a setting through it without
	// checking. A host that starts ticking as soon as the engine is asked to
	// start gets there first and dereferences null, which it must, because the
	// engine blocks during startup waiting to be handed a view and the tick is
	// what offers one.
	if (GConfig == nullptr)
	{
		return 0;
	}


	// TickGameThread must run on the thread that owns the engine. In an
	// embedded build that is whichever thread the host drives it from, so this
	// deliberately does not marshal: doing so would tick from somewhere the
	// engine does not expect.
	return FEmbeddedCommunication::TickGameThread(DeltaSeconds) ? 1 : 0;
}

void UnrealBridge_WakeGameThread(void)
{
	FEmbeddedCommunication::WakeGameThread();
}

void UnrealBridge_KeepAwake(const char* Requester, int32_t bNeedsRendering)
{
	FEmbeddedCommunication::KeepAwake(FName(CStringToFString(Requester)),
		bNeedsRendering != 0);
}

void UnrealBridge_AllowSleep(const char* Requester)
{
	FEmbeddedCommunication::AllowSleep(FName(CStringToFString(Requester)));
}

int32_t UnrealBridge_IsAwakeForTicking(void)
{
	return FEmbeddedCommunication::IsAwakeForTicking() ? 1 : 0;
}

int32_t UnrealBridge_IsAwakeForRendering(void)
{
	return FEmbeddedCommunication::IsAwakeForRendering() ? 1 : 0;
}

void UnrealBridge_Pause(int32_t Paused)
{
	const bool bPaused = Paused != 0;

	RunOnGameThread([bPaused]()
	{
		AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire);
		if (!Bridge)
		{
			return;
		}

		if (bPaused)
		{
			Bridge->OnEnginePause();
		}
		else
		{
			Bridge->OnEngineResume();
		}
	});
}

void UnrealBridge_Stop(void)
{
	// Clear callbacks first. The host is going away, and the quit path below
	// can still produce messages we would otherwise hand to a dead callback.
	GMessageCallback.store(nullptr, std::memory_order_release);
	GBinaryCallback.store(nullptr, std::memory_order_release);

	RunOnGameThread([]()
	{
		if (AFlutterBridge* Bridge = GFlutterBridgeInstance.load(std::memory_order_acquire))
		{
			Bridge->OnEngineQuit();
		}
	});

	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Apple] Bridge stopped"));
}

int32_t UnrealBridge_IsReady(void)
{
	return GFlutterBridgeInstance.load(std::memory_order_acquire) != nullptr ? 1 : 0;
}

} // extern "C"

#endif // PLATFORM_IOS || PLATFORM_MAC
