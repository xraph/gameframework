#!/bin/bash

# Flutter Game Framework - Development Helper Script
# This script provides common development tasks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Commands

cmd_help() {
    cat << EOF
Flutter Game Framework - Development Helper

Usage: ./scripts/dev.sh [command]

Commands:
  setup         Initial project setup
  test          Run all tests
  test:watch    Run tests in watch mode
  analyze       Run static analysis
  format        Format all code
  format:check  Check code formatting
  clean         Clean build artifacts
  doctor        Check Flutter and dependencies
  coverage      Generate test coverage report
  lint          Run all linting checks
  prebuild      Run all pre-build checks
  example       Run example app
  build:android Build example for Android
  build:ios     Build example for iOS
  help          Show this help message

Examples:
  ./scripts/dev.sh setup
  ./scripts/dev.sh test
  ./scripts/dev.sh prebuild

EOF
}

cmd_setup() {
    print_header "Setting up Flutter Game Framework"

    echo "Checking Flutter installation..."
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter not found. Please install Flutter first."
        exit 1
    fi
    print_success "Flutter found: $(flutter --version | head -n 1)"

    echo ""
    echo "Installing core dependencies..."
    flutter pub get
    print_success "Core dependencies installed"

    echo ""
    echo "Installing example dependencies..."
    cd example
    flutter pub get
    cd ..
    print_success "Example dependencies installed"

    echo ""
    echo "Installing Unity plugin dependencies..."
    cd engines/unity/dart
    flutter pub get
    cd ../../..
    print_success "Unity plugin dependencies installed"

    echo ""
    print_success "Setup complete!"
    print_warning "Run './scripts/dev.sh doctor' to check your environment"
}

cmd_test() {
    print_header "Running Tests"
    flutter test
    if [ $? -eq 0 ]; then
        print_success "All tests passed!"
    else
        print_error "Tests failed"
        exit 1
    fi
}

cmd_test_watch() {
    print_header "Running Tests in Watch Mode"
    flutter test --watch
}

cmd_analyze() {
    print_header "Running Static Analysis"
    flutter analyze
    if [ $? -eq 0 ]; then
        print_success "No issues found!"
    else
        print_error "Analysis found issues"
        exit 1
    fi
}

cmd_format() {
    print_header "Formatting Code"
    dart format .
    print_success "Code formatted!"
}

cmd_format_check() {
    print_header "Checking Code Format"
    dart format --set-exit-if-changed .
    if [ $? -eq 0 ]; then
        print_success "Code is properly formatted!"
    else
        print_error "Code needs formatting. Run './scripts/dev.sh format'"
        exit 1
    fi
}

cmd_clean() {
    print_header "Cleaning Build Artifacts"

    echo "Cleaning core..."
    flutter clean

    echo "Cleaning example..."
    cd example
    flutter clean
    cd ..

    echo "Cleaning Unity plugin..."
    cd engines/unity/dart
    flutter clean
    cd ../../..

    print_success "Clean complete!"
}

cmd_doctor() {
    print_header "Running Flutter Doctor"
    flutter doctor -v

    echo ""
    print_header "Checking Dependencies"

    echo "Core framework:"
    flutter pub outdated || true

    echo ""
    echo "Unity plugin:"
    cd engines/unity/dart
    flutter pub outdated || true
    cd ../../..
}

cmd_coverage() {
    print_header "Generating Test Coverage"

    if ! command -v lcov &> /dev/null; then
        print_warning "lcov not found. Install it for HTML reports:"
        print_warning "  macOS: brew install lcov"
        print_warning "  Linux: sudo apt-get install lcov"
        echo ""
    fi

    flutter test --coverage

    if [ $? -eq 0 ]; then
        print_success "Coverage generated at: coverage/lcov.info"

        if command -v lcov &> /dev/null; then
            echo ""
            echo "Generating HTML report..."
            genhtml coverage/lcov.info -o coverage/html
            print_success "HTML report: coverage/html/index.html"

            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo ""
                read -p "Open coverage report in browser? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    open coverage/html/index.html
                fi
            fi
        fi
    else
        print_error "Coverage generation failed"
        exit 1
    fi
}

cmd_lint() {
    print_header "Running All Linting Checks"

    echo "1. Checking format..."
    dart format --set-exit-if-changed . > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Format check passed"
    else
        print_error "Format check failed. Run './scripts/dev.sh format'"
        FORMAT_FAILED=1
    fi

    echo ""
    echo "2. Running static analysis..."
    flutter analyze > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Analysis passed"
    else
        print_error "Analysis failed"
        ANALYZE_FAILED=1
    fi

    echo ""
    echo "3. Running tests..."
    flutter test > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Tests passed"
    else
        print_error "Tests failed"
        TEST_FAILED=1
    fi

    echo ""
    if [ -n "$FORMAT_FAILED" ] || [ -n "$ANALYZE_FAILED" ] || [ -n "$TEST_FAILED" ]; then
        print_error "Linting failed!"
        exit 1
    else
        print_success "All linting checks passed!"
    fi
}

cmd_prebuild() {
    print_header "Running Pre-Build Checks"

    cmd_format_check
    echo ""
    cmd_analyze
    echo ""
    cmd_test

    echo ""
    print_success "All pre-build checks passed! Ready to commit."
}

cmd_example() {
    print_header "Running Example App"
    cd example
    flutter run
    cd ..
}

cmd_build_android() {
    print_header "Building Example for Android"
    cd example
    flutter build apk
    print_success "APK built: example/build/app/outputs/flutter-apk/app-release.apk"
    cd ..
}

cmd_build_ios() {
    print_header "Building Example for iOS"

    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "iOS builds only supported on macOS"
        exit 1
    fi

    cd example
    flutter build ios
    print_success "iOS build complete"
    cd ..
}

# Main command dispatcher
case "${1:-help}" in
    setup)
        cmd_setup
        ;;
    test)
        cmd_test
        ;;
    test:watch)
        cmd_test_watch
        ;;
    analyze)
        cmd_analyze
        ;;
    format)
        cmd_format
        ;;
    format:check)
        cmd_format_check
        ;;
    clean)
        cmd_clean
        ;;
    doctor)
        cmd_doctor
        ;;
    coverage)
        cmd_coverage
        ;;
    lint)
        cmd_lint
        ;;
    prebuild)
        cmd_prebuild
        ;;
    example)
        cmd_example
        ;;
    build:android)
        cmd_build_android
        ;;
    build:ios)
        cmd_build_ios
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        cmd_help
        exit 1
        ;;
esac
