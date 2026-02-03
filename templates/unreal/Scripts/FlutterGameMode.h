// Copyright Epic Games, Inc. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "FlutterGameMode.generated.h"

// Forward declarations
class AFlutterBridge;
class UFlutterMessageRouter;

/**
 * Flutter Game Mode - Base GameMode with Flutter integration
 *
 * Provides a ready-to-use GameMode that integrates with Flutter
 * for game state management, scoring, and level control.
 *
 * Features:
 * - Automatic Flutter bridge setup
 * - Game state synchronization (start, pause, resume, stop)
 * - Score tracking and updates
 * - Level management
 * - Player action handling
 *
 * Usage:
 * 1. Create a subclass or use directly as your GameMode
 * 2. Call game state methods from Blueprint or C++
 * 3. Flutter receives state updates automatically
 *
 * Example Blueprint:
 * - On game start: Call StartGame()
 * - On player death: Call GameOver("Player died")
 * - On score: Call AddScore(100)
 */
UCLASS(Blueprintable, BlueprintType)
class AFlutterGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	AFlutterGameMode();

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

public:
	// ============================================================
	// MARK: - Game State
	// ============================================================

	/**
	 * Start the game
	 * Notifies Flutter and fires OnGameStarted
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Game")
	void StartGame();

	/**
	 * Pause the game
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Game")
	void PauseGame();

	/**
	 * Resume the game
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Game")
	void ResumeGame();

	/**
	 * Stop/end the game
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Game")
	void StopGame();

	/**
	 * Game over with reason
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Game")
	void GameOver(const FString& Reason);

	/**
	 * Restart the game
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Game")
	void RestartGame();

	// ============================================================
	// MARK: - Score Management
	// ============================================================

	/**
	 * Set the current score
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Score")
	void SetScore(int32 NewScore);

	/**
	 * Add to the current score
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Score")
	void AddScore(int32 Points);

	/**
	 * Get the current score
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Score")
	int32 GetScore() const { return CurrentScore; }

	/**
	 * Reset the score to zero
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Score")
	void ResetScore();

	// ============================================================
	// MARK: - Level Management
	// ============================================================

	/**
	 * Set the current level
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Level")
	void SetLevel(int32 NewLevel);

	/**
	 * Advance to next level
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Level")
	void NextLevel();

	/**
	 * Get the current level
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Level")
	int32 GetLevel() const { return CurrentLevel; }

	/**
	 * Load a level by name
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter|Level")
	void LoadGameLevel(const FString& LevelName);

	// ============================================================
	// MARK: - Flutter Communication
	// ============================================================

	/**
	 * Send a custom event to Flutter
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	void SendGameEvent(const FString& EventName, const FString& EventData);

	/**
	 * Send the current game state to Flutter
	 */
	UFUNCTION(BlueprintCallable, Category = "Flutter")
	void SyncGameState();

	// ============================================================
	// MARK: - Blueprint Events
	// ============================================================

	/**
	 * Called when the game starts
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnGameStarted();

	/**
	 * Called when the game is paused
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnGamePaused();

	/**
	 * Called when the game is resumed
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnGameResumed();

	/**
	 * Called when the game stops
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnGameStopped();

	/**
	 * Called on game over
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnGameOver(const FString& Reason);

	/**
	 * Called when score changes
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnScoreChanged(int32 NewScore, int32 Delta);

	/**
	 * Called when level changes
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnLevelChanged(int32 NewLevel);

	/**
	 * Called when a player action is received from Flutter
	 */
	UFUNCTION(BlueprintImplementableEvent, Category = "Flutter|Events")
	void OnPlayerAction(const FString& Action, const FString& Data);

	// ============================================================
	// MARK: - Flutter Message Handlers
	// ============================================================

	/**
	 * Handle messages from Flutter
	 */
	UFUNCTION()
	void HandleFlutterMessage(const FString& Method, const FString& Data);

protected:
	// Game state
	UPROPERTY(BlueprintReadOnly, Category = "Flutter|State")
	bool bIsGameRunning;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter|State")
	bool bIsGamePaused;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter|State")
	int32 CurrentScore;

	UPROPERTY(BlueprintReadOnly, Category = "Flutter|State")
	int32 CurrentLevel;

	// Configuration
	UPROPERTY(EditDefaultsOnly, Category = "Flutter")
	FString FlutterTargetName;

	UPROPERTY(EditDefaultsOnly, Category = "Flutter")
	bool bAutoSyncState;

	UPROPERTY(EditDefaultsOnly, Category = "Flutter")
	float StateSyncInterval;

private:
	// Cached references
	UPROPERTY()
	AFlutterBridge* FlutterBridge;

	UPROPERTY()
	UFlutterMessageRouter* MessageRouter;

	// State sync timer
	FTimerHandle StateSyncTimerHandle;

	// Initialization
	void InitializeFlutter();

	// Send state to Flutter
	void NotifyFlutter(const FString& Event, const FString& Data);
};
