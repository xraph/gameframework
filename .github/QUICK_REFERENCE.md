# Quick Reference - CI/CD Commands

## 🚀 Release in 5 Steps

```bash
# 1. Bump version
make version-bump VERSION=1.0.0

# 2. Update CHANGELOG.md
vim CHANGELOG.md

# 3. Run checks
make release-prepare

# 4. Commit & tag
git add . && git commit -m "chore: release v1.0.0"
make release-tag VERSION=1.0.0

# 5. Push (triggers publish)
git push origin main --tags
```

## 📦 Common Commands

### Version Management
```bash
make version                    # Show current versions
make version-check              # Check consistency
make version-bump VERSION=X.Y.Z # Update all versions
```

### Testing
```bash
make test          # Run all tests
make gameframework # Test core package
make unity         # Test Unity plugin
make unreal        # Test Unreal plugin
```

### Quality Checks
```bash
make ci            # Run full CI checks
make analyze       # Static analysis
make format-check  # Check formatting
make lint          # All linting checks
```

### Publishing
```bash
make publish-dry-run    # Validate packages
make publish-check      # Check pub.dev readiness
make release-prepare    # Full pre-release check
```

## 🔍 Troubleshooting

### Check workflow status
```bash
gh run list              # List recent runs
gh run view <run-id>     # View specific run
gh run watch             # Watch current run
```

### Debug locally
```bash
make ci                  # Run CI checks
make publish-dry-run     # Test publish
make version-check       # Check versions
```

### Fix issues
```bash
make format              # Auto-format code
make clean               # Clean build artifacts
make bootstrap           # Reinstall dependencies
```

## 📚 Documentation

- **Full Guide**: `.github/RELEASE_WORKFLOW.md`
- **Checklist**: `.github/RELEASE_CHECKLIST.md`
- **Security**: `.github/SECURITY.md`
- **Overview**: `.github/README.md`

## 🔗 Links

- **GitHub Actions**: `https://github.com/<org>/<repo>/actions`
- **gameframework**: `https://pub.dev/packages/gameframework`
- **gameframework_unity**: `https://pub.dev/packages/gameframework_unity`
- **gameframework_unreal**: `https://pub.dev/packages/gameframework_unreal`

## 🎯 Publishing Order

```
gameframework → (wait) → unity & unreal (parallel)
```

## ⚠️ Remember

- Always test before releasing
- Check version consistency
- Update CHANGELOG.md
- Never commit credentials
- Monitor GitHub Actions logs

---

**Need help?** See `.github/RELEASE_WORKFLOW.md` for detailed instructions.
