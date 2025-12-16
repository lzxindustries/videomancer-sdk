# Package Signing Guide



Ed25519 cryptographic signing for Videomancer program packages (`.vmprog` files).



## Quick Start



### 1. Install Dependencies



```bash

# Ubuntu/Debian/WSL2 (recommended)

sudo apt install python3-cryptography



# macOS or other systems

pip3 install cryptography

```



### 2. Generate Keys (One-time)



```bash

# Use setup script

cd scripts/

./setup_ed25519_signing.sh



# Or manually

cd tools/vmprog-packer

python generate_ed25519_keys.py --output-dir ../../keys

```



### 3. Create Packages



```bash

# Signed package (default)

python vmprog_pack.py build/programs/passthru output/passthru.vmprog



# Unsigned package

python vmprog_pack.py --no-sign build/programs/passthru output/passthru.vmprog



# Custom key location

python vmprog_pack.py --keys-dir my_keys build/programs/passthru output/passthru.vmprog

```



## Key Management



**Key Files:**

- Private: `keys/lzx_official_signed_descriptor_priv.bin` (32 bytes) - **Keep secret**

- Public: `keys/lzx_official_signed_descriptor_pub.bin` (32 bytes) - Safe to share



**Security:**

- Private keys are protected by `.gitignore`

- Store private keys in encrypted storage

- Limit access to authorized personnel only

- Back up private keys securely

- Public keys can be freely distributed



## What Gets Signed



The signature covers:

- Program configuration hash

- All FPGA bitstream hashes

- Artifact count and metadata

- Build identifier



This prevents modification of config or bitstreams.



## Troubleshooting



**"cryptography library not available"**

```bash

pip install cryptography

```



**"Private key not found"**

```bash

python generate_ed25519_keys.py --output-dir ../../keys

```



**Package created but unsigned**

- Verify keys exist in `keys/` directory

- Check `cryptography` is installed

- Try explicit key directory: `--keys-dir ../../keys`



## Testing



```bash

cd tools/vmprog-packer

python test_ed25519_signing.py

```



## Technical Details



- **Algorithm:** Ed25519 (EdDSA using Curve25519)

- **Signature size:** 64 bytes

- **Key size:** 32 bytes (public and private)

- **Security level:** ~128 bits



## Related Documentation



- [TOML Configuration Guide](toml-config-guide.md)

- [Package Format Specification](vmprog-format.md)

- [Key Management](../keys/README.md)



