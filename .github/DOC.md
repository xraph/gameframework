# GitHub Workflows

This directory contains GitHub Actions workflows for automated CI/CD.

## Workflows

### 🔄 CI (`ci.yml`)

**Triggers:** Push to `main`/`develop`, Pull Requests

**Purpose:** Continuous Integration checks for every code change

**Jobs:**
- ✅ **Test** - Runs tests on Linux, macOS, and Windows
- ✅ **Validate Publish** - Ensures packages meet pub.dev requirements
- ✅ **Check Versions** - Verifies version consistency across packages

**What it does:**
- Runs `flutter analyze` for code quality
- Runs `dart format` to check formatting
- Runs `flutter test` with coverage reporting
- Validates packages with `dart pub publish --dry-run`
- Uploads coverage to Codecov

### 🚀 Publish (`publish.yml`)

**Triggers:** 
- Version tags (e.g., `v0.0.1`, `v1.2.3`)
- Manual workflow dispatch

**Purpose:** Automated package publishing to pub.dev

**Jobs:**
1. **Validate** - Pre-flight checks on all packages
2. **Publish gameframework** - Publishes core package first
3. **Publish engine plugins** - Publishes Unity and Unreal plugins in parallel
4. **Create Release** - Creates GitHub release with changelog

**Publishing Order:**
```
gameframework (core)
    ↓
    ├─→ gameframework_unity
    └─→ gameframework_unreal
```

**Configuration Required:**
- GitHub Secret: `PUB_CREDENTIALS` (pub.dev credentials JSON)

## Setup Instructions

### 1. Configure pub.dev Credentials

```bash
# Generate credentials locally
dart pub token add https://pub.dev

# Extract credentials
cat ~/.pub-cache/credentials.json

# Add to GitHub:
# Settings → Secrets → Actions → New repository secret
# Name: PUB_CREDENTIALS
# Value: <paste credentials.json content>
```

### 2. Release Process

#### Automated Release (Recommended)

```bash
# 1. Bump version
make version-bump VERSION=1.0.0

# 2. Run pre-release checks
make release-prepare

# 3. Update CHANGELOG.md
vim CHANGELOG.md

# 4. Commit changes
git add .
git commit -m "chore: release v1.0.0"

# 5. Create and push tag
make release-tag VERSION=1.0.0
git push origin main --tags
```

#### Manual Release

1. Go to **Actions** → **Publish to pub.dev**
2. Click **Run workflow**
3. Select package and options
4. Click **Run workflow**

### 3. Local Testing

```bash
# Run CI checks locally
make ci

# Validate packages for pub.dev
make publish-dry-run

# Check version consistency
make version-check
```

## Workflow Files

| File | Purpose |
|------|---------|
| `ci.yml` | Continuous Integration checks |
| `publish.yml` | Package publishing automation |
| `RELEASE_WORKFLOW.md` | Detailed release documentation |

## Security

- ⚠️ Never commit `credentials.json` to the repository
- ✅ Always use GitHub Secrets for sensitive data
- 🔒 Rotate credentials annually
- 📝 Audit workflow runs regularly

## Troubleshooting

### Failed CI Checks

```bash
# Run locally to debug
make ci

# Check specific package
cd packages/gameframework
flutter analyze
flutter test
```

### Failed Publication

1. Check GitHub Actions logs
2. Verify credentials are correct
3. Ensure version is incremented
4. Run `make publish-dry-run` locally

### Version Mismatch

```bash
# Check versions
make version-check

# Fix versions
make version-bump VERSION=1.0.0
```

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [pub.dev Publishing Guide](https://dart.dev/tools/pub/publishing)
- [Semantic Versioning](https://semver.org/)

## Support

For issues with workflows:
1. Check [GitHub Actions logs](../actions)
2. Review [RELEASE_WORKFLOW.md](RELEASE_WORKFLOW.md)
3. Open an issue in this repository
