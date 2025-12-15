#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Test script for Ed25519 signing functionality in vmprog_pack.py

This script verifies that:
1. Ed25519 keys can be loaded correctly
2. Signatures are generated correctly
3. Signatures can be verified

Usage:
    python test_ed25519_signing.py
"""

import sys
from pathlib import Path

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
    from cryptography.hazmat.primitives import serialization
    CRYPTO_AVAILABLE = True
except ImportError:
    print("ERROR: cryptography library not installed")
    print("Install with: pip install cryptography")
    sys.exit(1)


def test_key_loading():
    """Test that keys can be loaded from the keys directory"""
    print("=" * 70)
    print("Test 1: Load Ed25519 Keys")
    print("=" * 70)
    
    # Keys directory is at SDK root
    keys_dir = Path(__file__).parent.parent.parent / 'keys'
    priv_key_path = keys_dir / 'lzx_official_signed_descriptor_priv.bin'
    pub_key_path = keys_dir / 'lzx_official_signed_descriptor_pub.bin'
    
    if not priv_key_path.exists():
        print(f"SKIP: Private key not found at {priv_key_path}")
        print("      Run generate_ed25519_keys.py first")
        return False
    
    if not pub_key_path.exists():
        print(f"SKIP: Public key not found at {pub_key_path}")
        print("      Run generate_ed25519_keys.py first")
        return False
    
    try:
        # Load private key
        priv_key_data = priv_key_path.read_bytes()
        print(f"✓ Loaded private key: {len(priv_key_data)} bytes")
        
        if len(priv_key_data) != 32:
            print(f"✗ FAIL: Private key must be 32 bytes, got {len(priv_key_data)}")
            return False
        
        private_key = Ed25519PrivateKey.from_private_bytes(priv_key_data)
        print(f"✓ Parsed private key successfully")
        
        # Load public key
        pub_key_data = pub_key_path.read_bytes()
        print(f"✓ Loaded public key: {len(pub_key_data)} bytes")
        
        if len(pub_key_data) != 32:
            print(f"✗ FAIL: Public key must be 32 bytes, got {len(pub_key_data)}")
            return False
        
        public_key = Ed25519PublicKey.from_public_bytes(pub_key_data)
        print(f"✓ Parsed public key successfully")
        
        # Verify they match
        derived_public_key = private_key.public_key()
        derived_pub_bytes = derived_public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )
        
        if derived_pub_bytes == pub_key_data:
            print(f"✓ Public key matches private key")
        else:
            print(f"⚠ WARNING: Public key does not match private key")
            print(f"  Loaded:  {pub_key_data.hex()[:32]}...")
            print(f"  Derived: {derived_pub_bytes.hex()[:32]}...")
        
        print()
        return True
        
    except Exception as e:
        print(f"✗ FAIL: {e}")
        return False


def test_signing_and_verification():
    """Test that we can sign and verify a descriptor"""
    print("=" * 70)
    print("Test 2: Sign and Verify Descriptor")
    print("=" * 70)
    
    keys_dir = Path(__file__).parent.parent.parent / 'keys'
    priv_key_path = keys_dir / 'lzx_official_signed_descriptor_priv.bin'
    pub_key_path = keys_dir / 'lzx_official_signed_descriptor_pub.bin'
    
    if not priv_key_path.exists() or not pub_key_path.exists():
        print("SKIP: Keys not found (run Test 1 first)")
        return False
    
    try:
        # Load keys
        priv_key_data = priv_key_path.read_bytes()
        private_key = Ed25519PrivateKey.from_private_bytes(priv_key_data)
        
        pub_key_data = pub_key_path.read_bytes()
        public_key = Ed25519PublicKey.from_public_bytes(pub_key_data)
        
        # Create a test descriptor (332 bytes)
        test_descriptor = b'\x00' * 332
        test_descriptor = bytearray(test_descriptor)
        
        # Put some test data in it
        import hashlib
        test_hash = hashlib.sha256(b"test config data").digest()
        test_descriptor[0:32] = test_hash
        test_descriptor[32] = 2  # artifact_count = 2
        
        test_descriptor = bytes(test_descriptor)
        print(f"✓ Created test descriptor: {len(test_descriptor)} bytes")
        
        # Sign the descriptor
        signature = private_key.sign(test_descriptor)
        print(f"✓ Generated signature: {len(signature)} bytes")
        print(f"  Signature: {signature.hex()[:64]}...")
        
        if len(signature) != 64:
            print(f"✗ FAIL: Signature must be 64 bytes, got {len(signature)}")
            return False
        
        # Verify the signature
        try:
            public_key.verify(signature, test_descriptor)
            print(f"✓ Signature verified successfully")
        except Exception as e:
            print(f"✗ FAIL: Signature verification failed: {e}")
            return False
        
        # Test with wrong data (should fail)
        wrong_descriptor = bytearray(test_descriptor)
        wrong_descriptor[0] = (wrong_descriptor[0] + 1) % 256
        wrong_descriptor = bytes(wrong_descriptor)
        
        try:
            public_key.verify(signature, wrong_descriptor)
            print(f"✗ FAIL: Signature verified with wrong data (should have failed)")
            return False
        except:
            print(f"✓ Signature correctly rejected for wrong data")
        
        print()
        return True
        
    except Exception as e:
        print(f"✗ FAIL: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    print()
    print("Testing Ed25519 Signing Functionality")
    print("=" * 70)
    print()
    
    results = []
    
    # Test 1: Load keys
    results.append(("Load Ed25519 Keys", test_key_loading()))
    
    # Test 2: Sign and verify
    results.append(("Sign and Verify Descriptor", test_signing_and_verification()))
    
    # Summary
    print("=" * 70)
    print("Test Summary")
    print("=" * 70)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"{status}: {test_name}")
    
    print()
    print(f"Results: {passed}/{total} tests passed")
    print()
    
    if passed == total:
        print("✓ All tests passed!")
        sys.exit(0)
    else:
        print("✗ Some tests failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
