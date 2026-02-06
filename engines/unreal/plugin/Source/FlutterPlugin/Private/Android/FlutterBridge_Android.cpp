// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterBridge.h"

#if PLATFORM_ANDROID

#include "Android/AndroidJNI.h"
#include "Android/AndroidApplication.h"
#include "Android/AndroidWindow.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "Slate/SceneViewport.h"
#include "RenderingThread.h"
#include <jni.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>

// Global reference to the Java UnrealEngineController instance
static jobject GUnrealEngineControllerInstance = nullptr;
static jclass GUnrealEngineControllerClass = nullptr;

// Cached method IDs for callbacks
static jmethodID GOnMessageFromUnrealMethodID = nullptr;
static jmethodID GOnLevelLoadedMethodID = nullptr;

// Reference to FlutterBridge instance
static AFlutterBridge* GFlutterBridgeInstance = nullptr;

// Native window for rendering (from Flutter's SurfaceView)
static ANativeWindow* GNativeWindow = nullptr;
static int32 GSurfaceWidth = 0;
static int32 GSurfaceHeight = 0;

// ============================================================
// MARK: - Helper Functions
// ============================================================

/**
 * Convert FString to jstring
 */
jstring FStringToJString(JNIEnv* Env, const FString& String)
{
	if (!Env)
	{
		return nullptr;
	}

	// Use FTCHARToUTF8 converter to avoid dangling pointer from TCHAR_TO_UTF8 macro
	FTCHARToUTF8 Converter(*String);
	return Env->NewStringUTF(Converter.Get());
}

/**
 * Convert jstring to FString
 */
FString JStringToFString(JNIEnv* Env, jstring JavaString)
{
	if (!Env || !JavaString)
	{
		return FString();
	}

	const char* UTFString = Env->GetStringUTFChars(JavaString, nullptr);
	FString Result(UTF8_TO_TCHAR(UTFString));
	Env->ReleaseStringUTFChars(JavaString, UTFString);

	return Result;
}

/**
 * Convert Java Map to TMap<FString, FString>
 */
TMap<FString, FString> JMapToTMap(JNIEnv* Env, jobject JavaMap)
{
	TMap<FString, FString> Result;

	if (!Env || !JavaMap)
	{
		return Result;
	}

	// Get Map class and methods
	jclass MapClass = Env->FindClass("java/util/Map");
	jmethodID EntrySetMethod = Env->GetMethodID(MapClass, "entrySet", "()Ljava/util/Set;");

	// Get Set class and methods
	jclass SetClass = Env->FindClass("java/util/Set");
	jmethodID IteratorMethod = Env->GetMethodID(SetClass, "iterator", "()Ljava/util/Iterator;");

	// Get Iterator class and methods
	jclass IteratorClass = Env->FindClass("java/util/Iterator");
	jmethodID HasNextMethod = Env->GetMethodID(IteratorClass, "hasNext", "()Z");
	jmethodID NextMethod = Env->GetMethodID(IteratorClass, "next", "()Ljava/lang/Object;");

	// Get Map.Entry class and methods
	jclass EntryClass = Env->FindClass("java/util/Map$Entry");
	jmethodID GetKeyMethod = Env->GetMethodID(EntryClass, "getKey", "()Ljava/lang/Object;");
	jmethodID GetValueMethod = Env->GetMethodID(EntryClass, "getValue", "()Ljava/lang/Object;");

	// Iterate through the map
	jobject EntrySet = Env->CallObjectMethod(JavaMap, EntrySetMethod);
	jobject Iterator = Env->CallObjectMethod(EntrySet, IteratorMethod);

	while (Env->CallBooleanMethod(Iterator, HasNextMethod))
	{
		jobject Entry = Env->CallObjectMethod(Iterator, NextMethod);
		jstring Key = (jstring)Env->CallObjectMethod(Entry, GetKeyMethod);
		jobject Value = Env->CallObjectMethod(Entry, GetValueMethod);

		FString KeyString = JStringToFString(Env, Key);
		FString ValueString;

		// Handle different value types
		if (Value)
		{
			jclass ObjectClass = Env->GetObjectClass(Value);
			jmethodID ToStringMethod = Env->GetMethodID(ObjectClass, "toString", "()Ljava/lang/String;");
			jstring ValueStr = (jstring)Env->CallObjectMethod(Value, ToStringMethod);
			ValueString = JStringToFString(Env, ValueStr);
			Env->DeleteLocalRef(ValueStr);
			Env->DeleteLocalRef(ObjectClass);
		}

		Result.Add(KeyString, ValueString);

		Env->DeleteLocalRef(Key);
		Env->DeleteLocalRef(Entry);
	}

	Env->DeleteLocalRef(Iterator);
	Env->DeleteLocalRef(EntrySet);
	Env->DeleteLocalRef(MapClass);
	Env->DeleteLocalRef(SetClass);
	Env->DeleteLocalRef(IteratorClass);
	Env->DeleteLocalRef(EntryClass);

	return Result;
}

/**
 * Convert TMap to Java HashMap
 */
jobject TMapToJMap(JNIEnv* Env, const TMap<FString, int32>& Map)
{
	if (!Env)
	{
		return nullptr;
	}

	// Create HashMap
	jclass HashMapClass = Env->FindClass("java/util/HashMap");
	jmethodID HashMapConstructor = Env->GetMethodID(HashMapClass, "<init>", "()V");
	jmethodID PutMethod = Env->GetMethodID(HashMapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

	jobject HashMap = Env->NewObject(HashMapClass, HashMapConstructor);

	// Get Integer class
	jclass IntegerClass = Env->FindClass("java/lang/Integer");
	jmethodID IntegerConstructor = Env->GetMethodID(IntegerClass, "<init>", "(I)V");

	// Add all entries
	for (const auto& Entry : Map)
	{
		jstring Key = FStringToJString(Env, Entry.Key);
		jobject Value = Env->NewObject(IntegerClass, IntegerConstructor, Entry.Value);
		Env->CallObjectMethod(HashMap, PutMethod, Key, Value);
		Env->DeleteLocalRef(Key);
		Env->DeleteLocalRef(Value);
	}

	Env->DeleteLocalRef(HashMapClass);
	Env->DeleteLocalRef(IntegerClass);

	return HashMap;
}

// ============================================================
// MARK: - JNI Native Method Implementations
// ============================================================

extern "C"
{
	/**
	 * Create Unreal Engine instance
	 */
	JNIEXPORT jboolean JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeCreate(
		JNIEnv* Env, jobject Obj, jobject Config)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeCreate called"));

		// Store controller instance
		if (!GUnrealEngineControllerInstance)
		{
			GUnrealEngineControllerInstance = Env->NewGlobalRef(Obj);
			GUnrealEngineControllerClass = (jclass)Env->NewGlobalRef(Env->GetObjectClass(Obj));

			// Cache method IDs
			GOnMessageFromUnrealMethodID = Env->GetMethodID(
				GUnrealEngineControllerClass,
				"onMessageFromUnreal",
				"(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V"
			);

			GOnLevelLoadedMethodID = Env->GetMethodID(
				GUnrealEngineControllerClass,
				"onLevelLoaded",
				"(Ljava/lang/String;I)V"
			);
		}

		// Parse config (if needed)
		// TMap<FString, FString> ConfigMap = JMapToTMap(Env, Config);

		// Unreal Engine initialization happens automatically
		// This is called after Unreal has already started
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Unreal Engine initialized"));

		return true;
	}

	/**
	 * Get the native Unreal view
	 * 
	 * On Android, Unreal uses a NativeActivity with its own SurfaceView.
	 * We try to get the content view from the current activity's window.
	 */
	JNIEXPORT jobject JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeGetView(
		JNIEnv* Env, jobject Obj)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeGetView called"));

		// Get the main activity from AndroidApplication
		jobject Activity = FAndroidApplication::GetGameActivityThis();
		if (!Activity)
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] No game activity found"));
			return nullptr;
		}

		// Try to get the content view from the activity's window
		// Activity.getWindow().getDecorView()
		jclass ActivityClass = Env->GetObjectClass(Activity);
		if (!ActivityClass)
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] Failed to get activity class"));
			return nullptr;
		}

		jmethodID GetWindowMethod = Env->GetMethodID(ActivityClass, "getWindow", "()Landroid/view/Window;");
		if (!GetWindowMethod)
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] Failed to get getWindow method"));
			Env->DeleteLocalRef(ActivityClass);
			return nullptr;
		}

		jobject Window = Env->CallObjectMethod(Activity, GetWindowMethod);
		if (!Window)
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] Failed to get window"));
			Env->DeleteLocalRef(ActivityClass);
			return nullptr;
		}

		jclass WindowClass = Env->GetObjectClass(Window);
		jmethodID GetDecorViewMethod = Env->GetMethodID(WindowClass, "getDecorView", "()Landroid/view/View;");
		if (!GetDecorViewMethod)
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] Failed to get getDecorView method"));
			Env->DeleteLocalRef(WindowClass);
			Env->DeleteLocalRef(Window);
			Env->DeleteLocalRef(ActivityClass);
			return nullptr;
		}

		jobject DecorView = Env->CallObjectMethod(Window, GetDecorViewMethod);
		
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Got decor view: %p"), DecorView);

		// Clean up local references
		Env->DeleteLocalRef(WindowClass);
		Env->DeleteLocalRef(Window);
		Env->DeleteLocalRef(ActivityClass);

		// Return a global reference to the view
		if (DecorView)
		{
			return Env->NewGlobalRef(DecorView);
		}

		return nullptr;
	}

	/**
	 * Set the rendering surface from Kotlin's SurfaceView
	 * 
	 * This is the key function for Flutter integration - Kotlin creates a SurfaceView
	 * and passes the Surface to native code. We convert it to ANativeWindow which
	 * can be used by Unreal for rendering.
	 * 
	 * @param Surface The Android Surface object, or null to clear
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeSetSurface(
		JNIEnv* Env, jobject Obj, jobject Surface)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeSetSurface called"));

		// Release previous native window if any
		if (GNativeWindow != nullptr)
		{
			UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Releasing previous native window"));
			ANativeWindow_release(GNativeWindow);
			GNativeWindow = nullptr;
		}

		if (Surface != nullptr)
		{
			// Get ANativeWindow from the Surface
			GNativeWindow = ANativeWindow_fromSurface(Env, Surface);
			
			if (GNativeWindow != nullptr)
			{
				// Get surface dimensions
				GSurfaceWidth = ANativeWindow_getWidth(GNativeWindow);
				GSurfaceHeight = ANativeWindow_getHeight(GNativeWindow);
				
				UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Native window created: %dx%d"), 
					GSurfaceWidth, GSurfaceHeight);
				
					// Configure Unreal to render to this window
				// This is the key integration point - tell Unreal's Android window system
				// about our external surface
				
				// Acquire an additional reference since Unreal will manage this
				ANativeWindow_acquire(GNativeWindow);
				
				// Try to set the hardware window for rendering
				UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Setting hardware window..."));
				
				// Check if window is different from current
				void* CurrentWindow = FAndroidWindow::GetHardwareWindow_EventThread();
				if (CurrentWindow != GNativeWindow)
				{
					UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Calling SetHardwareWindow_EventThread"));
					
					// Set the hardware window - this tells Unreal's RHI where to render
					FAndroidWindow::SetHardwareWindow_EventThread(GNativeWindow);
					
					// Set window dimensions to trigger proper initialization
					FAndroidWindow::SetWindowDimensions_EventThread(GNativeWindow);
					
					UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Hardware window set: %dx%d"), 
						GSurfaceWidth, GSurfaceHeight);
				}
				else
				{
					UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Hardware window already set, updating dimensions"));
					FAndroidWindow::SetWindowDimensions_EventThread(GNativeWindow);
				}
				
				// Notify FlutterBridge if available
				if (GFlutterBridgeInstance)
				{
					GFlutterBridgeInstance->OnSurfaceReady(GSurfaceWidth, GSurfaceHeight);
				}
			}
			else
			{
				UE_LOG(LogTemp, Error, TEXT("[FlutterBridge_Android] Failed to get native window from surface"));
			}
		}
		else
		{
			UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Surface cleared"));
			GSurfaceWidth = 0;
			GSurfaceHeight = 0;
			
			// Clear the hardware window
			UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Clearing hardware window"));
			FAndroidWindow::SetHardwareWindow_EventThread(nullptr);
			
			// Notify FlutterBridge if available
			if (GFlutterBridgeInstance)
			{
				GFlutterBridgeInstance->OnSurfaceDestroyed();
			}
		}
	}

	/**
	 * Handle surface dimension changes
	 * 
	 * Called when the SurfaceView dimensions change (e.g., rotation, resize)
	 * 
	 * @param Width New surface width
	 * @param Height New surface height
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeSurfaceChanged(
		JNIEnv* Env, jobject Obj, jint Width, jint Height)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeSurfaceChanged: %dx%d"), Width, Height);

		GSurfaceWidth = Width;
		GSurfaceHeight = Height;

		if (GNativeWindow != nullptr)
		{
			// Update the native window buffer geometry if needed
			// ANativeWindow_setBuffersGeometry(GNativeWindow, Width, Height, WINDOW_FORMAT_RGBA_8888);
			
			UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Surface dimensions updated"));
		}

		// Notify FlutterBridge of size change
		if (GFlutterBridgeInstance)
		{
			GFlutterBridgeInstance->OnSurfaceSizeChanged(Width, Height);
		}
	}

	/**
	 * Get the current native window (for use by other Unreal systems)
	 */
	ANativeWindow* FlutterBridge_GetNativeWindow()
	{
		return GNativeWindow;
	}

	/**
	 * Get the current surface dimensions
	 */
	void FlutterBridge_GetSurfaceSize(int32& OutWidth, int32& OutHeight)
	{
		OutWidth = GSurfaceWidth;
		OutHeight = GSurfaceHeight;
	}

	/**
	 * Pause the engine
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativePause(
		JNIEnv* Env, jobject Obj)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativePause called"));

		if (GFlutterBridgeInstance)
		{
			GFlutterBridgeInstance->OnEnginePause();
		}

		// Pause Unreal Engine rendering
		// This will be handled by Unreal's lifecycle automatically
	}

	/**
	 * Resume the engine
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeResume(
		JNIEnv* Env, jobject Obj)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeResume called"));

		if (GFlutterBridgeInstance)
		{
			GFlutterBridgeInstance->OnEngineResume();
		}

		// Resume Unreal Engine rendering
		// This will be handled by Unreal's lifecycle automatically
	}

	/**
	 * Quit the engine
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeQuit(
		JNIEnv* Env, jobject Obj)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeQuit called"));

		if (GFlutterBridgeInstance)
		{
			GFlutterBridgeInstance->OnEngineQuit();
		}

		// Clean up global references
		if (GUnrealEngineControllerInstance)
		{
			Env->DeleteGlobalRef(GUnrealEngineControllerInstance);
			GUnrealEngineControllerInstance = nullptr;
		}

		if (GUnrealEngineControllerClass)
		{
			Env->DeleteGlobalRef(GUnrealEngineControllerClass);
			GUnrealEngineControllerClass = nullptr;
		}

		GFlutterBridgeInstance = nullptr;
	}

	/**
	 * Send message to Unreal
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeSendMessage(
		JNIEnv* Env, jobject Obj, jstring Target, jstring Method, jstring Data)
	{
		FString TargetString = JStringToFString(Env, Target);
		FString MethodString = JStringToFString(Env, Method);
		FString DataString = JStringToFString(Env, Data);

		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeSendMessage: Target=%s, Method=%s"),
			*TargetString, *MethodString);

		if (GFlutterBridgeInstance)
		{
			GFlutterBridgeInstance->ReceiveFromFlutter(TargetString, MethodString, DataString);
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] FlutterBridge instance not set"));
		}
	}

	/**
	 * Execute console command
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeExecuteConsoleCommand(
		JNIEnv* Env, jobject Obj, jstring Command)
	{
		FString CommandString = JStringToFString(Env, Command);

		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeExecuteConsoleCommand: %s"), *CommandString);

		if (GFlutterBridgeInstance)
		{
			GFlutterBridgeInstance->ExecuteConsoleCommand(CommandString);
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] FlutterBridge instance not set"));
		}
	}

	/**
	 * Load level
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeLoadLevel(
		JNIEnv* Env, jobject Obj, jstring LevelName)
	{
		FString LevelNameString = JStringToFString(Env, LevelName);

		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeLoadLevel: %s"), *LevelNameString);

		if (GFlutterBridgeInstance)
		{
			GFlutterBridgeInstance->LoadLevel(LevelNameString);
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] FlutterBridge instance not set"));
		}
	}

	/**
	 * Apply quality settings
	 */
	JNIEXPORT void JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeApplyQualitySettings(
		JNIEnv* Env, jobject Obj, jobject Settings)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeApplyQualitySettings called"));

		if (!GFlutterBridgeInstance)
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] FlutterBridge instance not set"));
			return;
		}

		// Parse settings map
		TMap<FString, FString> SettingsMap = JMapToTMap(Env, Settings);

		// Extract quality settings
		int32 QualityLevel = SettingsMap.Contains(TEXT("qualityLevel")) ?
			FCString::Atoi(*SettingsMap[TEXT("qualityLevel")]) : -1;
		int32 AntiAliasing = SettingsMap.Contains(TEXT("antiAliasingQuality")) ?
			FCString::Atoi(*SettingsMap[TEXT("antiAliasingQuality")]) : -1;
		int32 Shadow = SettingsMap.Contains(TEXT("shadowQuality")) ?
			FCString::Atoi(*SettingsMap[TEXT("shadowQuality")]) : -1;
		int32 PostProcess = SettingsMap.Contains(TEXT("postProcessQuality")) ?
			FCString::Atoi(*SettingsMap[TEXT("postProcessQuality")]) : -1;
		int32 Texture = SettingsMap.Contains(TEXT("textureQuality")) ?
			FCString::Atoi(*SettingsMap[TEXT("textureQuality")]) : -1;
		int32 Effects = SettingsMap.Contains(TEXT("effectsQuality")) ?
			FCString::Atoi(*SettingsMap[TEXT("effectsQuality")]) : -1;
		int32 Foliage = SettingsMap.Contains(TEXT("foliageQuality")) ?
			FCString::Atoi(*SettingsMap[TEXT("foliageQuality")]) : -1;
		int32 ViewDistance = SettingsMap.Contains(TEXT("viewDistanceQuality")) ?
			FCString::Atoi(*SettingsMap[TEXT("viewDistanceQuality")]) : -1;

		// Apply settings
		GFlutterBridgeInstance->ApplyQualitySettings(
			QualityLevel,
			AntiAliasing,
			Shadow,
			PostProcess,
			Texture,
			Effects,
			Foliage,
			ViewDistance
		);
	}

	/**
	 * Get quality settings
	 */
	JNIEXPORT jobject JNICALL
	Java_com_xraph_gameframework_unreal_UnrealEngineController_nativeGetQualitySettings(
		JNIEnv* Env, jobject Obj)
	{
		UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] nativeGetQualitySettings called"));

		if (!GFlutterBridgeInstance)
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] FlutterBridge instance not set"));
			return nullptr;
		}

		// Get quality settings from Unreal
		TMap<FString, int32> Settings = GFlutterBridgeInstance->GetQualitySettings();

		// Convert to Java HashMap
		return TMapToJMap(Env, Settings);
	}
}

// ============================================================
// MARK: - Callbacks from Unreal to Flutter (via Java)
// ============================================================

/**
 * Send message to Flutter via Java
 * Called from AFlutterBridge::SendToFlutter()
 */
void FlutterBridge_SendToFlutter_Android(const FString& Target, const FString& Method, const FString& Data)
{
	if (!GUnrealEngineControllerInstance || !GOnMessageFromUnrealMethodID)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] Cannot send to Flutter: Java instance not initialized"));
		return;
	}

	JNIEnv* Env = FAndroidApplication::GetJavaEnv();
	if (!Env)
	{
		UE_LOG(LogTemp, Error, TEXT("[FlutterBridge_Android] Failed to get JNI environment"));
		return;
	}

	// Convert strings
	jstring jTarget = FStringToJString(Env, Target);
	jstring jMethod = FStringToJString(Env, Method);
	jstring jData = FStringToJString(Env, Data);

	// Call Java method
	Env->CallVoidMethod(
		GUnrealEngineControllerInstance,
		GOnMessageFromUnrealMethodID,
		jTarget,
		jMethod,
		jData
	);

	// Clean up local references
	Env->DeleteLocalRef(jTarget);
	Env->DeleteLocalRef(jMethod);
	Env->DeleteLocalRef(jData);

	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Message sent to Flutter: Target=%s, Method=%s"),
		*Target, *Method);
}

/**
 * Send binary data to Flutter via Java
 * Called from AFlutterBridge::SendBinaryToFlutter()
 */
void FlutterBridge_SendBinaryToFlutter_Android(const FString& Target, const FString& Method, const TArray<uint8>& Data, int32 Checksum)
{
	if (!GUnrealEngineControllerInstance)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] Cannot send binary to Flutter: Java instance not initialized"));
		return;
	}

	JNIEnv* Env = FAndroidApplication::GetJavaEnv();
	if (!Env)
	{
		UE_LOG(LogTemp, Error, TEXT("[FlutterBridge_Android] Failed to get JNI environment"));
		return;
	}

	// Convert strings
	jstring jTarget = FStringToJString(Env, Target);
	jstring jMethod = FStringToJString(Env, Method);

	// Create byte array
	jbyteArray jData = Env->NewByteArray(Data.Num());
	if (jData && Data.Num() > 0)
	{
		Env->SetByteArrayRegion(jData, 0, Data.Num(), reinterpret_cast<const jbyte*>(Data.GetData()));
	}

	// TODO: Call Java method for binary data once implemented in UnrealEngineController
	// For now, log the binary data info
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Binary data to Flutter: Target=%s, Method=%s, Size=%d, Checksum=%d"),
		*Target, *Method, Data.Num(), Checksum);

	// Clean up local references
	Env->DeleteLocalRef(jTarget);
	Env->DeleteLocalRef(jMethod);
	if (jData)
	{
		Env->DeleteLocalRef(jData);
	}
}

/**
 * Notify Flutter that a level has been loaded
 */
void FlutterBridge_NotifyLevelLoaded_Android(const FString& LevelName, int32 BuildIndex)
{
	if (!GUnrealEngineControllerInstance || !GOnLevelLoadedMethodID)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterBridge_Android] Cannot notify level loaded: Java instance not initialized"));
		return;
	}

	JNIEnv* Env = FAndroidApplication::GetJavaEnv();
	if (!Env)
	{
		UE_LOG(LogTemp, Error, TEXT("[FlutterBridge_Android] Failed to get JNI environment"));
		return;
	}

	// Convert level name
	jstring jLevelName = FStringToJString(Env, LevelName);

	// Call Java method
	Env->CallVoidMethod(
		GUnrealEngineControllerInstance,
		GOnLevelLoadedMethodID,
		jLevelName,
		BuildIndex
	);

	// Clean up local reference
	Env->DeleteLocalRef(jLevelName);

	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] Level loaded notification sent: %s"), *LevelName);
}

/**
 * Set the FlutterBridge instance
 * Called from AFlutterBridge::BeginPlay()
 */
void FlutterBridge_SetInstance_Android(AFlutterBridge* Instance)
{
	GFlutterBridgeInstance = Instance;
	UE_LOG(LogTemp, Log, TEXT("[FlutterBridge_Android] FlutterBridge instance set"));
}

#endif // PLATFORM_ANDROID
