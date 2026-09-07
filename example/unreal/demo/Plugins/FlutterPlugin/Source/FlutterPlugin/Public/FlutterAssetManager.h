#pragma once

#include "CoreMinimal.h"
#include "Engine/StreamableManager.h"
#include "FlutterAssetManager.generated.h"

/**
 * Asset loading state enumeration
 */
UENUM(BlueprintType)
enum class EFlutterAssetState : uint8
{
    NotLoaded,
    Loading,
    Loaded,
    Failed,
    Unloading
};

/**
 * Information about a loaded asset
 */
USTRUCT(BlueprintType)
struct FFlutterLoadedAsset
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    FString AssetPath;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    EFlutterAssetState State;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    UObject* Asset = nullptr;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int64 LoadTimeMs = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 SizeBytes = 0;
};

/**
 * Asset loading progress information
 */
USTRUCT(BlueprintType)
struct FFlutterAssetProgress
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 TotalAssets = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 LoadedAssets = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 FailedAssets = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    float Progress = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int64 TotalSizeBytes = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int64 LoadedSizeBytes = 0;
};

/**
 * Asset manager statistics
 */
USTRUCT(BlueprintType)
struct FFlutterAssetStatistics
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 TotalAssetsLoaded = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 TotalAssetsUnloaded = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int64 TotalBytesLoaded = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int64 CurrentMemoryUsage = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 CacheHits = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    int32 CacheMisses = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Flutter|Assets")
    float AverageLoadTimeMs = 0.0f;
};

// Delegate declarations
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnFlutterAssetLoaded, const FString&, AssetPath, UObject*, Asset);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnFlutterAssetFailed, const FString&, AssetPath, const FString&, ErrorMessage);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFlutterAssetProgress, const FFlutterAssetProgress&, Progress);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFlutterAssetUnloaded, const FString&, AssetPath);

/**
 * Asset manager for Flutter-Unreal integration.
 * Provides async asset loading with progress tracking and caching.
 */
UCLASS(BlueprintType, Blueprintable)
class FLUTTERPLUGIN_API UFlutterAssetManager : public UObject
{
    GENERATED_BODY()

public:
    UFlutterAssetManager();

    /** Get the singleton instance */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets", meta = (WorldContext = "WorldContextObject"))
    static UFlutterAssetManager* Get(UObject* WorldContextObject);

    // ==================== ASSET LOADING ====================

    /** Load a single asset asynchronously */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void LoadAsset(const FString& AssetPath);

    /** Load a single asset and return it (blocking) */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    UObject* LoadAssetSync(const FString& AssetPath);

    /** Load multiple assets asynchronously */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void LoadAssets(const TArray<FString>& AssetPaths);

    /** Load a level by name */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void LoadLevel(const FString& LevelName, bool bAbsolute = true);

    /** Load a level asynchronously with streaming */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void LoadLevelAsync(const FString& LevelName);

    // ==================== ASSET UNLOADING ====================

    /** Unload a single asset */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void UnloadAsset(const FString& AssetPath);

    /** Unload multiple assets */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void UnloadAssets(const TArray<FString>& AssetPaths);

    /** Unload all loaded assets */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void UnloadAllAssets();

    /** Unload a streaming level */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void UnloadLevel(const FString& LevelName);

    // ==================== ASSET QUERIES ====================

    /** Check if an asset is loaded */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    bool IsAssetLoaded(const FString& AssetPath) const;

    /** Get the state of an asset */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    EFlutterAssetState GetAssetState(const FString& AssetPath) const;

    /** Get a loaded asset */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    UObject* GetLoadedAsset(const FString& AssetPath) const;

    /** Get information about a loaded asset */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    FFlutterLoadedAsset GetAssetInfo(const FString& AssetPath) const;

    /** Get all loaded asset paths */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    TArray<FString> GetLoadedAssetPaths() const;

    // ==================== CACHE MANAGEMENT ====================

    /** Set the maximum cache size in bytes */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void SetCacheMaxSize(int64 MaxSizeBytes);

    /** Get the current cache size */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    int64 GetCacheSize() const;

    /** Clear the asset cache */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void ClearCache();

    /** Trim cache to fit within max size */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void TrimCache();

    // ==================== STATISTICS ====================

    /** Get asset manager statistics */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    FFlutterAssetStatistics GetStatistics() const;

    /** Reset statistics */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void ResetStatistics();

    // ==================== FLUTTER COMMUNICATION ====================

    /** Notify Flutter of asset load progress */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void NotifyFlutterProgress(const FFlutterAssetProgress& Progress);

    /** Notify Flutter of asset loaded */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void NotifyFlutterAssetLoaded(const FString& AssetPath);

    /** Notify Flutter of asset load failure */
    UFUNCTION(BlueprintCallable, Category = "Flutter|Assets")
    void NotifyFlutterAssetFailed(const FString& AssetPath, const FString& ErrorMessage);

    // ==================== EVENTS ====================

    /** Called when an asset is loaded successfully */
    UPROPERTY(BlueprintAssignable, Category = "Flutter|Assets")
    FOnFlutterAssetLoaded OnAssetLoaded;

    /** Called when an asset fails to load */
    UPROPERTY(BlueprintAssignable, Category = "Flutter|Assets")
    FOnFlutterAssetFailed OnAssetFailed;

    /** Called when loading progress updates */
    UPROPERTY(BlueprintAssignable, Category = "Flutter|Assets")
    FOnFlutterAssetProgress OnProgress;

    /** Called when an asset is unloaded */
    UPROPERTY(BlueprintAssignable, Category = "Flutter|Assets")
    FOnFlutterAssetUnloaded OnAssetUnloaded;

protected:
    /** Handle async load completion */
    void HandleAssetLoaded(const FString& AssetPath, UObject* Asset);

    /** Update progress and notify listeners */
    void UpdateProgress();

    /** Calculate asset size estimate */
    int32 EstimateAssetSize(UObject* Asset) const;

private:
    /** Singleton instance */
    static UFlutterAssetManager* Instance;

    /** Streamable manager for async loading */
    FStreamableManager StreamableManager;

    /** Currently loaded assets */
    UPROPERTY()
    TMap<FString, FFlutterLoadedAsset> LoadedAssets;

    /** Assets currently being loaded */
    TMap<FString, TSharedPtr<FStreamableHandle>> PendingLoads;

    /** Cache settings */
    int64 CacheMaxSizeBytes = 256 * 1024 * 1024; // 256 MB default

    /** Statistics */
    FFlutterAssetStatistics Statistics;

    /** Current batch loading progress */
    FFlutterAssetProgress CurrentProgress;

    /** Batch load asset paths */
    TArray<FString> BatchLoadPaths;
};
