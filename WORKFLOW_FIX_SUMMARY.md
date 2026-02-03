# ✅ Workflow Fix Complete

## Issue Fixed

**Error**: `Unrecognized named-value: 'matrix'` in `.github/workflows/publish.yml`

**Cause**: Attempted to use `matrix.package.name` in job-level `if` condition, but matrix context is only available within job steps.

## Solution Applied

Restructured the workflow with separate job paths:

### Publishing Paths

```
┌─────────────────────────────────────────────────┐
│                 TAG PUSH (v1.0.0)                │
│                                                   │
│  validate → gameframework → engine-plugins       │
│                             (unity + unreal)     │
│                                 ↓                 │
│                          create-release          │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│            MANUAL DISPATCH: "all"                │
│                                                   │
│  validate → gameframework → engine-plugins       │
│                             (unity + unreal)     │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│       MANUAL DISPATCH: "gameframework"           │
│                                                   │
│  validate → gameframework                        │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│     MANUAL DISPATCH: "gameframework_unity"       │
│                                                   │
│  validate → gameframework (skip) → publish-unity │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│    MANUAL DISPATCH: "gameframework_unreal"       │
│                                                   │
│  validate → gameframework (skip) → publish-unreal│
└─────────────────────────────────────────────────┘
```

## Changes Made

### 1. Added Individual Publish Jobs

- `publish-unity` - For publishing Unity plugin individually
- `publish-unreal` - For publishing Unreal plugin individually

Both jobs:
- Use `always()` to run even if gameframework publish is skipped
- Only run on manual workflow dispatch
- Wait for gameframework availability on pub.dev

### 2. Updated Job Conditions

```yaml
# Original (BROKEN)
if: |
  (github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')) ||
  (github.event_name == 'workflow_dispatch' && 
   (github.event.inputs.package == 'all' || 
    github.event.inputs.package == matrix.package.name))  # ❌ Error!

# Fixed
# Main job for tag pushes and "all"
if: |
  (github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')) ||
  (github.event_name == 'workflow_dispatch' && github.event.inputs.package == 'all')

# Separate jobs for individual packages
publish-unity:
  if: |
    always() &&
    github.event_name == 'workflow_dispatch' && 
    github.event.inputs.package == 'gameframework_unity'

publish-unreal:
  if: |
    always() &&
    github.event_name == 'workflow_dispatch' && 
    github.event.inputs.package == 'gameframework_unreal'
```

### 3. Job Dependencies

```yaml
# Individual jobs can run even if gameframework is skipped
needs: [validate, publish-gameframework]
if: always() && ...
```

## Workflow Jobs

1. **validate** - Validates all packages (always runs)
2. **publish-gameframework** - Publishes core package
3. **publish-unity** - Publishes Unity plugin individually (manual only)
4. **publish-unreal** - Publishes Unreal plugin individually (manual only)
5. **publish-engine-plugins** - Publishes both plugins (tag/all only)
6. **create-release** - Creates GitHub release (tag only)

## Testing

### Local Validation

```bash
# Check workflow syntax (requires actionlint)
actionlint .github/workflows/publish.yml

# Run version checks
make version-check

# Test CI locally
make ci
```

### Manual Testing

1. Go to GitHub **Actions** tab
2. Select **Publish to pub.dev** workflow
3. Click **Run workflow**
4. Select package and enable dry-run
5. Verify it runs without errors

## Usage

### Automatic Release

```bash
# Bump version
make version-bump VERSION=1.0.0

# Update changelog
vim CHANGELOG.md

# Commit and tag
git add .
git commit -m "chore: release v1.0.0"
make release-tag VERSION=1.0.0

# Push (triggers workflow)
git push origin main --tags
```

### Manual Release

1. **Actions** → **Publish to pub.dev** → **Run workflow**
2. Select:
   - Package: `all` / `gameframework` / `gameframework_unity` / `gameframework_unreal`
   - Dry run: `true` (for testing) or `false` (for real publish)
3. Click **Run workflow**

## Key Points

✅ **Fixed**: Matrix context error resolved  
✅ **Tested**: Workflow syntax validated  
✅ **Flexible**: Supports tag-based and manual publishing  
✅ **Safe**: Dry-run mode for testing  
✅ **Automated**: Creates releases automatically  

## Files Modified

- `.github/workflows/publish.yml` - Fixed workflow file
- `.github/WORKFLOW_FIX.md` - Detailed fix explanation
- `WORKFLOW_FIX_SUMMARY.md` - This summary

## Next Steps

1. ✅ Workflow fixed and validated
2. 🔑 Add `PUB_CREDENTIALS` to GitHub Secrets
3. 🧪 Test with dry-run enabled
4. 🚀 Create first release

---

**Fixed**: January 31, 2026  
**Status**: ✅ Ready to use  
**Issue**: Resolved - matrix context error fixed
