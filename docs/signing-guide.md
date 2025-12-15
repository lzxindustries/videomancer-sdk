# Ed25519 Signing Quick Reference

This guide covers package signing. For TOML configuration details, see [TOML Program Configuration Guide](toml-program-config-guide.md).

## Installation

```bash
# Ubuntu/Debian/WSL2 (recommended - avoids PEP 668 issues)
sudo apt install python3-cryptography

# macOS
pip3 install cryptography

# Other Linux (if pip is allowed)
pip3 install cryptography

# If you get "externally-managed-environment" error:
# Use system package manager or --user flag:
sudo apt install python3-cryptography  # Debian/Ubuntu
pip3 install --user cryptography       # User installation
```

## Generate Keys (One-time Setup)

```bash
# From tools/vmprog-packer directory
python generate_ed25519_keys.py --output-dir ../../keys

# Or use the setup script
cd scripts/
./setup_ed25519_signing.sh   # Linux/macOS/WSL2
```

## Create Packages

### Signed Package (Recommended)
```bash
python vmprog_pack.py \
  ../../build/programs/passthru \
  ../../out/passthru.vmprog
```

### Unsigned Package
```bash
python vmprog_pack.py --no-sign \
  ../../build/programs/passthru \
  ../../out/passthru.vmprog
```

### Custom Key Directory
```bash
python vmprog_pack.py --keys-dir ../../my_keys \
  ../../build/programs/passthru \
  ../../output/passthru.vmprog
```

## Test Signing

```bash
python test_ed25519_signing.py
```

## Key Files

- **Private:** `../../keys/lzx_official_signed_descriptor_priv.bin` (32 bytes) ⚠️ KEEP SECRET
- **Public:** `../../keys/lzx_official_signed_descriptor_pub.bin` (32 bytes) ✓ Safe to share

## Security Checklist

- [ ] Private key is NOT committed to version control (protected by `.gitignore`)
- [ ] Private key is stored securely (encrypted storage recommended)
- [ ] Access to private key is limited to authorized personnel
- [ ] Public key is embedded in firmware for verification
- [ ] Backup of private key exists in secure location

## Troubleshooting

### "cryptography library not available"
```bash
pip install cryptography
```

### "Private key not found"
```bash
python generate_ed25519_keys.py --output-dir ../../keys
```

### Package created but unsigned
- Check that keys exist in `../../keys/` directory
- Verify `cryptography` library is installed
- Try running with explicit key directory: `--keys-dir ../../keys`

## Command Reference

| Command | Description |
|---------|-------------|
| `generate_ed25519_keys.py` | Generate new Ed25519 key pair |
| `test_ed25519_signing.py` | Test signing functionality |
| `vmprog_pack.py` | Create signed/unsigned packages |
| `vmprog_pack.py --no-sign` | Force unsigned package |
| `vmprog_pack.py --keys-dir DIR` | Use keys from custom directory |

## Documentation

- **Full Documentation:** `../../docs/vmprog-ed25519-signing.md`
- **Key Management:** `../../keys/README.md`
- **Package Format:** `../../docs/vmprog-format.md`
- **Tool Usage:** `README.md` (this directory)
