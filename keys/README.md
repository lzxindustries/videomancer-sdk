# Videomancer Ed25519 Signing Keys

This directory contains Ed25519 keys used for signing Videomancer program packages (`.vmprog` files).

## Key Files

- `lzx_official_signed_descriptor_priv.bin` - Ed25519 private key (32 bytes)

- `lzx_official_signed_descriptor_pub.bin` - Ed25519 public key (32 bytes)

## Security Notice

⚠️ **IMPORTANT**: The private key (`*_priv.bin`) must be kept secure and should **NEVER** be committed to version control or shared publicly. The `.gitignore` file in this directory is configured to exclude the private key.

The public key can be safely distributed and is used by Videomancer firmware to verify package signatures.

## Generating New Keys

To generate a new Ed25519 key pair, you can use the following Python script:

```python

#!/usr/bin/env python3

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from cryptography.hazmat.primitives import serialization

# Generate a new Ed25519 private key

private_key = Ed25519PrivateKey.generate()

# Extract the public key

public_key = private_key.public_key()

# Serialize keys to raw bytes (32 bytes each)

private_bytes = private_key.private_bytes(

    encoding=serialization.Encoding.Raw,

    format=serialization.PrivateFormat.Raw,

    encryption_algorithm=serialization.NoEncryption()

)

public_bytes = public_key.public_bytes(

    encoding=serialization.Encoding.Raw,

    format=serialization.PublicFormat.Raw

)

# Write keys to files

with open('lzx_official_signed_descriptor_priv.bin', 'wb') as f:

    f.write(private_bytes)

with open('lzx_official_signed_descriptor_pub.bin', 'wb') as f:

    f.write(public_bytes)

print(f"Private key: {private_bytes.hex()}")

print(f"Public key:  {public_bytes.hex()}")

```

## Using Keys with vmprog_pack

The `vmprog_pack.py` script automatically looks for keys in this directory and signs packages by default:

```bash

# Sign package (default behavior)

python tools/vmprog-packer/vmprog_pack.py ./build/programs/passthru ./output/passthru.vmprog

# Create unsigned package

python tools/vmprog-packer/vmprog_pack.py --no-sign ./build/programs/passthru ./output/passthru.vmprog

# Use keys from different directory

python tools/vmprog-packer/vmprog_pack.py --keys-dir ./my_keys ./build/programs/passthru ./output/passthru.vmprog

```

## Key Format

Both key files are raw binary Ed25519 keys:

- Private key: 32 bytes (256 bits)

- Public key: 32 bytes (256 bits)

These are **not** PEM or DER encoded - they are the raw key material.

## Signature Verification

The Videomancer firmware verifies signatures using the public key embedded in the firmware. The signature is generated over the `vmprog_signed_descriptor_v1_0` structure (332 bytes) which includes:

- SHA-256 hash of the program configuration

- SHA-256 hashes of all artifacts (FPGA bitstreams)

- Build ID

This ensures that the entire program package contents are cryptographically verified.

## Dependencies

The signing functionality requires the `cryptography` Python library:

```bash

# Ubuntu/Debian/WSL2 (recommended - avoids PEP 668 issues):

sudo apt install python3-cryptography

# macOS:

pip3 install cryptography

# Or if system pip is allowed:

pip3 install cryptography

# If you get "externally-managed-environment" error:

# - Use system package manager (recommended): sudo apt install python3-cryptography

# - Or install for user only: pip3 install --user cryptography

```

If the library is not available, `vmprog_pack.py` will still work but will create unsigned packages (equivalent to using `--no-sign`).

