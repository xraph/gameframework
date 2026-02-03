# Workflow Fix - Matrix Context Issue

## Problem

The original publish workflow had an error:

```
Unrecognized named-value: 'matrix'. Located at position 197 within expression:
(github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')) ||
(github.event_name == 'workflow_dispatch' && 
 (github.event.inputs.package == 'all' || 
  github.event.inputs.package == matrix.package.name))
```

**Root Cause**: The `matrix` context is not available in job-level `if` conditions - it's only available within job steps.

## Solution

Restructured the workflow to handle different publishing scenarios:

### 1. Tag-Based Publishing (Automatic)

```yaml
Tag v1.0.0 pushed
    ↓
validate → publish-gameframework → publish-engine-plugins → create-release
                                    (unity + unreal in parallel)
```

### 2. Manual Publishing - All Packages

```yaml
Workflow dispatch: package=all
    ↓
validate → publish-gameframework → publish-engine-plugins
                                    (unity + unreal in parallel)
```

### 3. Manual Publishing - Core Only

```yaml
Workflow dispatch: package=gameframework
    ↓
validate → publish-gameframework
```

### 4. Manual Publishing - Unity Only

```yaml
Workflow dispatch: package=gameframework_unity
    ↓
validate → publish-gameframework (skipped) → publish-unity
```

### 5. Manual Publishing - Unreal Only

```yaml
Workflow dispatch: package=gameframework_unreal
    ↓
validate → publish-gameframework (skipped) → publish-unreal
```

## Changes Made

### 1. Added Individual Publish Jobs

Created separate jobs for individual package publishing:

- `publish-unity` - Publishes gameframework_unity only
- `publish-unreal` - Publishes gameframework_unreal only

These jobs:
- Run only on manual workflow dispatch
- Use `always()` to run even if gameframework publish is skipped
- Wait for gameframework availability on pub.dev

### 2. Simplified Matrix Job

The `publish-engine-plugins` job now:
- Runs for tag pushes (automatic release)
- Runs for manual "all" selection
- No longer has complex step-level filtering

### 3. Fixed Dependencies

Jobs now use proper dependency chaining:

```yaml
# Individual package jobs
needs: [validate, publish-gameframework]
if: always() && ...

# This allows them to run even if gameframework publish is skipped
```

## Workflow Structure

```yaml
jobs:
  validate:
    # Validates all packages

  publish-gameframework:
    needs: validate
    if: tag push OR (manual && (all OR gameframework))
    # Publishes core package

  publish-unity:
    needs: [validate, publish-gameframework]
    if: always() && manual && gameframework_unity
    # Publishes Unity plugin individually

  publish-unreal:
    needs: [validate, publish-gameframework]
    if: always() && manual && gameframework_unreal
    # Publishes Unreal plugin individually

  publish-engine-plugins:
    needs: publish-gameframework
    if: tag push OR (manual && all)
    strategy:
      matrix:
        package: [unity, unreal]
    # Publishes both plugins in parallel

  create-release:
    needs: [publish-gameframework, publish-engine-plugins]
    if: tag push
    # Creates GitHub release
```

## Key Points

1. **Matrix limitations**: `matrix` context only available in steps, not in job-level conditions

2. **Conditional dependencies**: Using `always()` allows jobs to run even when dependencies are skipped

3. **Separate jobs**: Individual publish jobs provide flexibility for manual publishing

4. **Automatic releases**: Tag-based releases publish all packages automatically

5. **Manual control**: Workflow dispatch allows selective package publishing

## Usage

### Automatic Release (Recommended)

```bash
git tag v1.0.0
git push origin v1.0.0
# Publishes all three packages automatically
```

### Manual Release

1. Go to **Actions** → **Publish to pub.dev**
2. Click **Run workflow**
3. Select:
   - **Package**: Choose which to publish
   - **Dry run**: Enable to test without publishing
4. Click **Run workflow**

## Testing

To verify the workflow syntax:

```bash
# Install actionlint (optional)
brew install actionlint

# Validate workflow
actionlint .github/workflows/publish.yml

# Or push to GitHub and check Actions tab
git push origin main
```

## Notes

- Individual package publishing (unity/unreal only) assumes gameframework is already available on pub.dev
- The workflow waits 60 seconds after publishing gameframework before publishing engine plugins
- Dry-run mode works for all publishing scenarios
- GitHub releases are only created for tag-based pushes, not manual dispatch

---

**Fixed**: January 31, 2026  
**Status**: ✅ Workflow validated and working
