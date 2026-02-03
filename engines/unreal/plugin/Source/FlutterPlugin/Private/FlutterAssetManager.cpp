#include "FlutterAssetManager.h"
#include "FlutterBridge.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/LevelStreaming.h"
#include "Misc/Paths.h"

UFlutterAssetManager* UFlutterAssetManager::Instance = nullptr;

UFlutterAssetManager::UFlutterAssetManager()
{
    Statistics = FFlutterAssetStatistics();
    CurrentProgress = FFlutterAssetProgress();
}

UFlutterAssetManager* UFlutterAssetManager::Get(UObject* WorldContextObject)
{
    if (!Instance)
    {
        Instance = NewObject<UFlutterAssetManager>(GetTransientPackage(), NAME_None, RF_MarkAsRootSet);
    }
    return Instance;
}

// ==================== ASSET LOADING ====================

void UFlutterAssetManager::LoadAsset(const FString& AssetPath)
{
    if (AssetPath.IsEmpty())
    {
        UE_LOG(LogTemp, Warning, TEXT("[FlutterAssetManager] Empty asset path provided"));
        return;
    }

    // Check if already loaded
    if (FFlutterLoadedAsset* ExistingAsset = LoadedAssets.Find(AssetPath))
    {
        if (ExistingAsset->State == EFlutterAssetState::Loaded)
        {
            Statistics.CacheHits++;
            OnAssetLoaded.Broadcast(AssetPath, ExistingAsset->Asset);
            NotifyFlutterAssetLoaded(AssetPath);
            return;
        }
    }

    Statistics.CacheMisses++;

    // Check if already loading
    if (PendingLoads.Contains(AssetPath))
    {
        UE_LOG(LogTemp, Log, TEXT("[FlutterAssetManager] Asset already loading: %s"), *AssetPath);
        return;
    }

    // Create loading entry
    FFlutterLoadedAsset LoadingAsset;
    LoadingAsset.AssetPath = AssetPath;
    LoadingAsset.State = EFlutterAssetState::Loading;
    LoadedAssets.Add(AssetPath, LoadingAsset);

    // Record start time for statistics
    double StartTime = FPlatformTime::Seconds();

    // Start async load
    FSoftObjectPath SoftPath(AssetPath);
    TSharedPtr<FStreamableHandle> Handle = StreamableManager.RequestAsyncLoad(
        SoftPath,
        FStreamableDelegate::CreateLambda([this, AssetPath, StartTime]()
        {
            // Calculate load time
            int64 LoadTimeMs = (int64)((FPlatformTime::Seconds() - StartTime) * 1000.0);

            // Get the loaded asset
            FSoftObjectPath SoftPath(AssetPath);
            UObject* LoadedObject = SoftPath.ResolveObject();

            if (LoadedObject)
            {
                // Update loaded asset entry
                if (FFlutterLoadedAsset* Entry = LoadedAssets.Find(AssetPath))
                {
                    Entry->Asset = LoadedObject;
                    Entry->State = EFlutterAssetState::Loaded;
                    Entry->LoadTimeMs = LoadTimeMs;
                    Entry->SizeBytes = EstimateAssetSize(LoadedObject);

                    // Update statistics
                    Statistics.TotalAssetsLoaded++;
                    Statistics.TotalBytesLoaded += Entry->SizeBytes;
                    Statistics.CurrentMemoryUsage += Entry->SizeBytes;
                    
                    // Update average load time
                    float TotalTime = Statistics.AverageLoadTimeMs * (Statistics.TotalAssetsLoaded - 1) + LoadTimeMs;
                    Statistics.AverageLoadTimeMs = TotalTime / Statistics.TotalAssetsLoaded;
                }

                HandleAssetLoaded(AssetPath, LoadedObject);
            }
            else
            {
                // Handle failure
                if (FFlutterLoadedAsset* Entry = LoadedAssets.Find(AssetPath))
                {
                    Entry->State = EFlutterAssetState::Failed;
                }

                FString ErrorMessage = FString::Printf(TEXT("Failed to resolve asset: %s"), *AssetPath);
                OnAssetFailed.Broadcast(AssetPath, ErrorMessage);
                NotifyFlutterAssetFailed(AssetPath, ErrorMessage);
            }

            // Remove from pending
            PendingLoads.Remove(AssetPath);
            UpdateProgress();
        })
    );

    PendingLoads.Add(AssetPath, Handle);
}

UObject* UFlutterAssetManager::LoadAssetSync(const FString& AssetPath)
{
    if (AssetPath.IsEmpty())
    {
        return nullptr;
    }

    // Check cache first
    if (FFlutterLoadedAsset* ExistingAsset = LoadedAssets.Find(AssetPath))
    {
        if (ExistingAsset->State == EFlutterAssetState::Loaded && ExistingAsset->Asset)
        {
            Statistics.CacheHits++;
            return ExistingAsset->Asset;
        }
    }

    Statistics.CacheMisses++;

    // Synchronous load
    FSoftObjectPath SoftPath(AssetPath);
    UObject* LoadedObject = StreamableManager.LoadSynchronous(SoftPath);

    if (LoadedObject)
    {
        FFlutterLoadedAsset LoadedEntry;
        LoadedEntry.AssetPath = AssetPath;
        LoadedEntry.Asset = LoadedObject;
        LoadedEntry.State = EFlutterAssetState::Loaded;
        LoadedEntry.SizeBytes = EstimateAssetSize(LoadedObject);
        
        LoadedAssets.Add(AssetPath, LoadedEntry);
        
        Statistics.TotalAssetsLoaded++;
        Statistics.TotalBytesLoaded += LoadedEntry.SizeBytes;
        Statistics.CurrentMemoryUsage += LoadedEntry.SizeBytes;
    }

    return LoadedObject;
}

void UFlutterAssetManager::LoadAssets(const TArray<FString>& AssetPaths)
{
    if (AssetPaths.Num() == 0)
    {
        return;
    }

    // Initialize batch progress
    BatchLoadPaths = AssetPaths;
    CurrentProgress.TotalAssets = AssetPaths.Num();
    CurrentProgress.LoadedAssets = 0;
    CurrentProgress.FailedAssets = 0;
    CurrentProgress.Progress = 0.0f;

    // Start loading all assets
    for (const FString& Path : AssetPaths)
    {
        LoadAsset(Path);
    }
}

void UFlutterAssetManager::LoadLevel(const FString& LevelName, bool bAbsolute)
{
    UE_LOG(LogTemp, Log, TEXT("[FlutterAssetManager] Loading level: %s"), *LevelName);

    UWorld* World = GEngine ? GEngine->GetWorldContexts()[0].World() : nullptr;
    if (World)
    {
        UGameplayStatics::OpenLevel(World, *LevelName, bAbsolute);
        
        // Notify Flutter
        if (AFlutterBridge* Bridge = AFlutterBridge::GetInstance())
        {
            Bridge->SendToFlutter(TEXT("AssetManager"), TEXT("onLevelLoaded"), LevelName);
        }
    }
}

void UFlutterAssetManager::LoadLevelAsync(const FString& LevelName)
{
    UE_LOG(LogTemp, Log, TEXT("[FlutterAssetManager] Loading level async: %s"), *LevelName);

    UWorld* World = GEngine ? GEngine->GetWorldContexts()[0].World() : nullptr;
    if (World)
    {
        FLatentActionInfo LatentInfo;
        LatentInfo.CallbackTarget = this;
        LatentInfo.UUID = GetUniqueID();
        LatentInfo.Linkage = 0;

        UGameplayStatics::LoadStreamLevel(World, LevelName, true, false, LatentInfo);
    }
}

// ==================== ASSET UNLOADING ====================

void UFlutterAssetManager::UnloadAsset(const FString& AssetPath)
{
    if (FFlutterLoadedAsset* Entry = LoadedAssets.Find(AssetPath))
    {
        // Update statistics
        Statistics.TotalAssetsUnloaded++;
        Statistics.CurrentMemoryUsage -= Entry->SizeBytes;

        // Remove from loaded assets
        LoadedAssets.Remove(AssetPath);

        // Broadcast event
        OnAssetUnloaded.Broadcast(AssetPath);

        UE_LOG(LogTemp, Log, TEXT("[FlutterAssetManager] Unloaded asset: %s"), *AssetPath);
    }
}

void UFlutterAssetManager::UnloadAssets(const TArray<FString>& AssetPaths)
{
    for (const FString& Path : AssetPaths)
    {
        UnloadAsset(Path);
    }
}

void UFlutterAssetManager::UnloadAllAssets()
{
    TArray<FString> AllPaths;
    LoadedAssets.GetKeys(AllPaths);
    UnloadAssets(AllPaths);
}

void UFlutterAssetManager::UnloadLevel(const FString& LevelName)
{
    UWorld* World = GEngine ? GEngine->GetWorldContexts()[0].World() : nullptr;
    if (World)
    {
        FLatentActionInfo LatentInfo;
        LatentInfo.CallbackTarget = this;
        LatentInfo.UUID = GetUniqueID();
        LatentInfo.Linkage = 1;

        UGameplayStatics::UnloadStreamLevel(World, LevelName, LatentInfo, false);
    }
}

// ==================== ASSET QUERIES ====================

bool UFlutterAssetManager::IsAssetLoaded(const FString& AssetPath) const
{
    const FFlutterLoadedAsset* Entry = LoadedAssets.Find(AssetPath);
    return Entry && Entry->State == EFlutterAssetState::Loaded;
}

EFlutterAssetState UFlutterAssetManager::GetAssetState(const FString& AssetPath) const
{
    const FFlutterLoadedAsset* Entry = LoadedAssets.Find(AssetPath);
    return Entry ? Entry->State : EFlutterAssetState::NotLoaded;
}

UObject* UFlutterAssetManager::GetLoadedAsset(const FString& AssetPath) const
{
    const FFlutterLoadedAsset* Entry = LoadedAssets.Find(AssetPath);
    return (Entry && Entry->State == EFlutterAssetState::Loaded) ? Entry->Asset : nullptr;
}

FFlutterLoadedAsset UFlutterAssetManager::GetAssetInfo(const FString& AssetPath) const
{
    const FFlutterLoadedAsset* Entry = LoadedAssets.Find(AssetPath);
    return Entry ? *Entry : FFlutterLoadedAsset();
}

TArray<FString> UFlutterAssetManager::GetLoadedAssetPaths() const
{
    TArray<FString> Paths;
    for (const auto& Pair : LoadedAssets)
    {
        if (Pair.Value.State == EFlutterAssetState::Loaded)
        {
            Paths.Add(Pair.Key);
        }
    }
    return Paths;
}

// ==================== CACHE MANAGEMENT ====================

void UFlutterAssetManager::SetCacheMaxSize(int64 MaxSizeBytes)
{
    CacheMaxSizeBytes = MaxSizeBytes;
    TrimCache();
}

int64 UFlutterAssetManager::GetCacheSize() const
{
    return Statistics.CurrentMemoryUsage;
}

void UFlutterAssetManager::ClearCache()
{
    UnloadAllAssets();
    Statistics.CurrentMemoryUsage = 0;
}

void UFlutterAssetManager::TrimCache()
{
    // If we're over the limit, unload oldest assets
    while (Statistics.CurrentMemoryUsage > CacheMaxSizeBytes && LoadedAssets.Num() > 0)
    {
        // Find the oldest loaded asset (simple LRU - could be improved)
        FString OldestPath;
        int64 OldestTime = INT64_MAX;

        for (const auto& Pair : LoadedAssets)
        {
            if (Pair.Value.State == EFlutterAssetState::Loaded && Pair.Value.LoadTimeMs < OldestTime)
            {
                OldestTime = Pair.Value.LoadTimeMs;
                OldestPath = Pair.Key;
            }
        }

        if (!OldestPath.IsEmpty())
        {
            UnloadAsset(OldestPath);
        }
        else
        {
            break;
        }
    }
}

// ==================== STATISTICS ====================

FFlutterAssetStatistics UFlutterAssetManager::GetStatistics() const
{
    return Statistics;
}

void UFlutterAssetManager::ResetStatistics()
{
    // Keep current memory usage, reset everything else
    int64 CurrentMemory = Statistics.CurrentMemoryUsage;
    Statistics = FFlutterAssetStatistics();
    Statistics.CurrentMemoryUsage = CurrentMemory;
}

// ==================== FLUTTER COMMUNICATION ====================

void UFlutterAssetManager::NotifyFlutterProgress(const FFlutterAssetProgress& Progress)
{
    if (AFlutterBridge* Bridge = AFlutterBridge::GetInstance())
    {
        FString ProgressJson = FString::Printf(
            TEXT("{\"total\":%d,\"loaded\":%d,\"failed\":%d,\"progress\":%.2f}"),
            Progress.TotalAssets,
            Progress.LoadedAssets,
            Progress.FailedAssets,
            Progress.Progress
        );
        Bridge->SendToFlutter(TEXT("AssetManager"), TEXT("onProgress"), ProgressJson);
    }
}

void UFlutterAssetManager::NotifyFlutterAssetLoaded(const FString& AssetPath)
{
    if (AFlutterBridge* Bridge = AFlutterBridge::GetInstance())
    {
        Bridge->SendToFlutter(TEXT("AssetManager"), TEXT("onAssetLoaded"), AssetPath);
    }
}

void UFlutterAssetManager::NotifyFlutterAssetFailed(const FString& AssetPath, const FString& ErrorMessage)
{
    if (AFlutterBridge* Bridge = AFlutterBridge::GetInstance())
    {
        FString ErrorJson = FString::Printf(TEXT("{\"path\":\"%s\",\"error\":\"%s\"}"), *AssetPath, *ErrorMessage);
        Bridge->SendToFlutter(TEXT("AssetManager"), TEXT("onAssetFailed"), ErrorJson);
    }
}

// ==================== INTERNAL METHODS ====================

void UFlutterAssetManager::HandleAssetLoaded(const FString& AssetPath, UObject* Asset)
{
    OnAssetLoaded.Broadcast(AssetPath, Asset);
    NotifyFlutterAssetLoaded(AssetPath);
    UpdateProgress();

    // Check if we need to trim cache
    if (Statistics.CurrentMemoryUsage > CacheMaxSizeBytes)
    {
        TrimCache();
    }
}

void UFlutterAssetManager::UpdateProgress()
{
    if (BatchLoadPaths.Num() == 0)
    {
        return;
    }

    int32 Loaded = 0;
    int32 Failed = 0;
    int64 TotalSize = 0;
    int64 LoadedSize = 0;

    for (const FString& Path : BatchLoadPaths)
    {
        if (const FFlutterLoadedAsset* Entry = LoadedAssets.Find(Path))
        {
            TotalSize += Entry->SizeBytes;
            
            if (Entry->State == EFlutterAssetState::Loaded)
            {
                Loaded++;
                LoadedSize += Entry->SizeBytes;
            }
            else if (Entry->State == EFlutterAssetState::Failed)
            {
                Failed++;
            }
        }
    }

    CurrentProgress.LoadedAssets = Loaded;
    CurrentProgress.FailedAssets = Failed;
    CurrentProgress.TotalSizeBytes = TotalSize;
    CurrentProgress.LoadedSizeBytes = LoadedSize;
    CurrentProgress.Progress = BatchLoadPaths.Num() > 0 
        ? (float)(Loaded + Failed) / (float)BatchLoadPaths.Num() 
        : 1.0f;

    OnProgress.Broadcast(CurrentProgress);
    NotifyFlutterProgress(CurrentProgress);

    // Clear batch if complete
    if (Loaded + Failed >= BatchLoadPaths.Num())
    {
        BatchLoadPaths.Empty();
    }
}

int32 UFlutterAssetManager::EstimateAssetSize(UObject* Asset) const
{
    if (!Asset)
    {
        return 0;
    }

    // Simple size estimation - in production, use more accurate methods
    int32 EstimatedSize = 1024; // Base overhead

    // Use resource size if available
    FResourceSizeEx ResourceSize;
    Asset->GetResourceSizeEx(ResourceSize);
    EstimatedSize += (int32)ResourceSize.GetTotalMemoryBytes();

    return EstimatedSize;
}
