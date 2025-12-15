#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Generate Ed25519 key pair for Videomancer package signing

This script generates a new Ed25519 private/public key pair and saves them
as raw binary files (32 bytes each) suitable for use with vmprog_pack.py.

Usage:
    python generate_ed25519_keys.py [--output-dir DIR]
    
Example:
    python generate_ed25519_keys.py
    python generate_ed25519_keys.py --output-dir ./my_keys
"""

import sys
import argparse
from pathlib import Path

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives import serialization
except ImportError:
    print("ERROR: cryptography library not installed")
    print("Install with: pip install cryptography")
    sys.exit(1)


def generate_keys(output_dir: Path, prefix: str = "lzx_official_signed_descriptor") -> bool:
    """
    Generate Ed25519 key pair and save to files
    
    Args:
        output_dir: Directory to save keys to
        prefix: Filename prefix for key files
        
    Returns:
        True if successful, False otherwise
    """
    print(f"Generating Ed25519 key pair...")
    
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
    
    # Verify key sizes
    if len(private_bytes) != 32:
        print(f"ERROR: Private key size is {len(private_bytes)} bytes, expected 32")
        return False
    
    if len(public_bytes) != 32:
        print(f"ERROR: Public key size is {len(public_bytes)} bytes, expected 32")
        return False
    
    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Define file paths
    priv_key_path = output_dir / f"{prefix}_priv.bin"
    pub_key_path = output_dir / f"{prefix}_pub.bin"
    
    # Check if keys already exist
    if priv_key_path.exists() or pub_key_path.exists():
        print(f"\n{'='*70}")
        print(f"WARNING: Key files already exist!")
        print(f"{'='*70}")
        if priv_key_path.exists():
            print(f"  {priv_key_path}")
        if pub_key_path.exists():
            print(f"  {pub_key_path}")
        print()
        
        response = input("Overwrite existing keys? (yes/no): ").strip().lower()
        if response not in ['yes', 'y']:
            print("Operation cancelled.")
            return False
    
    # Write keys to files
    priv_key_path.write_bytes(private_bytes)
    pub_key_path.write_bytes(public_bytes)
    
    # Set restrictive permissions on private key (Unix-like systems only)
    try:
        import os
        os.chmod(priv_key_path, 0o600)  # Read/write for owner only
    except (ImportError, AttributeError, OSError):
        pass  # Not available on Windows or permission denied
    
    print(f"\n{'='*70}")
    print(f"✓ Ed25519 key pair generated successfully")
    print(f"{'='*70}")
    print(f"\nPrivate key: {priv_key_path}")
    print(f"  Size: {len(private_bytes)} bytes")
    print(f"  Hex:  {private_bytes.hex()}")
    print(f"\nPublic key:  {pub_key_path}")
    print(f"  Size: {len(public_bytes)} bytes")
    print(f"  Hex:  {public_bytes.hex()}")
    
    print(f"\n{'='*70}")
    print(f"SECURITY NOTICE")
    print(f"{'='*70}")
    print(f"⚠️  Keep the private key ({priv_key_path.name}) secure!")
    print(f"⚠️  Do NOT commit it to version control")
    print(f"⚠️  Do NOT share it publicly")
    print(f"\nThe public key can be safely distributed and is used by")
    print(f"Videomancer firmware to verify package signatures.")
    print()
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description='Generate Ed25519 key pair for Videomancer package signing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
  # Generate keys in current directory
  python generate_ed25519_keys.py
  
  # Generate keys in specific directory
  python generate_ed25519_keys.py --output-dir ../../keys
  
  # Generate keys with custom prefix
  python generate_ed25519_keys.py --prefix my_custom_key

The generated keys will be:
  <prefix>_priv.bin - Private key (32 bytes, keep secret!)
  <prefix>_pub.bin  - Public key (32 bytes, safe to share)
        """
    )
    
    parser.add_argument('--output-dir', '-o', type=Path, default=Path.cwd(),
                       help='Output directory for key files (default: current directory)')
    parser.add_argument('--prefix', '-p', type=str, default='lzx_official_signed_descriptor',
                       help='Filename prefix for key files (default: lzx_official_signed_descriptor)')
    
    args = parser.parse_args()
    
    success = generate_keys(args.output_dir, args.prefix)
    
    if not success:
        sys.exit(1)
    
    sys.exit(0)


if __name__ == '__main__':
    main()
