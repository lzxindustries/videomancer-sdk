# Contributing to Videomancer SDK

Thank you for your interest in the Videomancer SDK. This document provides information about the project maintenance and how to report issues.

## Table of Contents

- [Maintenance Policy](#maintenance-policy)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)
- [Community Discussion](#community-discussion)
- [Development Information](#development-information)

## Maintenance Policy

The Videomancer SDK is **actively maintained by LZX Industries LLC** as the official development kit for Videomancer hardware. This project is maintained internally to ensure quality, compatibility, and alignment with our hardware roadmap.

### Contribution Model

- **Primary Development:** LZX Industries developers
- **Issue Reports:** Community members are encouraged to report bugs and issues
- **External Contributions:** Not actively solicited; please discuss with maintainers before investing significant effort
- **Pull Requests:** Reviewed on a case-by-case basis; acceptance not guaranteed

### Why This Approach?

- **Quality Control:** Ensures consistency with our hardware and firmware
- **Compatibility:** Maintains tight integration with Videomancer devices
- **Support:** Allows us to provide reliable support to our customers
- **Roadmap Alignment:** Development prioritizes features aligned with our product direction

## Code of Conduct

All interactions in this project should be professional and respectful:

- Be respectful in all communications
- Focus on technical merit
- Accept maintainer decisions gracefully
- Understand that this is a commercially supported product

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

While we prioritize development based on our internal roadmap, we're interested in hearing about use cases and needs from the Videomancer community.

### Feature Request Guidelines

- Describe the use case and problem it solves
- Explain why it's important for Videomancer users
- Provide examples or mockups if applicable
- Understand that implementation is subject to LZX Industries' priorities

**Note:** Feature requests may be closed if they don't align with our product direction, but feedback is valuable for understanding community needs.

## Community Discussion

For general questions, usage help, or discussions:

- **GitHub Discussions:** Use for questions and community interaction
- **Issues:** Reserved for bug reports and confirmed problems
- **Documentation:** Check the comprehensive format specification in `docs/`

## Development Information

This section provides technical information for those interested in understanding the SDK architecture.

### Build Requirements

### Build Requirements

- CMake 3.13 or later
- C++17 compatible compiler (C++20 on non-Windows)
- Git

### Building from Source

```bash
# Clone the repository
git clone https://github.com/lzxindustries/videomancer-sdk.git
cd videomancer-sdk

# Run build script
chmod +x build.sh
./build.sh

# Or manually:
mkdir -p build && cd build
cmake ..
cmake --build .
```

### Project Structure

- `src/lzx/sdk/` - Header-only SDK files
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

By engaging with this project (reporting issues, discussions, etc.), you acknowledge that:

- The Videomancer SDK is licensed under GPL-3.0
- LZX Industries LLC retains all rights to accept, modify, or reject contributions
- Any submitted content may be used by LZX Industries under the project license

## Questions?

For questions about the SDK:

- **Technical Issues:** Open a GitHub issue
- **Usage Questions:** Check documentation first, then GitHub Discussions
- **Commercial Support:** Contact LZX Industries directly

---

**Note:** This is a commercially supported product maintained by LZX Industries LLC. While we appreciate community feedback and bug reports, active development and feature implementation are managed internally to ensure quality and compatibility with Videomancer hardware.
