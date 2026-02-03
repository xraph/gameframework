// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterMessageRouter.h"
#include "Engine/World.h"
#include "Engine/Engine.h"

// Initialize static instance
UFlutterMessageRouter* UFlutterMessageRouter::Instance = nullptr;

UFlutterMessageRouter::UFlutterMessageRouter()
	: bQueueUnknownTargets(true)
	, MaxQueueSize(1000)
{
}

// ============================================================
// MARK: - Singleton Access
// ============================================================

UFlutterMessageRouter* UFlutterMessageRouter::Get(const UObject* WorldContextObject)
{
	if (!Instance)
	{
		Instance = NewObject<UFlutterMessageRouter>();
		Instance->AddToRoot(); // Prevent garbage collection
	}

	return Instance;
}

// ============================================================
// MARK: - Target Registration
// ============================================================

void UFlutterMessageRouter::RegisterTarget(const FString& Name, UObject* Target, bool bIsSingleton)
{
	if (!Target)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] Cannot register null target: %s"), *Name);
		return;
	}

	// Check if singleton already registered
	if (bIsSingleton && Targets.Contains(Name))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] Singleton target already registered: %s"), *Name);
		return;
	}

	Targets.Add(Name, Target);
	SingletonFlags.Add(Name, bIsSingleton);

	UE_LOG(LogTemp, Log, TEXT("[FlutterRouter] Registered target: %s (Singleton=%d)"), *Name, bIsSingleton);

	// Update statistics
	Statistics.RegisteredTargets = Targets.Num();

	// Flush any queued messages for this target
	FlushQueue();
}

void UFlutterMessageRouter::UnregisterTarget(const FString& Name)
{
	if (Targets.Remove(Name) > 0)
	{
		SingletonFlags.Remove(Name);

		// Remove cached delegates for this target
		TArray<FString> KeysToRemove;
		for (const auto& Pair : CachedDelegates)
		{
			if (Pair.Key.StartsWith(Name + TEXT(":")))
			{
				KeysToRemove.Add(Pair.Key);
			}
		}

		for (const FString& Key : KeysToRemove)
		{
			CachedDelegates.Remove(Key);
		}

		// Same for binary delegates
		KeysToRemove.Empty();
		for (const auto& Pair : CachedBinaryDelegates)
		{
			if (Pair.Key.StartsWith(Name + TEXT(":")))
			{
				KeysToRemove.Add(Pair.Key);
			}
		}

		for (const FString& Key : KeysToRemove)
		{
			CachedBinaryDelegates.Remove(Key);
		}

		UE_LOG(LogTemp, Log, TEXT("[FlutterRouter] Unregistered target: %s"), *Name);

		// Update statistics
		Statistics.RegisteredTargets = Targets.Num();
		Statistics.CachedDelegates = CachedDelegates.Num() + CachedBinaryDelegates.Num();
	}
}

bool UFlutterMessageRouter::IsTargetRegistered(const FString& Name) const
{
	return Targets.Contains(Name);
}

TArray<FFlutterTargetInfo> UFlutterMessageRouter::GetRegisteredTargets() const
{
	TArray<FFlutterTargetInfo> Result;

	for (const auto& Pair : Targets)
	{
		FFlutterTargetInfo Info;
		Info.TargetName = Pair.Key;
		Info.TargetObject = Pair.Value;
		Info.bIsSingleton = SingletonFlags.Contains(Pair.Key) ? SingletonFlags[Pair.Key] : false;

		// Count registered methods
		int32 MethodCount = 0;
		for (const auto& DelegatePair : CachedDelegates)
		{
			if (DelegatePair.Key.StartsWith(Pair.Key + TEXT(":")))
			{
				MethodCount++;
			}
		}
		Info.RegisteredMethods = MethodCount;

		Result.Add(Info);
	}

	return Result;
}

// ============================================================
// MARK: - Method Registration
// ============================================================

void UFlutterMessageRouter::RegisterMethod(const FString& TargetName, const FString& MethodName, FFlutterMethodDelegate Delegate)
{
	FString CacheKey = GetCacheKey(TargetName, MethodName);
	CachedDelegates.Add(CacheKey, Delegate);

	UE_LOG(LogTemp, Log, TEXT("[FlutterRouter] Registered method: %s"), *CacheKey);

	Statistics.CachedDelegates = CachedDelegates.Num() + CachedBinaryDelegates.Num();
}

void UFlutterMessageRouter::RegisterBinaryMethod(const FString& TargetName, const FString& MethodName, FFlutterBinaryMethodDelegate Delegate)
{
	FString CacheKey = GetCacheKey(TargetName, MethodName);
	CachedBinaryDelegates.Add(CacheKey, Delegate);

	UE_LOG(LogTemp, Log, TEXT("[FlutterRouter] Registered binary method: %s"), *CacheKey);

	Statistics.CachedDelegates = CachedDelegates.Num() + CachedBinaryDelegates.Num();
}

void UFlutterMessageRouter::UnregisterMethod(const FString& TargetName, const FString& MethodName)
{
	FString CacheKey = GetCacheKey(TargetName, MethodName);
	CachedDelegates.Remove(CacheKey);
	CachedBinaryDelegates.Remove(CacheKey);

	Statistics.CachedDelegates = CachedDelegates.Num() + CachedBinaryDelegates.Num();
}

// ============================================================
// MARK: - Message Routing
// ============================================================

bool UFlutterMessageRouter::RouteMessage(const FString& Target, const FString& Method, const FString& Data)
{
	FString CacheKey = GetCacheKey(Target, Method);

	// Try cached delegate first (zero-reflection fast path)
	if (TryRouteCached(CacheKey, Method, Data))
	{
		Statistics.MessagesRouted++;
		return true;
	}

	// Check if target is registered but method is not
	if (Targets.Contains(Target))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] No handler for method: %s on target: %s"), *Method, *Target);
		Statistics.MessagesDropped++;
		return false;
	}

	// Target not registered - queue if enabled
	if (bQueueUnknownTargets)
	{
		QueueMessage(Target, Method, Data);
		return true;
	}

	UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] Unknown target: %s"), *Target);
	Statistics.MessagesDropped++;
	return false;
}

bool UFlutterMessageRouter::RouteBinaryMessage(const FString& Target, const FString& Method, const TArray<uint8>& Data)
{
	FString CacheKey = GetCacheKey(Target, Method);

	// Try cached delegate first
	if (TryRouteBinaryCached(CacheKey, Method, Data))
	{
		Statistics.MessagesRouted++;
		return true;
	}

	// Check if target is registered but method is not
	if (Targets.Contains(Target))
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] No binary handler for method: %s on target: %s"), *Method, *Target);
		Statistics.MessagesDropped++;
		return false;
	}

	// Target not registered - queue if enabled
	if (bQueueUnknownTargets)
	{
		FQueuedFlutterMessage QueuedMsg;
		QueuedMsg.Target = Target;
		QueuedMsg.Method = Method;
		QueuedMsg.bIsBinary = true;
		QueuedMsg.BinaryData = Data;

		if (MessageQueue.Num() < MaxQueueSize)
		{
			MessageQueue.Add(QueuedMsg);
			Statistics.QueuedMessages = MessageQueue.Num();
		}
		else
		{
			UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] Message queue full, dropping message"));
			Statistics.MessagesDropped++;
		}
		return true;
	}

	UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] Unknown target: %s"), *Target);
	Statistics.MessagesDropped++;
	return false;
}

bool UFlutterMessageRouter::TryRouteCached(const FString& CacheKey, const FString& Method, const FString& Data)
{
	FFlutterMethodDelegate* Delegate = CachedDelegates.Find(CacheKey);
	if (Delegate && Delegate->IsBound())
	{
		Delegate->Execute(Method, Data);
		return true;
	}
	return false;
}

bool UFlutterMessageRouter::TryRouteBinaryCached(const FString& CacheKey, const FString& Method, const TArray<uint8>& Data)
{
	FFlutterBinaryMethodDelegate* Delegate = CachedBinaryDelegates.Find(CacheKey);
	if (Delegate && Delegate->IsBound())
	{
		Delegate->Execute(Method, Data);
		return true;
	}
	return false;
}

// ============================================================
// MARK: - Message Queuing
// ============================================================

void UFlutterMessageRouter::QueueMessage(const FString& Target, const FString& Method, const FString& Data)
{
	if (MessageQueue.Num() >= MaxQueueSize)
	{
		UE_LOG(LogTemp, Warning, TEXT("[FlutterRouter] Message queue full, dropping oldest message"));
		MessageQueue.RemoveAt(0);
	}

	FQueuedFlutterMessage QueuedMsg;
	QueuedMsg.Target = Target;
	QueuedMsg.Method = Method;
	QueuedMsg.Data = Data;
	QueuedMsg.bIsBinary = false;

	MessageQueue.Add(QueuedMsg);
	Statistics.QueuedMessages = MessageQueue.Num();

	UE_LOG(LogTemp, Verbose, TEXT("[FlutterRouter] Queued message for target: %s"), *Target);
}

void UFlutterMessageRouter::FlushQueue()
{
	if (MessageQueue.Num() == 0)
	{
		return;
	}

	TArray<FQueuedFlutterMessage> MessagesToProcess = MessageQueue;
	MessageQueue.Empty();

	for (const FQueuedFlutterMessage& Msg : MessagesToProcess)
	{
		if (Msg.bIsBinary)
		{
			if (!RouteBinaryMessage(Msg.Target, Msg.Method, Msg.BinaryData))
			{
				// Re-queue if still no handler
				if (bQueueUnknownTargets && !Targets.Contains(Msg.Target))
				{
					MessageQueue.Add(Msg);
				}
			}
		}
		else
		{
			if (!RouteMessage(Msg.Target, Msg.Method, Msg.Data))
			{
				// Re-queue if still no handler
				if (bQueueUnknownTargets && !Targets.Contains(Msg.Target))
				{
					MessageQueue.Add(Msg);
				}
			}
		}
	}

	Statistics.QueuedMessages = MessageQueue.Num();
}

void UFlutterMessageRouter::ClearQueue()
{
	int32 Cleared = MessageQueue.Num();
	MessageQueue.Empty();
	Statistics.QueuedMessages = 0;

	UE_LOG(LogTemp, Log, TEXT("[FlutterRouter] Cleared %d queued messages"), Cleared);
}

// ============================================================
// MARK: - Statistics
// ============================================================

FFlutterRouterStatistics UFlutterMessageRouter::GetStatistics() const
{
	return Statistics;
}

void UFlutterMessageRouter::ResetStatistics()
{
	Statistics.MessagesRouted = 0;
	Statistics.MessagesDropped = 0;
	// Keep registration counts accurate
	Statistics.RegisteredTargets = Targets.Num();
	Statistics.CachedDelegates = CachedDelegates.Num() + CachedBinaryDelegates.Num();
	Statistics.QueuedMessages = MessageQueue.Num();
}

// ============================================================
// MARK: - Configuration
// ============================================================

void UFlutterMessageRouter::SetQueueUnknownTargets(bool bEnable)
{
	bQueueUnknownTargets = bEnable;
}

void UFlutterMessageRouter::SetMaxQueueSize(int32 Size)
{
	MaxQueueSize = FMath::Max(1, Size);

	// Trim queue if necessary
	while (MessageQueue.Num() > MaxQueueSize)
	{
		MessageQueue.RemoveAt(0);
	}

	Statistics.QueuedMessages = MessageQueue.Num();
}

// ============================================================
// MARK: - Helpers
// ============================================================

FString UFlutterMessageRouter::GetCacheKey(const FString& Target, const FString& Method) const
{
	return FString::Printf(TEXT("%s:%s"), *Target, *Method);
}
