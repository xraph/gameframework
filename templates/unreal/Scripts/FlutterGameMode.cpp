// Copyright Epic Games, Inc. All Rights Reserved.

#include "FlutterGameMode.h"
#include "FlutterBridge.h"
#include "FlutterMessageRouter.h"
#include "TimerManager.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonWriter.h"
#include "Serialization/JsonSerializer.h"

AFlutterGameMode::AFlutterGameMode()
{
	bIsGameRunning = false;
	bIsGamePaused = false;
	CurrentScore = 0;
	CurrentLevel = 1;
	FlutterTargetName = TEXT("GameMode");
	bAutoSyncState = true;
	StateSyncInterval = 1.0f;
	FlutterBridge = nullptr;
	MessageRouter = nullptr;
}

void AFlutterGameMode::BeginPlay()
{
	Super::BeginPlay();
	InitializeFlutter();
}

void AFlutterGameMode::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	// Clear timer
	if (GetWorld())
	{
		GetWorld()->GetTimerManager().ClearTimer(StateSyncTimerHandle);
	}

	// Unregister from router
	if (MessageRouter)
	{
		MessageRouter->UnregisterTarget(FlutterTargetName);
	}

	Super::EndPlay(EndPlayReason);
}

void AFlutterGameMode::InitializeFlutter()
{
	// Get Flutter bridge
	FlutterBridge = AFlutterBridge::GetInstance(this);
	MessageRouter = UFlutterMessageRouter::Get(this);

	if (MessageRouter)
	{
		// Register as target
		MessageRouter->RegisterTarget(FlutterTargetName, this, true);

		// Register message handlers
		FFlutterMethodDelegate Delegate;
		Delegate.BindDynamic(this, &AFlutterGameMode::HandleFlutterMessage);
		MessageRouter->RegisterMethod(FlutterTargetName, TEXT("playerAction"), Delegate);
		MessageRouter->RegisterMethod(FlutterTargetName, TEXT("requestState"), Delegate);
		MessageRouter->RegisterMethod(FlutterTargetName, TEXT("setLevel"), Delegate);

		UE_LOG(LogTemp, Log, TEXT("[FlutterGameMode] Registered with Flutter router"));
	}

	// Start state sync timer if enabled
	if (bAutoSyncState && StateSyncInterval > 0.0f && GetWorld())
	{
		GetWorld()->GetTimerManager().SetTimer(
			StateSyncTimerHandle,
			this,
			&AFlutterGameMode::SyncGameState,
			StateSyncInterval,
			true
		);
	}
}

// ============================================================
// MARK: - Game State
// ============================================================

void AFlutterGameMode::StartGame()
{
	if (!bIsGameRunning)
	{
		bIsGameRunning = true;
		bIsGamePaused = false;

		NotifyFlutter(TEXT("gameStarted"), TEXT("{}"));
		OnGameStarted();

		UE_LOG(LogTemp, Log, TEXT("[FlutterGameMode] Game started"));
	}
}

void AFlutterGameMode::PauseGame()
{
	if (bIsGameRunning && !bIsGamePaused)
	{
		bIsGamePaused = true;

		NotifyFlutter(TEXT("gamePaused"), TEXT("{}"));
		OnGamePaused();

		UE_LOG(LogTemp, Log, TEXT("[FlutterGameMode] Game paused"));
	}
}

void AFlutterGameMode::ResumeGame()
{
	if (bIsGameRunning && bIsGamePaused)
	{
		bIsGamePaused = false;

		NotifyFlutter(TEXT("gameResumed"), TEXT("{}"));
		OnGameResumed();

		UE_LOG(LogTemp, Log, TEXT("[FlutterGameMode] Game resumed"));
	}
}

void AFlutterGameMode::StopGame()
{
	if (bIsGameRunning)
	{
		bIsGameRunning = false;
		bIsGamePaused = false;

		NotifyFlutter(TEXT("gameStopped"), TEXT("{}"));
		OnGameStopped();

		UE_LOG(LogTemp, Log, TEXT("[FlutterGameMode] Game stopped"));
	}
}

void AFlutterGameMode::GameOver(const FString& Reason)
{
	bIsGameRunning = false;
	bIsGamePaused = false;

	// Build JSON
	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
	JsonObject->SetStringField(TEXT("reason"), Reason);
	JsonObject->SetNumberField(TEXT("finalScore"), CurrentScore);
	JsonObject->SetNumberField(TEXT("finalLevel"), CurrentLevel);

	FString JsonString;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
	FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

	NotifyFlutter(TEXT("gameOver"), JsonString);
	OnGameOver(Reason);

	UE_LOG(LogTemp, Log, TEXT("[FlutterGameMode] Game over: %s"), *Reason);
}

void AFlutterGameMode::RestartGame()
{
	StopGame();
	ResetScore();
	CurrentLevel = 1;
	StartGame();
}

// ============================================================
// MARK: - Score Management
// ============================================================

void AFlutterGameMode::SetScore(int32 NewScore)
{
	int32 Delta = NewScore - CurrentScore;
	CurrentScore = NewScore;

	// Build JSON
	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
	JsonObject->SetNumberField(TEXT("score"), CurrentScore);
	JsonObject->SetNumberField(TEXT("delta"), Delta);

	FString JsonString;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
	FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

	NotifyFlutter(TEXT("scoreChanged"), JsonString);
	OnScoreChanged(CurrentScore, Delta);
}

void AFlutterGameMode::AddScore(int32 Points)
{
	SetScore(CurrentScore + Points);
}

void AFlutterGameMode::ResetScore()
{
	SetScore(0);
}

// ============================================================
// MARK: - Level Management
// ============================================================

void AFlutterGameMode::SetLevel(int32 NewLevel)
{
	CurrentLevel = FMath::Max(1, NewLevel);

	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
	JsonObject->SetNumberField(TEXT("level"), CurrentLevel);

	FString JsonString;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
	FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

	NotifyFlutter(TEXT("levelChanged"), JsonString);
	OnLevelChanged(CurrentLevel);
}

void AFlutterGameMode::NextLevel()
{
	SetLevel(CurrentLevel + 1);
}

void AFlutterGameMode::LoadGameLevel(const FString& LevelName)
{
	if (FlutterBridge)
	{
		FlutterBridge->LoadLevel(LevelName);
	}
}

// ============================================================
// MARK: - Flutter Communication
// ============================================================

void AFlutterGameMode::SendGameEvent(const FString& EventName, const FString& EventData)
{
	NotifyFlutter(EventName, EventData);
}

void AFlutterGameMode::SyncGameState()
{
	TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
	JsonObject->SetBoolField(TEXT("isRunning"), bIsGameRunning);
	JsonObject->SetBoolField(TEXT("isPaused"), bIsGamePaused);
	JsonObject->SetNumberField(TEXT("score"), CurrentScore);
	JsonObject->SetNumberField(TEXT("level"), CurrentLevel);

	FString JsonString;
	TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
	FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

	NotifyFlutter(TEXT("stateSync"), JsonString);
}

void AFlutterGameMode::NotifyFlutter(const FString& Event, const FString& Data)
{
	if (FlutterBridge)
	{
		FlutterBridge->SendToFlutter(FlutterTargetName, Event, Data);
	}
}

// ============================================================
// MARK: - Flutter Message Handlers
// ============================================================

void AFlutterGameMode::HandleFlutterMessage(const FString& Method, const FString& Data)
{
	if (Method == TEXT("playerAction"))
	{
		// Parse action from Data
		TSharedPtr<FJsonObject> JsonObject;
		TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Data);

		if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
		{
			FString Action = JsonObject->GetStringField(TEXT("action"));
			FString ActionData = JsonObject->GetStringField(TEXT("data"));
			OnPlayerAction(Action, ActionData);
		}
	}
	else if (Method == TEXT("requestState"))
	{
		SyncGameState();
	}
	else if (Method == TEXT("setLevel"))
	{
		TSharedPtr<FJsonObject> JsonObject;
		TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Data);

		if (FJsonSerializer::Deserialize(Reader, JsonObject) && JsonObject.IsValid())
		{
			int32 Level = JsonObject->GetIntegerField(TEXT("level"));
			SetLevel(Level);
		}
	}
}
