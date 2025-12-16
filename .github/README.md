# GitHub Actions CI/CD

This directory contains GitHub Actions workflow configurations for automated testing and releases.

## Workflows

### CI (`ci.yml`)
**Triggers:** Push to `main`/`develop`, Pull Requests

**Jobs:**
- **Build and Test** (Ubuntu Latest)
  - Installs dependencies and caches OSS CAD Suite (~2GB)
  - Builds SDK with all 125 C++ tests
  - Runs comprehensive test suite (C++, Python, Shell)
  - Builds example FPGA programs
  - Uploads `.vmprog` artifacts

- **Multi-Platform Testing** (Ubuntu 22.04, 24.04, macOS 13, 14)
  - Validates cross-platform compatibility
  - Runs C++ test suite on each platform

**Duration:** ~5 minutes (cached), ~15 minutes (first run)

### Release (`release.yml`)
**Triggers:** Git tags matching `v*` or `X.Y.Z` patterns

**Actions:**
- Builds SDK and runs full test suite
- Builds all example FPGA programs
- Generates SHA-256 checksums
- Creates GitHub Release with:
  - Pre-built `.vmprog` packages
  - Checksum file
  - Auto-generated release notes

**Usage:**
```bash
git tag -a v0.3.0 -m "Version 0.3.0: Test suite expansion"
git push origin v0.3.0
```

### Documentation (`docs.yml`)
**Triggers:** Push to `main`/`develop`, Pull Requests

**Checks:**
- Validates all markdown links (prevents broken documentation)
- Validates TOML files against JSON schema
- Checks for trailing whitespace
- Verifies script executable permissions

## Configuration Files

### `markdown-link-check-config.json`
Configuration for markdown link validation:
- Ignores localhost URLs
- Ignores GitHub blob URLs (not yet pushed)
- 20-second timeout per link
- Retries on 429 (rate limit)

## Badge Status

The README.md includes workflow status badges:
- **CI Badge**: Shows current build/test status
- **Documentation Badge**: Shows documentation validation status

## Caching Strategy

The workflows cache the OSS CAD Suite toolchain to improve build times:
- **Cache Key**: Based on OS and `scripts/setup.sh` hash
- **Cache Size**: ~2GB
- **Time Saved**: 5-10 minutes per workflow run
- **Invalidation**: Automatic when setup script changes

## Requirements

All workflows run on GitHub-hosted runners with no additional configuration needed. Free for public repositories.

## Local Testing

To test workflow behavior locally, ensure all scripts work:
```bash
# Test build
bash build_sdk.sh --test

# Test full suite
cd tests && bash run_tests.sh

# Test programs
bash build_programs.sh
```

## Future Enhancements

Potential workflow additions:
- Code coverage reporting (gcov/lcov)
- Performance benchmarking
- Nightly builds
- Dependency scanning
- Security scanning
