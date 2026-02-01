# Development Scripts

This directory contains helper scripts for Flutter Game Framework development.

---

## Available Scripts

### `dev.sh` - Development Helper

Main development script with common tasks.

**Setup:**
```bash
# Make executable (first time only)
chmod +x scripts/dev.sh
```

**Usage:**
```bash
./scripts/dev.sh [command]
```

**Commands:**

| Command | Description |
|---------|-------------|
| `setup` | Initial project setup (install dependencies) |
| `test` | Run all unit tests |
| `test:watch` | Run tests in watch mode |
| `analyze` | Run Flutter static analysis |
| `format` | Format all code |
| `format:check` | Check if code is properly formatted |
| `clean` | Clean all build artifacts |
| `doctor` | Check Flutter environment and dependencies |
| `coverage` | Generate test coverage report |
| `lint` | Run all linting checks (format, analyze, test) |
| `prebuild` | Run all pre-build checks before committing |
| `example` | Run the example app |
| `build:android` | Build example APK for Android |
| `build:ios` | Build example for iOS (macOS only) |
| `help` | Show help message |

---

## Common Workflows

### First-Time Setup

```bash
# Clone the repo
git clone https://github.com/xraph/flutter-game-framework.git
cd flutter-game-framework

# Run setup
./scripts/dev.sh setup
```

### Before Committing

```bash
# Run all pre-build checks
./scripts/dev.sh prebuild

# Or run checks individually
./scripts/dev.sh format
./scripts/dev.sh analyze
./scripts/dev.sh test
```

### Testing

```bash
# Run tests once
./scripts/dev.sh test

# Run tests in watch mode (automatically re-runs on changes)
./scripts/dev.sh test:watch

# Generate coverage report
./scripts/dev.sh coverage
```

### Code Quality

```bash
# Format code
./scripts/dev.sh format

# Run static analysis
./scripts/dev.sh analyze

# Run all linting checks
./scripts/dev.sh lint
```

### Building

```bash
# Run example app
./scripts/dev.sh example

# Build for Android
./scripts/dev.sh build:android

# Build for iOS (macOS only)
./scripts/dev.sh build:ios
```

### Maintenance

```bash
# Clean build artifacts
./scripts/dev.sh clean

# Check environment and dependencies
./scripts/dev.sh doctor
```

---

## CI/CD Integration

These scripts can be used in CI/CD pipelines:

### GitHub Actions Example

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      - name: Setup
        run: ./scripts/dev.sh setup
      - name: Run checks
        run: ./scripts/dev.sh prebuild
```

---

## Troubleshooting

### Permission Denied

If you get "Permission denied" error:
```bash
chmod +x scripts/dev.sh
```

### Flutter Not Found

If the script can't find Flutter:
```bash
# Check Flutter installation
which flutter
flutter --version

# If not installed, follow: https://docs.flutter.dev/get-started/install
```

### Script Fails

Run with verbose output:
```bash
bash -x scripts/dev.sh [command]
```

---

## Adding New Scripts

When adding new scripts:

1. **Create script file** in `scripts/` directory
2. **Make it executable**: `chmod +x scripts/your-script.sh`
3. **Document it** in this README
4. **Follow conventions**:
   - Use bash shebang: `#!/bin/bash`
   - Add error handling: `set -e`
   - Use colored output for clarity
   - Provide help/usage info

---

## Script Conventions

### Exit Codes

- `0` - Success
- `1` - General error
- `2` - Misuse of shell command

### Output Colors

- 🔵 Blue - Headers
- ✅ Green - Success messages
- ❌ Red - Error messages
- ⚠️ Yellow - Warnings

### Best Practices

- Always check command availability before using
- Provide clear error messages
- Return to original directory after operations
- Clean up temporary files
- Handle interrupts gracefully

---

## Future Scripts

Planned additions:

- `release.sh` - Automate release process
- `benchmark.sh` - Run performance benchmarks
- `deploy.sh` - Deploy to pub.dev
- `unity-export.sh` - Helper for Unity project export

---

## Resources

- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)
- [Shell Script Best Practices](https://google.github.io/styleguide/shellguide.html)
- [Flutter CLI Reference](https://docs.flutter.dev/reference/flutter-cli)

---

**Last Updated:** 2024-01
**Framework Version:** 0.4.0
