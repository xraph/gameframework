# Flutter Game Framework - Makefile
# Cross-platform build automation

.PHONY: help setup test test-watch analyze format format-check clean doctor coverage lint prebuild example build-android build-ios install-cli uninstall-cli

# Default target
.DEFAULT_GOAL := help

# Colors (works on Unix-like systems)
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@echo "Flutter Game Framework - Build Automation"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup & Installation

setup: ## Initial project setup (install all dependencies)
	@echo "$(BLUE)Setting up Flutter Game Framework...$(NC)"
	@flutter pub get
	@cd example && flutter pub get
	@cd engines/unity/dart && flutter pub get
	@cd engines/unreal/dart && flutter pub get
	@echo "$(GREEN)✓ Setup complete!$(NC)"

install-cli: ## Install game CLI globally for local development
	@echo "$(BLUE)Installing Game CLI...$(NC)"
	@cd cli && dart pub get
	@dart pub global activate --source path cli
	@echo ""
	@echo "$(GREEN)✓ Game CLI installed successfully!$(NC)"
	@echo "$(YELLOW)⚠ Make sure your PATH includes: $$HOME/.pub-cache/bin$(NC)"
	@echo ""
	@echo "Try: game --help"

uninstall-cli: ## Uninstall game CLI
	@echo "$(BLUE)Uninstalling Game CLI...$(NC)"
	@dart pub global deactivate game_cli
	@echo "$(GREEN)✓ Game CLI uninstalled$(NC)"

##@ Development

test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	@flutter test
	@echo "$(GREEN)✓ All tests passed!$(NC)"

test-watch: ## Run tests in watch mode
	@echo "$(BLUE)Running tests in watch mode...$(NC)"
	@flutter test --watch

analyze: ## Run static analysis
	@echo "$(BLUE)Running static analysis...$(NC)"
	@flutter analyze
	@echo "$(GREEN)✓ No issues found!$(NC)"

format: ## Format all code
	@echo "$(BLUE)Formatting code...$(NC)"
	@dart format .
	@echo "$(GREEN)✓ Code formatted!$(NC)"

format-check: ## Check code formatting without modifying
	@echo "$(BLUE)Checking code format...$(NC)"
	@dart format --set-exit-if-changed .
	@echo "$(GREEN)✓ Code is properly formatted!$(NC)"

lint: ## Run all linting checks (format, analyze, test)
	@echo "$(BLUE)Running all linting checks...$(NC)"
	@echo "1. Checking format..."
	@dart format --set-exit-if-changed . > /dev/null 2>&1 && echo "$(GREEN)  ✓ Format check passed$(NC)" || (echo "$(RED)  ✗ Format check failed$(NC)" && exit 1)
	@echo "2. Running static analysis..."
	@flutter analyze > /dev/null 2>&1 && echo "$(GREEN)  ✓ Analysis passed$(NC)" || (echo "$(RED)  ✗ Analysis failed$(NC)" && exit 1)
	@echo "3. Running tests..."
	@flutter test > /dev/null 2>&1 && echo "$(GREEN)  ✓ Tests passed$(NC)" || (echo "$(RED)  ✗ Tests failed$(NC)" && exit 1)
	@echo ""
	@echo "$(GREEN)✓ All linting checks passed!$(NC)"

prebuild: format-check analyze test ## Run all pre-build checks
	@echo ""
	@echo "$(GREEN)✓ All pre-build checks passed! Ready to commit.$(NC)"

##@ Cleanup

clean: ## Clean all build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@flutter clean
	@cd example && flutter clean
	@cd engines/unity/dart && flutter clean
	@cd engines/unreal/dart && flutter clean
	@echo "$(GREEN)✓ Clean complete!$(NC)"

##@ Diagnostics

doctor: ## Run Flutter doctor and check dependencies
	@echo "$(BLUE)Running Flutter Doctor...$(NC)"
	@flutter doctor -v
	@echo ""
	@echo "$(BLUE)Checking Dependencies...$(NC)"
	@flutter pub outdated || true
	@echo ""
	@echo "Unity plugin:"
	@cd engines/unity/dart && flutter pub outdated || true
	@echo ""
	@echo "Unreal plugin:"
	@cd engines/unreal/dart && flutter pub outdated || true

coverage: ## Generate test coverage report
	@echo "$(BLUE)Generating test coverage...$(NC)"
	@flutter test --coverage
	@echo "$(GREEN)✓ Coverage generated at: coverage/lcov.info$(NC)"
	@if command -v lcov >/dev/null 2>&1; then \
		echo "Generating HTML report..."; \
		genhtml coverage/lcov.info -o coverage/html; \
		echo "$(GREEN)✓ HTML report: coverage/html/index.html$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Install lcov for HTML reports: brew install lcov$(NC)"; \
	fi

##@ Example App

example: ## Run example app
	@echo "$(BLUE)Running example app...$(NC)"
	@cd example && flutter run

build-android: ## Build example for Android
	@echo "$(BLUE)Building example for Android...$(NC)"
	@cd example && flutter build apk
	@echo "$(GREEN)✓ APK built: example/build/app/outputs/flutter-apk/app-release.apk$(NC)"

build-ios: ## Build example for iOS (macOS only)
	@echo "$(BLUE)Building example for iOS...$(NC)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		cd example && flutter build ios; \
		echo "$(GREEN)✓ iOS build complete$(NC)"; \
	else \
		echo "$(RED)✗ iOS builds only supported on macOS$(NC)"; \
		exit 1; \
	fi

##@ CLI Development

cli-test: ## Run CLI tests
	@echo "$(BLUE)Running CLI tests...$(NC)"
	@cd cli && dart test
	@echo "$(GREEN)✓ CLI tests passed!$(NC)"

cli-analyze: ## Analyze CLI code
	@echo "$(BLUE)Analyzing CLI code...$(NC)"
	@cd cli && dart analyze
	@echo "$(GREEN)✓ CLI analysis passed!$(NC)"

cli-format: ## Format CLI code
	@echo "$(BLUE)Formatting CLI code...$(NC)"
	@cd cli && dart format .
	@echo "$(GREEN)✓ CLI code formatted!$(NC)"

##@ Release

version: ## Show current version
	@echo "Flutter Game Framework"
	@echo "Version: $$(grep '^version:' pubspec.yaml | awk '{print $$2}')"
	@echo "CLI Version: $$(grep '^version:' cli/pubspec.yaml | awk '{print $$2}')"

publish-check: ## Check if package is ready to publish
	@echo "$(BLUE)Checking package...$(NC)"
	@dart pub publish --dry-run
	@echo ""
	@echo "$(BLUE)Checking CLI package...$(NC)"
	@cd cli && dart pub publish --dry-run
	@echo ""
	@echo "$(GREEN)✓ Publish check complete$(NC)"

##@ All-in-one Commands

all: setup test analyze ## Setup and run all checks
	@echo ""
	@echo "$(GREEN)✓ All tasks completed successfully!$(NC)"

check: lint coverage ## Run all quality checks
	@echo ""
	@echo "$(GREEN)✓ All quality checks passed!$(NC)"

ci: format-check analyze test ## Continuous Integration checks
	@echo ""
	@echo "$(GREEN)✓ CI checks passed!$(NC)"
