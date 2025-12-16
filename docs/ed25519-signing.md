# Ed25519 Signing for Videomancer Program Packages

**Version:** 1.0
**Status:** Production
**Audience:** Firmware developers, program authors, release engineers

---

## Table of Contents

1. [Overview](#1-overview)
2. [Implementation Summary](#2-implementation-summary)
3. [Architecture](#3-architecture)
4. [Usage Guide](#4-usage-guide)
5. [Key Management](#5-key-management)
6. [Security Considerations](#6-security-considerations)
7. [Technical Specifications](#7-technical-specifications)
8. [Testing](#8-testing)
9. [Troubleshooting](#9-troubleshooting)
10. [Future Enhancements](#10-future-enhancements)

---

## 1. Overview

Ed25519 cryptographic signing has been integrated into the Videomancer SDK to enable cryptographic authentication and integrity verification for program packages (`.vmprog` files). This ensures that packages can be verified as authentic and unmodified by the firmware before execution.

### Key Benefits

- **Authentication:** Verify that packages were created by authorized parties
- **Integrity:** Detect any tampering or corruption of package contents
- **Non-repudiation:** Signed packages provide proof of origin
- **Future-proof:** Supports key rotation and multiple signing authorities

### Signing Algorithm

- **Algorithm:** Ed25519 (EdDSA using Curve25519)
- **Signature size:** 64 bytes
- **Key size:** 32 bytes (private and public)
- **Hash function:** SHA-512 (internal to Ed25519)

---

## 2. Implementation Summary

### Changes Made

#### Modified Files

**`scripts/vmprog_pack/vmprog_pack.py`**
- Added `cryptography` library import with graceful fallback
- Implemented `load_ed25519_keys()` function for loading key pairs
- Implemented `sign_descriptor()` function for signature generation
- Updated `build_vmprog_package()` to support signing
- Added command-line arguments for signing control

**`scripts/vmprog_pack/README.md`**
- Documented Ed25519 signing features
- Added key management instructions
- Updated usage examples

#### New Files

**`scripts/vmprog_pack/generate_ed25519_keys.py`**
- Utility for generating Ed25519 key pairs
- Interactive key generation with safety checks
- Restrictive file permissions for private keys

**`scripts/vmprog_pack/test_ed25519_signing.py`**
- Test suite for signing functionality
- Validates key loading and signature generation
- Verifies signature correctness

**`scripts/setup_ed25519_signing.sh`**
- One-step setup script for signing infrastructure
- Automated dependency installation and key generation
- Cross-platform support (Linux/macOS/WSL2)

**`keys/README.md`**
- Key management documentation
- Security guidelines
- Key generation instructions

**`docs/ed25519-signing.md`** (this document)
- Comprehensive implementation documentation

---

## 3. Architecture

### Package Structure

When a package is signed, the following components are included:

```
┌─────────────────────────────────────────┐
│ File Header (64 bytes)                  │
│ - flags: 0x00000001 (signed_pkg)       │
├─────────────────────────────────────────┤
│ Table of Contents (TOC)                 │
│ - CONFIG entry                          │
│ - SIGNED_DESCRIPTOR entry               │
│ - SIGNATURE entry (64 bytes)            │  ← Ed25519 signature
│ - Bitstream entries...                  │
├─────────────────────────────────────────┤
│ Payload: Program Config (7368 bytes)    │
├─────────────────────────────────────────┤
│ Payload: Signed Descriptor (332 bytes)  │  ← Signed data
│ - config_sha256                         │
│ - artifact hashes (bitstreams)          │
│ - build_id                              │
├─────────────────────────────────────────┤
│ Payload: Signature (64 bytes)           │  ← Ed25519 signature
├─────────────────────────────────────────┤
│ Payload: FPGA Bitstreams                │
└─────────────────────────────────────────┘
```

### What is Signed

The Ed25519 signature is computed over the **Signed Descriptor** (332 bytes), which contains:

1. **Config SHA-256** (32 bytes) - Hash of the program configuration
2. **Artifact Count** (1 byte) - Number of bitstreams
3. **Artifact Hashes** (8 × 36 bytes) - SHA-256 hashes of all bitstreams
4. **Flags** (4 bytes) - Descriptor flags
5. **Build ID** (4 bytes) - Unique build identifier

This ensures that:
- The program configuration cannot be modified
- Bitstreams cannot be swapped, added, or removed
- The entire package contents are cryptographically bound

### Signature Verification Flow

```
┌──────────────────┐
│ Load .vmprog     │
│ package          │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Check header     │
│ signed_pkg flag  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Extract          │
│ - Descriptor     │
│ - Signature      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Verify signature │
│ using public key │
└────────┬─────────┘
         │
    ┌────┴────┐
    │  Valid? │
    └────┬────┘
         │
    ┌────┴────┐
    │         │
   Yes       No
    │         │
    ▼         ▼
┌────────┐ ┌──────────┐
│ Accept │ │ Reject   │
│ package│ │ package  │
└────────┘ └──────────┘
```

---

## 4. Usage Guide

### Installation

Install the required Python library:

```bash
pip install cryptography
```

### Generate Keys (One-time Setup)

```bash
# Generate keys in default location (../../keys from vmprog_pack)
cd scripts/vmprog_pack
python generate_ed25519_keys.py --output-dir ../../keys

# Or use the automated setup script
cd scripts
./setup_ed25519_signing.sh    # Linux/macOS/WSL2
```

### Create Signed Packages

**Default (Signed):**
```bash
python scripts/vmprog_pack/vmprog_pack.py \
  ./build/programs/passthru \
  ./output/passthru.vmprog
```

**Unsigned Package:**
```bash
python scripts/vmprog_pack/vmprog_pack.py --no-sign \
  ./build/programs/passthru \
  ./output/passthru.vmprog
```

**Custom Key Directory:**
```bash
python scripts/vmprog_pack/vmprog_pack.py --keys-dir ./my_keys \
  ./build/programs/passthru \
  ./output/passthru.vmprog
```

### Test Signing Functionality

```bash
cd scripts/vmprog_pack
python test_ed25519_signing.py
```

---

## 5. Key Management

### Key File Format

Both keys are stored as raw binary files:
- **Private key:** 32 bytes of raw Ed25519 private key material
- **Public key:** 32 bytes of raw Ed25519 public key material

These are **not** PEM or DER encoded - they are the raw key bytes.

### Key Storage

**Default location:** `keys/` (relative to SDK root)

```
keys/
├── README.md
├── .gitignore
├── lzx_official_signed_descriptor_priv.bin  ⚠️ SECRET
└── lzx_official_signed_descriptor_pub.bin   ✓ PUBLIC
```

### Key Security

**Private keys must:**
- Never be committed to version control (protected by `.gitignore`)
- Be stored in encrypted storage (disk encryption, password manager, HSM)
- Have restrictive file permissions (600 on Unix-like systems)
- Have limited access to authorized personnel only
- Be backed up securely

**Public keys can:**
- Be freely distributed
- Be committed to version control
- Be embedded in firmware
- Be shared publicly

### Key Generation Best Practices

1. **Generate on secure system:** Use a trusted, malware-free system
2. **Use strong randomness:** The `cryptography` library uses OS-provided randomness
3. **Immediate backup:** Back up private keys to secure storage immediately
4. **Document key metadata:** Track key generation date, purpose, authorized users
5. **Plan for rotation:** Have a key rotation strategy

---

## 6. Security Considerations

### Threat Model

**Protected against:**
- Unauthorized package modification
- Bitstream substitution attacks
- Configuration tampering
- Man-in-the-middle attacks (if using secure channels)

**Not protected against:**
- Compromised private keys
- Malicious code in legitimately signed packages
- Side-channel attacks on firmware
- Physical hardware attacks

### Best Practices

1. **Key Hygiene:**
   - Generate keys on secure systems
   - Never share private keys
   - Use hardware security modules (HSM) for production keys
   - Rotate keys periodically

2. **Build Environment:**
   - Sign packages in isolated, secure build environments
   - Audit access to signing systems
   - Log all signing operations
   - Verify signatures after creation

3. **Distribution:**
   - Use secure channels (HTTPS, SSH) to distribute packages
   - Provide signature verification tools to users
   - Publish public key checksums through multiple channels

4. **Incident Response:**
   - Have a key revocation plan
   - Monitor for unauthorized signatures
   - Document compromise procedures
   - Maintain key rotation schedule

---

## 7. Technical Specifications

### Cryptographic Details

**Algorithm:** Ed25519 (Edwards-curve Digital Signature Algorithm)
- **Curve:** Curve25519
- **Security level:** ~128 bits
- **Signature size:** 64 bytes
- **Public key size:** 32 bytes
- **Private key size:** 32 bytes

**Hash functions:**
- **Package hash:** SHA-256 (32 bytes)
- **Payload hashes:** SHA-256 (32 bytes)
- **Ed25519 internal:** SHA-512

### Signed Descriptor Structure

```c
struct vmprog_signed_descriptor_v1_0 {
    uint8_t  config_sha256[32];      // Offset 0
    uint8_t  artifact_count;         // Offset 32
    uint8_t  reserved_pad[3];        // Offset 33
    struct {                         // Offset 36
        uint32_t type;               // 4 bytes
        uint8_t  sha256[32];         // 32 bytes
    } artifacts[8];                  // 8 × 36 = 288 bytes
    uint32_t flags;                  // Offset 324
    uint32_t build_id;               // Offset 328
};                                   // Total: 332 bytes
```

### Signature Generation

```python
# Load private key (32 bytes)
private_key = Ed25519PrivateKey.from_private_bytes(priv_key_data)

# Sign descriptor (332 bytes)
signature = private_key.sign(descriptor_data)  # Returns 64 bytes
```

### Signature Verification

```python
# Load public key (32 bytes)
public_key = Ed25519PublicKey.from_public_bytes(pub_key_data)

# Verify signature
try:
    public_key.verify(signature, descriptor_data)
    # Signature valid
except:
    # Signature invalid
```

---

## 8. Testing

### Test Suite

Run comprehensive tests:

```bash
cd scripts/vmprog_pack
python test_ed25519_signing.py
```

**Tests performed:**
1. Key loading from files
2. Key format validation
3. Public/private key matching
4. Signature generation
5. Signature verification
6. Rejection of invalid signatures

### Manual Testing

**Test signed package creation:**
```bash
# Create test package
python scripts/vmprog_pack/vmprog_pack.py \
  ./build/programs/passthru \
  ./test_signed.vmprog

# Verify it's signed
grep -a "SIGNATURE" test_signed.vmprog || echo "Signed"
```

**Test unsigned package creation:**
```bash
python scripts/vmprog_pack/vmprog_pack.py --no-sign \
  ./build/programs/passthru \
  ./test_unsigned.vmprog
```

---

## 9. Troubleshooting

### Common Issues

**"cryptography library not available"**
```bash
pip install cryptography
```

**"Private key not found"**
```bash
cd scripts/vmprog_pack
python generate_ed25519_keys.py --output-dir ../../keys
```

**"Package created but unsigned"**
- Verify keys exist in correct location
- Check `cryptography` library is installed
- Try specifying keys directory explicitly: `--keys-dir ./keys`

**"Public key does not match private key"**
- Keys may be from different pairs
- Regenerate keys to ensure they match

### Debug Mode

Add print statements to track signing process:

```python
# In vmprog_pack.py
print(f"Keys loaded: private={private_key is not None}, public={public_key is not None}")
print(f"Will sign: {will_sign}")
```

---

## 10. Future Enhancements

### Potential Improvements

1. **Multiple Signing Keys**
   - Support for key rotation
   - Multiple authorized signers
   - Signature chains

2. **Hardware Security Modules (HSM)**
   - PKCS#11 integration
   - Cloud KMS support (AWS, Azure, GCP)
   - YubiKey support

3. **Timestamping**
   - RFC 3161 timestamp tokens
   - Signature freshness verification
   - Expiration dates

4. **Key Revocation**
   - Revocation lists
   - Online revocation checking
   - Emergency key revocation

5. **Additional Signature Algorithms**
   - RSA support for legacy systems
   - Post-quantum algorithms (future-proofing)
   - Algorithm agility

### Backward Compatibility

All enhancements maintain backward compatibility:
- Existing unsigned packages continue to work
- Version-specific signature verification
- Graceful handling of unknown algorithms

---

## References

- [vmprog-format.md](vmprog-format.md) - Package format specification
- [Ed25519 Specification](https://ed25519.cr.yp.to/) - Algorithm details
- [RFC 8032](https://tools.ietf.org/html/rfc8032) - EdDSA standard
- [cryptography library](https://cryptography.io/) - Python implementation
- [Monocypher](https://monocypher.org/) - C implementation (used in firmware)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-14 | Initial implementation |
