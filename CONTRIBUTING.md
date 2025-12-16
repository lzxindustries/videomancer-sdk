# Contributing to Videomancer SDK

## Table of Contents

- [Contributing to Videomancer SDK](#contributing-to-videomancer-sdk)
  - [Table of Contents](#table-of-contents)
  - [Maintenance Policy](#maintenance-policy)
  - [Reporting Bugs](#reporting-bugs)
    - [Before Reporting](#before-reporting)
    - [Bug Report Template](#bug-report-template)
  - [Feature Requests](#feature-requests)
  - [Community Discussion](#community-discussion)
  - [Development Information](#development-information)
    - [Build Requirements](#build-requirements)
    - [Building from Source](#building-from-source)
    - [Project Structure](#project-structure)
    - [Coding Standards](#coding-standards)
    - [Architecture](#architecture)
  - [License](#license)

## Maintenance Policy

Maintained by LZX Industries. Bug reports welcome. External contributions reviewed case-by-case; discuss significant changes before investing effort.

## Reporting Bugs

We appreciate bug reports from the community as they help improve the SDK for all Videomancer users.

### Before Reporting

- Check existing issues to avoid duplicates
- Verify the bug is reproducible
- Test with the latest version
- Collect relevant information (OS, compiler, SDK version)

### Bug Report Template

When reporting a bug, please include:

**Describe the Bug**
Clear description of the issue

**To Reproduce**
Steps to reproduce:

1. Step one
2. Step two
3. See error

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**

- OS: [e.g., Windows 11, Ubuntu 22.04]
- Compiler: [e.g., GCC 11.2, MSVC 2022]
- CMake Version: [e.g., 3.25]
- SDK Version: [e.g., 0.1.7]

**Additional Context**
Any other relevant information, logs, or files

## Feature Requests

Submit via GitHub Issues. Describe use case and impact. Implementation subject to LZX Industries priorities.

## Community Discussion

Use GitHub Discussions for questions. Issues for bugs only.

## Development Information

This section provides technical information for those interested in understanding the SDK architecture.

For developers creating new VHDL programs, see the **[Program Development Guide](docs/program-development-guide.md)**.

### Build Requirements

- CMake 3.13+
- C++17 compiler (C++20 on non-Windows)
- Git

### Building from Source

```bash
# Clone the repository
git clone https://github.com/lzxindustries/videomancer-sdk.git
cd videomancer-sdk

# Run initial setup (one-time)
./setup.sh

# Build SDK headers
./build_sdk.sh

# Or manually:
mkdir -p build && cd build
cmake ..
cmake --build .
```

### Project Structure

- `src/lzx/videomancer/` - Header-only SDK files
- `third_party/monocypher/` - Cryptographic library
- `docs/` - Format specification and documentation
- `scripts/` - Build and utility scripts

### Coding Standards

The SDK follows these conventions:

- **C++ Standard:** C++17 minimum (C++20 on non-Windows)
- **Naming:** `snake_case` for types, functions, variables
- **Namespaces:** All code in `lzx` namespace
- **Headers:** Use `.hpp` extension and `#pragma once`
- **Indentation:** 4 spaces (no tabs)

### Architecture

- **Header-only library** for easy integration
- **Packed structures** (`#pragma pack(1)`) for binary compatibility
- **Little-endian** byte order for all multi-byte integers
- **Cryptographic security** via Ed25519 and SHA-256

## License

GPL-3.0. Contributions subject to project license.
