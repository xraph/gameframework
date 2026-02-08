# GameFramework - Makefile
# Monorepo build automation for Dart workspace

.PHONY: help setup bootstrap test test-package test-watch analyze format format-check clean clean-deep doctor list-packages coverage lint prebuild example build-android build-ios version version-check version-bump publish-check publish-dry-run publish-gameframework publish-unity publish-unreal publish-all release-prepare release-tag gameframework unity unreal all check ci

# Default target
.DEFAULT_GOAL := help

# Workspace packages
PACKAGES := packages/gameframework engines/unity/dart engines/unreal/dart
EXAMPLE := example

# Colors (works on Unix-like systems)
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@echo "GameFramework - Monorepo Build Automation"
	@echo ""
	@echo "$(BLUE)Workspace Packages:$(NC)"
	@echo "  - packages/gameframework"
	@echo "  - engines/unity/dart"
	@echo "  - engines/unreal/dart"
	@echo "  - example"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup & Installation

bootstrap: ## Bootstrap workspace (resolve all package dependencies)
	@echo "$(BLUE)Bootstrapping workspace...$(NC)"
	@flutter pub get
	@echo "$(GREEN)✓ Workspace bootstrapped!$(NC)"

setup: bootstrap ## Alias for bootstrap (install all dependencies)

##@ Development

test: ## Run all tests across workspace packages
	@echo "$(BLUE)Running tests across workspace...$(NC)"
	@for pkg in $(PACKAGES) $(EXAMPLE); do \
		if [ -d "$$pkg/test" ]; then \
			echo "$(BLUE)Testing $$pkg...$(NC)"; \
			cd $$pkg && flutter test && cd - > /dev/null || exit 1; \
		else \
			echo "$(YELLOW)Skipping $$pkg (no tests)$(NC)"; \
		fi; \
	done
	@echo "$(GREEN)✓ All tests passed!$(NC)"

test-package: ## Run tests for specific package (usage: make test-package PKG=packages/gameframework)
	@if [ -z "$(PKG)" ]; then \
		echo "$(RED)Error: PKG variable not set. Usage: make test-package PKG=packages/gameframework$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Testing $(PKG)...$(NC)"
	@cd $(PKG) && flutter test
	@echo "$(GREEN)✓ Tests passed for $(PKG)!$(NC)"

test-watch: ## Run tests in watch mode (from workspace root)
	@echo "$(BLUE)Running tests in watch mode...$(NC)"
	@flutter test --watch

analyze: ## Run static analysis across workspace
	@echo "$(BLUE)Running static analysis across workspace...$(NC)"
	@for pkg in $(PACKAGES) $(EXAMPLE); do \
		echo "$(BLUE)Analyzing $$pkg...$(NC)"; \
		cd $$pkg && flutter analyze --no-fatal-infos && cd - > /dev/null || exit 1; \
	done
	@echo "$(GREEN)✓ No issues found!$(NC)"

format: ## Format all code
	@echo "$(BLUE)Formatting code...$(NC)"
	@dart format .
	@echo "$(GREEN)✓ Code formatted!$(NC)"

format-check: ## Check code formatting without modifying
	@echo "$(BLUE)Checking code format...$(NC)"
	@dart format --set-exit-if-changed .
	@echo "$(GREEN)✓ Code is properly formatted!$(NC)"

lint: ## Run all linting checks (format, analyze, test) across workspace
	@echo "$(BLUE)Running all linting checks across workspace...$(NC)"
	@echo "1. Checking format..."
	@dart format --set-exit-if-changed . > /dev/null 2>&1 && echo "$(GREEN)  ✓ Format check passed$(NC)" || (echo "$(RED)  ✗ Format check failed$(NC)" && exit 1)
	@echo "2. Running static analysis..."
	@for pkg in $(PACKAGES) $(EXAMPLE); do \
		(cd $$pkg && flutter analyze --no-fatal-infos > /dev/null 2>&1) || (echo "$(RED)  ✗ Analysis failed in $$pkg$(NC)" && exit 1); \
	done
	@echo "$(GREEN)  ✓ Analysis passed$(NC)"
	@echo "3. Running tests..."
	@for pkg in $(PACKAGES) $(EXAMPLE); do \
		if [ -d "$$pkg/test" ]; then \
			(cd $$pkg && flutter test > /dev/null 2>&1) || (echo "$(RED)  ✗ Tests failed in $$pkg$(NC)" && exit 1); \
		else \
			echo "$(YELLOW)  ⊘ Skipping $$pkg (no tests)$(NC)"; \
		fi; \
	done
	@echo "$(GREEN)  ✓ Tests passed$(NC)"
	@echo ""
	@echo "$(GREEN)✓ All linting checks passed!$(NC)"

prebuild: format-check analyze test ## Run all pre-build checks
	@echo ""
	@echo "$(GREEN)✓ All pre-build checks passed! Ready to commit.$(NC)"

##@ Cleanup

clean: ## Clean all build artifacts across workspace
	@echo "$(BLUE)Cleaning build artifacts across workspace...$(NC)"
	@for pkg in $(PACKAGES) $(EXAMPLE); do \
		echo "$(BLUE)Cleaning $$pkg...$(NC)"; \
		cd $$pkg && flutter clean && cd - > /dev/null; \
	done
	@rm -rf .dart_tool
	@echo "$(GREEN)✓ Clean complete!$(NC)"

clean-deep: clean ## Deep clean (includes pub cache and generated files)
	@echo "$(BLUE)Performing deep clean...$(NC)"
	@find . -name "pubspec.lock" -type f -delete
	@find . -name ".dart_tool" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "build" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✓ Deep clean complete!$(NC)"

##@ Diagnostics

doctor: ## Run Flutter doctor and check dependencies across workspace
	@echo "$(BLUE)Running Flutter Doctor...$(NC)"
	@flutter doctor -v
	@echo ""
	@echo "$(BLUE)Checking Dependencies Across Workspace...$(NC)"
	@for pkg in $(PACKAGES) $(EXAMPLE); do \
		echo ""; \
		echo "$(YELLOW)$$pkg:$(NC)"; \
		cd $$pkg && flutter pub outdated && cd - > /dev/null || true; \
	done

list-packages: ## List all packages in workspace
	@echo "$(BLUE)Workspace Packages:$(NC)"
	@for pkg in $(PACKAGES) $(EXAMPLE); do \
		name=$$(grep '^name:' $$pkg/pubspec.yaml | awk '{print $$2}'); \
		version=$$(grep '^version:' $$pkg/pubspec.yaml | awk '{print $$2}'); \
		echo "  $(GREEN)$$pkg$(NC) ($$name@$$version)"; \
	done

coverage: ## Generate test coverage report for all packages
	@echo "$(BLUE)Generating test coverage across workspace...$(NC)"
	@rm -rf coverage
	@mkdir -p coverage
	@for pkg in $(PACKAGES); do \
		echo "$(BLUE)Generating coverage for $$pkg...$(NC)"; \
		cd $$pkg && flutter test --coverage && cd - > /dev/null; \
		if [ -f $$pkg/coverage/lcov.info ]; then \
			cat $$pkg/coverage/lcov.info >> coverage/lcov.info; \
		fi; \
	done
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

##@ Release

version: ## Show versions of all packages
	@echo "$(BLUE)GameFramework - Package Versions$(NC)"
	@echo ""
	@for pkg in $(PACKAGES); do \
		name=$$(grep '^name:' $$pkg/pubspec.yaml | awk '{print $$2}'); \
		version=$$(grep '^version:' $$pkg/pubspec.yaml | awk '{print $$2}'); \
		echo "  $(GREEN)$$name$(NC): $$version"; \
	done

publish-check: ## Check if all packages are ready to publish
	@echo "$(BLUE)Checking packages for publishing...$(NC)"
	@for pkg in $(PACKAGES); do \
		name=$$(grep '^name:' $$pkg/pubspec.yaml | awk '{print $$2}'); \
		echo ""; \
		echo "$(YELLOW)Checking $$name...$(NC)"; \
		cd $$pkg && dart pub publish --dry-run && cd - > /dev/null || exit 1; \
	done
	@echo ""
	@echo "$(GREEN)✓ All packages ready to publish!$(NC)"

publish-gameframework: ## Publish gameframework package to pub.dev
	@echo "$(BLUE)Publishing gameframework...$(NC)"
	@cd packages/gameframework && dart pub publish
	@echo "$(GREEN)✓ gameframework published!$(NC)"

publish-unity: ## Publish gameframework_unity package to pub.dev
	@echo "$(BLUE)Publishing gameframework_unity...$(NC)"
	@cd engines/unity/dart && dart pub publish
	@echo "$(GREEN)✓ gameframework_unity published!$(NC)"

publish-unreal: ## Publish gameframework_unreal package to pub.dev
	@echo "$(BLUE)Publishing gameframework_unreal...$(NC)"
	@cd engines/unreal/dart && dart pub publish
	@echo "$(GREEN)✓ gameframework_unreal published!$(NC)"

publish-all: publish-gameframework publish-unity publish-unreal ## Publish all packages to pub.dev (in order)
	@echo ""
	@echo "$(GREEN)✓ All packages published!$(NC)"

version-check: ## Check version consistency across all packages
	@echo "$(BLUE)Checking version consistency...$(NC)"
	@echo ""
	@GAMEFRAMEWORK_VERSION=$$(grep '^version:' packages/gameframework/pubspec.yaml | awk '{print $$2}'); \
	UNITY_VERSION=$$(grep '^version:' engines/unity/dart/pubspec.yaml | awk '{print $$2}'); \
	UNREAL_VERSION=$$(grep '^version:' engines/unreal/dart/pubspec.yaml | awk '{print $$2}'); \
	UNITY_GAMEFRAMEWORK_DEP=$$(grep '^  gameframework:' engines/unity/dart/pubspec.yaml | grep -v '#' | awk '{print $$2}'); \
	UNREAL_GAMEFRAMEWORK_DEP=$$(grep '^  gameframework:' engines/unreal/dart/pubspec.yaml | grep -v '#' | awk '{print $$2}'); \
	echo "$(GREEN)Package Versions:$(NC)"; \
	echo "  gameframework:        $$GAMEFRAMEWORK_VERSION"; \
	echo "  gameframework_unity:  $$UNITY_VERSION"; \
	echo "  gameframework_unreal: $$UNREAL_VERSION"; \
	echo ""; \
	echo "$(GREEN)Dependencies:$(NC)"; \
	echo "  unity depends on gameframework:  $$UNITY_GAMEFRAMEWORK_DEP"; \
	echo "  unreal depends on gameframework: $$UNREAL_GAMEFRAMEWORK_DEP"; \
	echo ""; \
	if [ "$$UNITY_GAMEFRAMEWORK_DEP" != "$$GAMEFRAMEWORK_VERSION" ]; then \
		echo "$(YELLOW)⚠️  Warning: gameframework_unity depends on gameframework $$UNITY_GAMEFRAMEWORK_DEP, but gameframework is at version $$GAMEFRAMEWORK_VERSION$(NC)"; \
		exit 1; \
	fi; \
	if [ "$$UNREAL_GAMEFRAMEWORK_DEP" != "$$GAMEFRAMEWORK_VERSION" ]; then \
		echo "$(YELLOW)⚠️  Warning: gameframework_unreal depends on gameframework $$UNREAL_GAMEFRAMEWORK_DEP, but gameframework is at version $$GAMEFRAMEWORK_VERSION$(NC)"; \
		exit 1; \
	fi; \
	echo "$(GREEN)✓ All versions are consistent!$(NC)"

version-bump: ## Bump version across all packages (usage: make version-bump VERSION=0.0.2)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: VERSION variable not set. Usage: make version-bump VERSION=0.0.2$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Bumping version to $(VERSION)...$(NC)"
	@# Update gameframework version
	@sed -i.bak 's/^version: .*/version: $(VERSION)/' packages/gameframework/pubspec.yaml && rm packages/gameframework/pubspec.yaml.bak
	@echo "$(GREEN)✓ Updated packages/gameframework$(NC)"
	@# Update unity version and dependency
	@sed -i.bak 's/^version: .*/version: $(VERSION)/' engines/unity/dart/pubspec.yaml && rm engines/unity/dart/pubspec.yaml.bak
	@sed -i.bak 's/^  gameframework: .*/  gameframework: $(VERSION)/' engines/unity/dart/pubspec.yaml && rm engines/unity/dart/pubspec.yaml.bak
	@echo "$(GREEN)✓ Updated engines/unity/dart$(NC)"
	@# Update unreal version and dependency
	@sed -i.bak 's/^version: .*/version: $(VERSION)/' engines/unreal/dart/pubspec.yaml && rm engines/unreal/dart/pubspec.yaml.bak
	@sed -i.bak 's/^  gameframework: .*/  gameframework: $(VERSION)/' engines/unreal/dart/pubspec.yaml && rm engines/unreal/dart/pubspec.yaml.bak
	@echo "$(GREEN)✓ Updated engines/unreal/dart$(NC)"
	@echo ""
	@$(MAKE) version-check

publish-dry-run: ## Dry-run publish all packages (validate without publishing)
	@echo "$(BLUE)Dry-run publishing all packages...$(NC)"
	@echo ""
	@for pkg in $(PACKAGES); do \
		name=$$(grep '^name:' $$pkg/pubspec.yaml | awk '{print $$2}'); \
		version=$$(grep '^version:' $$pkg/pubspec.yaml | awk '{print $$2}'); \
		echo "$(YELLOW)Dry-run: $$name@$$version$(NC)"; \
		cd $$pkg && dart pub publish --dry-run && cd - > /dev/null || exit 1; \
		echo "$(GREEN)✓ $$name validation passed$(NC)"; \
		echo ""; \
	done
	@echo "$(GREEN)✓ All packages validated successfully!$(NC)"

release-prepare: ## Prepare for release (run all checks and validation)
	@echo "$(BLUE)Preparing for release...$(NC)"
	@echo ""
	@echo "$(BLUE)1. Checking version consistency...$(NC)"
	@$(MAKE) version-check
	@echo ""
	@echo "$(BLUE)2. Running format check...$(NC)"
	@$(MAKE) format-check
	@echo ""
	@echo "$(BLUE)3. Running analysis...$(NC)"
	@$(MAKE) analyze
	@echo ""
	@echo "$(BLUE)4. Running tests...$(NC)"
	@$(MAKE) test
	@echo ""
	@echo "$(BLUE)5. Validating packages for pub.dev...$(NC)"
	@$(MAKE) publish-dry-run
	@echo ""
	@echo "$(GREEN)✓ All release checks passed!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Update CHANGELOG.md with release notes"
	@echo "  2. Commit changes: git add . && git commit -m 'chore: release vX.Y.Z'"
	@echo "  3. Create tag: make release-tag VERSION=X.Y.Z"
	@echo "  4. Push: git push origin main --tags"

release-tag: ## Create and push a release tag (usage: make release-tag VERSION=0.0.2)
	@if [ -z "$(VERSION)" ]; then \
		echo "$(RED)Error: VERSION variable not set. Usage: make release-tag VERSION=0.0.2$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Creating release tag v$(VERSION)...$(NC)"
	@# Verify version matches package versions
	@GAMEFRAMEWORK_VERSION=$$(grep '^version:' packages/gameframework/pubspec.yaml | awk '{print $$2}'); \
	if [ "$$GAMEFRAMEWORK_VERSION" != "$(VERSION)" ]; then \
		echo "$(RED)Error: Package version ($$GAMEFRAMEWORK_VERSION) does not match specified VERSION ($(VERSION))$(NC)"; \
		echo "$(YELLOW)Run: make version-bump VERSION=$(VERSION)$(NC)"; \
		exit 1; \
	fi
	@# Check if tag already exists
	@if git rev-parse v$(VERSION) >/dev/null 2>&1; then \
		echo "$(RED)Error: Tag v$(VERSION) already exists$(NC)"; \
		exit 1; \
	fi
	@# Create and push tag
	@git tag -a v$(VERSION) -m "Release v$(VERSION)"
	@echo "$(GREEN)✓ Created tag v$(VERSION)$(NC)"
	@echo ""
	@echo "$(YELLOW)Push tag to trigger release:$(NC)"
	@echo "  git push origin v$(VERSION)"
	@echo ""
	@echo "$(YELLOW)Or push with commits:$(NC)"
	@echo "  git push origin main --tags"

##@ Package-Specific Commands

gameframework: ## Run tests for gameframework package only
	@$(MAKE) test-package PKG=packages/gameframework

unity: ## Run tests for gameframework_unity package only
	@$(MAKE) test-package PKG=engines/unity/dart

unreal: ## Run tests for gameframework_unreal package only
	@$(MAKE) test-package PKG=engines/unreal/dart

##@ All-in-one Commands

all: bootstrap test analyze ## Bootstrap and run all checks
	@echo ""
	@echo "$(GREEN)✓ All tasks completed successfully!$(NC)"

check: lint coverage ## Run all quality checks
	@echo ""
	@echo "$(GREEN)✓ All quality checks passed!$(NC)"

ci: format-check analyze test ## Continuous Integration checks
	@echo ""
	@echo "$(GREEN)✓ CI checks passed!$(NC)"
