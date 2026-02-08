# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.0.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability, please follow these steps:

### 1. Email Report

Send an email to **security@xraph.com** (or the appropriate security contact) with:

- **Subject**: `[SECURITY] GameFramework - Brief Description`
- **Description**: Detailed description of the vulnerability
- **Impact**: What an attacker could achieve
- **Reproduction**: Step-by-step instructions to reproduce
- **Environment**: Flutter version, package version, platform
- **Proof of Concept**: Code sample demonstrating the issue (if possible)
- **Suggested Fix**: If you have ideas on how to fix it

### 2. Response Timeline

- **24 hours**: Initial acknowledgment of your report
- **72 hours**: Preliminary assessment and triage
- **7 days**: Detailed response with remediation plan
- **30 days**: Security patch released (target)

### 3. Coordinated Disclosure

We follow coordinated disclosure principles:

1. You report the issue privately
2. We confirm and develop a fix
3. We release a security patch
4. We publish a security advisory
5. You may publish details after patch is released

We will credit you in the security advisory unless you prefer to remain anonymous.

## Security Best Practices

### For Users

When using GameFramework:

1. **Keep Updated**: Always use the latest version
2. **Validate Input**: Sanitize all data sent to game engines
3. **Secure Communication**: Use HTTPS for game asset downloads
4. **Platform Security**: Follow platform-specific security guidelines
5. **Permissions**: Request minimal permissions needed

### For Contributors

When contributing code:

1. **Input Validation**: Validate all external input at boundaries
2. **No Secrets**: Never commit credentials, API keys, or tokens
3. **Dependencies**: Keep dependencies updated
4. **Code Review**: All PRs require security review
5. **Static Analysis**: Run `flutter analyze` before committing

## Known Security Considerations

### Platform Views

- Platform views embed native game engines in Flutter
- Native code runs with same permissions as app
- Ensure game engine code is from trusted sources

### Method Channel Communication

- Data passed between Flutter and native engines is serialized
- Validate all messages from game engines
- Don't trust data from game engine implicitly

### WebGL Builds

- WebGL builds run in browser sandbox
- Follow CSP (Content Security Policy) best practices
- Be cautious with eval() and dynamic code execution

### AR Foundation

- Camera and sensor access requires permissions
- Don't store sensitive data in AR scenes
- Follow platform AR privacy guidelines

## Security Updates

Security updates are released as:

- **Patch releases** (e.g., 1.0.1) for minor vulnerabilities
- **Minor releases** (e.g., 1.1.0) for moderate vulnerabilities
- **Major releases** (e.g., 2.0.0) if breaking changes needed

Subscribe to:
- GitHub Security Advisories
- GitHub Releases
- pub.dev package updates

## Vulnerability Disclosure

When we release a security fix:

1. **Security Advisory**: Published on GitHub
2. **CHANGELOG**: Entry in CHANGELOG.md
3. **Release Notes**: Details in GitHub release
4. **CVE**: Request CVE if applicable
5. **Credits**: Acknowledge reporter(s)

## Scope

This security policy covers:

- `gameframework` (core package)
- `gameframework_unity` (Unity plugin)
- `gameframework_unreal` (Unreal plugin)
- Example applications
- Documentation

**Out of Scope:**
- Third-party game engines (Unity, Unreal)
- Third-party plugins or dependencies
- User-created game content
- Social engineering attacks

## Security Tools

We use:

- **Dependabot**: Automated dependency updates
- **CodeQL**: Static analysis for vulnerabilities
- **dart analyze**: Dart static analysis
- **flutter test**: Unit and integration tests

## Contact

- **Security Email**: security@xraph.com
- **GitHub**: @xraph
- **Response Time**: Within 24 hours

## Acknowledgments

We thank the following security researchers for responsible disclosure:

<!-- List will be updated as reports are received and resolved -->

---

**Last Updated**: January 31, 2026
