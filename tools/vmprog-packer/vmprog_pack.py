#!/usr/bin/env python3
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
"""
Videomancer Program Package Creator

Creates a fully packaged and verified .vmprog file from:
- Program configuration binary (program_config.bin)
- FPGA bitstream binaries (*.bin in bitstreams/ directory)

The output is verified against the vmprog format specification.

Usage:
    python vmprog_pack.py <input_dir> <output_file.vmprog>
    python vmprog_pack.py ./build/programs/passthru ./output/passthru.vmprog

Input directory structure:
    input_dir/
        program_config.bin          # Required: 7372 bytes
        bitstreams/                 # Required directory
            sd_analog.bin           # Optional: SD analog bitstream
            sd_hdmi.bin             # Optional: SD HDMI bitstream
            sd_dual.bin             # Optional: SD dual bitstream
            hd_analog.bin           # Optional: HD analog bitstream
            hd_hdmi.bin             # Optional: HD HDMI bitstream
            hd_dual.bin             # Optional: HD dual bitstream
"""

import struct
import sys
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple, Optional, TYPE_CHECKING
from dataclasses import dataclass

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
    from cryptography.hazmat.primitives import serialization
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False
    if TYPE_CHECKING:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
    print("WARNING: cryptography library not available - signature generation disabled")
    print("Install with: pip install cryptography")


# =============================================================================
# Constants from vmprog_format.hpp
# =============================================================================

# Magic number for vmprog files
VMPROG_MAGIC = 0x47504D56  # 'VMPG'

# Version
VERSION_MAJOR = 1
VERSION_MINOR = 0

# Structure sizes
HEADER_SIZE = 64
TOC_ENTRY_SIZE = 64
PROGRAM_CONFIG_SIZE = 7372
SIGNED_DESCRIPTOR_SIZE = 332
SIGNATURE_SIZE = 64
ARTIFACT_HASH_SIZE = 36

# Limits
MAX_FILE_SIZE = 1048576  # 1 MB
MAX_ARTIFACTS = 8
MAX_TOC_ENTRIES = 256

# TOC Entry Types
class TOCEntryType:
    NONE = 0
    CONFIG = 1
    SIGNED_DESCRIPTOR = 2
    SIGNATURE = 3
    FPGA_BITSTREAM = 4
    BITSTREAM_SD_ANALOG = 5
    BITSTREAM_SD_HDMI = 6
    BITSTREAM_SD_DUAL = 7
    BITSTREAM_HD_ANALOG = 8
    BITSTREAM_HD_HDMI = 9
    BITSTREAM_HD_DUAL = 10

# Header flags
class HeaderFlags:
    NONE = 0x00000000
    SIGNED_PKG = 0x00000001

# Validation result codes
class ValidationResult:
    OK = 0
    INVALID_MAGIC = 1
    INVALID_VERSION = 2
    INVALID_HEADER_SIZE = 3
    INVALID_FILE_SIZE = 4
    INVALID_TOC_OFFSET = 5
    INVALID_TOC_SIZE = 6
    INVALID_TOC_COUNT = 7
    INVALID_ARTIFACT_COUNT = 8
    INVALID_PARAMETER_COUNT = 9
    INVALID_VALUE_LABEL_COUNT = 10
    INVALID_ABI_RANGE = 11
    STRING_NOT_TERMINATED = 12
    INVALID_HASH = 13
    INVALID_TOC_ENTRY = 14
    INVALID_PAYLOAD_OFFSET = 15
    INVALID_PARAMETER_VALUES = 16
    INVALID_ENUM_VALUE = 17
    RESERVED_FIELD_NOT_ZERO = 18

VALIDATION_MESSAGES = {
    ValidationResult.OK: "Validation succeeded",
    ValidationResult.INVALID_MAGIC: "Invalid magic number",
    ValidationResult.INVALID_VERSION: "Unsupported version",
    ValidationResult.INVALID_HEADER_SIZE: "Invalid header size",
    ValidationResult.INVALID_FILE_SIZE: "Invalid file size",
    ValidationResult.INVALID_TOC_OFFSET: "TOC offset out of bounds",
    ValidationResult.INVALID_TOC_SIZE: "Invalid TOC size",
    ValidationResult.INVALID_TOC_COUNT: "Invalid TOC count",
    ValidationResult.INVALID_ARTIFACT_COUNT: "Artifact count out of range",
    ValidationResult.INVALID_PARAMETER_COUNT: "Parameter count exceeds limit",
    ValidationResult.INVALID_VALUE_LABEL_COUNT: "Value label count too high",
    ValidationResult.INVALID_ABI_RANGE: "Invalid ABI range",
    ValidationResult.STRING_NOT_TERMINATED: "String not null-terminated",
    ValidationResult.INVALID_HASH: "Hash verification failed",
    ValidationResult.INVALID_TOC_ENTRY: "TOC entry validation failed",
    ValidationResult.INVALID_PAYLOAD_OFFSET: "Payload offset out of bounds",
    ValidationResult.INVALID_PARAMETER_VALUES: "Parameter value constraints violated",
    ValidationResult.INVALID_ENUM_VALUE: "Enum value out of valid range",
    ValidationResult.RESERVED_FIELD_NOT_ZERO: "Reserved field not zeroed",
}


# =============================================================================
# Data Structures
# =============================================================================

@dataclass
class TOCEntry:
    """Table of Contents entry"""
    entry_type: int
    flags: int
    offset: int
    size: int
    sha256: bytes

@dataclass
class BitstreamFile:
    """FPGA bitstream file metadata"""
    path: Path
    entry_type: int
    data: bytes


# =============================================================================
# Helper Functions
# =============================================================================

def calculate_sha256(data: bytes) -> bytes:
    """Calculate SHA-256 hash of data"""
    return hashlib.sha256(data).digest()


def load_ed25519_keys(keys_dir: Path) -> Tuple[Optional['Ed25519PrivateKey'], Optional['Ed25519PublicKey']]:
    """Load Ed25519 private and public keys from binary files

    Args:
        keys_dir: Directory containing private and public key files

    Returns:
        Tuple of (private_key, public_key) or (None, None) if not available
    """
    if not CRYPTO_AVAILABLE:
        print("WARNING: Cannot load keys - cryptography library not available")
        return None, None

    priv_key_path = keys_dir / 'lzx_official_signed_descriptor_priv.bin'
    pub_key_path = keys_dir / 'lzx_official_signed_descriptor_pub.bin'

    if not priv_key_path.exists():
        print(f"WARNING: Private key not found at {priv_key_path}")
        return None, None

    if not pub_key_path.exists():
        print(f"WARNING: Public key not found at {pub_key_path}")
        return None, None

    try:
        # Load private key (32 bytes)
        priv_key_data = priv_key_path.read_bytes()
        if len(priv_key_data) != 32:
            print(f"ERROR: Private key must be 32 bytes, got {len(priv_key_data)}")
            return None, None

        private_key = Ed25519PrivateKey.from_private_bytes(priv_key_data)

        # Load public key (32 bytes)
        pub_key_data = pub_key_path.read_bytes()
        if len(pub_key_data) != 32:
            print(f"ERROR: Public key must be 32 bytes, got {len(pub_key_data)}")
            return None, None

        public_key = Ed25519PublicKey.from_public_bytes(pub_key_data)

        # Verify that the public key matches the private key
        derived_public_key = private_key.public_key()
        derived_pub_bytes = derived_public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )

        if derived_pub_bytes != pub_key_data:
            print("WARNING: Public key does not match private key")
            # Still return them, but warn the user

        print(f"✓ Loaded Ed25519 keys from {keys_dir}")
        return private_key, public_key

    except Exception as e:
        print(f"ERROR: Failed to load Ed25519 keys: {e}")
        return None, None


def sign_descriptor(descriptor_data: bytes, private_key: 'Ed25519PrivateKey') -> bytes:
    """Sign the descriptor with Ed25519 private key

    Args:
        descriptor_data: The 332-byte signed descriptor to sign
        private_key: Ed25519 private key

    Returns:
        64-byte Ed25519 signature
    """
    if len(descriptor_data) != SIGNED_DESCRIPTOR_SIZE:
        raise ValueError(f"Descriptor must be {SIGNED_DESCRIPTOR_SIZE} bytes, got {len(descriptor_data)}")

    signature = private_key.sign(descriptor_data)

    if len(signature) != SIGNATURE_SIZE:
        raise ValueError(f"Signature must be {SIGNATURE_SIZE} bytes, got {len(signature)}")

    return signature


def pack_string(s: str, max_length: int) -> bytes:
    """Pack a string into a fixed-length null-terminated byte array"""
    encoded = s.encode('utf-8')
    if len(encoded) >= max_length:
        raise ValueError(f"String '{s}' is too long ({len(encoded)} bytes, max {max_length - 1})")
    return encoded + b'\x00' * (max_length - len(encoded))


def validate_string_terminated(data: bytes, offset: int, max_length: int, field_name: str) -> int:
    """Validate that a string field is null-terminated"""
    string_data = data[offset:offset + max_length]
    if b'\x00' not in string_data:
        print(f"ERROR: {field_name} is not null-terminated")
        return ValidationResult.STRING_NOT_TERMINATED
    return ValidationResult.OK


def validate_reserved_zero(data: bytes, offset: int, length: int, field_name: str) -> int:
    """Validate that reserved fields are zeroed"""
    reserved_data = data[offset:offset + length]
    if reserved_data != b'\x00' * length:
        print(f"WARNING: {field_name} contains non-zero values (should be zero)")
        # Don't fail validation for this - just warn
    return ValidationResult.OK


# =============================================================================
# Bitstream Detection
# =============================================================================

BITSTREAM_MAP = {
    'sd_analog.bin': TOCEntryType.BITSTREAM_SD_ANALOG,
    'sd_hdmi.bin': TOCEntryType.BITSTREAM_SD_HDMI,
    'sd_dual.bin': TOCEntryType.BITSTREAM_SD_DUAL,
    'hd_analog.bin': TOCEntryType.BITSTREAM_HD_ANALOG,
    'hd_hdmi.bin': TOCEntryType.BITSTREAM_HD_HDMI,
    'hd_dual.bin': TOCEntryType.BITSTREAM_HD_DUAL,
}


def find_bitstreams(input_dir: Path) -> List[BitstreamFile]:
    """Find and load all bitstream files in the bitstreams/ directory"""
    bitstreams = []
    bitstream_dir = input_dir / 'bitstreams'

    if not bitstream_dir.exists():
        print(f"WARNING: No bitstreams directory found at {bitstream_dir}")
        return bitstreams

    for filename, entry_type in BITSTREAM_MAP.items():
        filepath = bitstream_dir / filename
        if filepath.exists():
            data = filepath.read_bytes()
            bitstreams.append(BitstreamFile(
                path=filepath,
                entry_type=entry_type,
                data=data
            ))
            print(f"Found bitstream: {filename} ({len(data)} bytes)")

    if not bitstreams:
        print(f"WARNING: No bitstream files found in {bitstream_dir}")

    return bitstreams


# =============================================================================
# Package Building
# =============================================================================

def build_vmprog_package(input_dir: Path, output_path: Path, sign: bool = True, keys_dir: Optional[Path] = None) -> bool:
    """
    Build a complete .vmprog package from input directory.

    Args:
        input_dir: Directory containing program_config.bin and bitstreams/
        output_path: Output .vmprog file path
        sign: If True, sign the package with Ed25519 (default: True)
        keys_dir: Directory containing Ed25519 keys (default: ./keys relative to script)

    Returns:
        True if successful, False otherwise
    """
    print(f"\n{'='*70}")
    print(f"Building vmprog package")
    print(f"{'='*70}")
    print(f"Input directory: {input_dir}")
    print(f"Output file: {output_path}")
    print()

    # Load program configuration
    config_path = input_dir / 'program_config.bin'
    if not config_path.exists():
        print(f"ERROR: Program configuration not found at {config_path}")
        return False

    config_data = config_path.read_bytes()
    if len(config_data) != PROGRAM_CONFIG_SIZE:
        print(f"ERROR: Program config size is {len(config_data)} bytes, expected {PROGRAM_CONFIG_SIZE}")
        return False

    print(f"Loaded program config: {len(config_data)} bytes")

    # Find bitstreams
    bitstreams = find_bitstreams(input_dir)
    if not bitstreams:
        print("ERROR: No bitstreams found - at least one bitstream is required")
        return False

    # Load Ed25519 keys if signing is requested
    private_key = None
    public_key = None
    will_sign = False

    if sign:
        if keys_dir is None:
            # Default to ./keys relative to the script location
            script_dir = Path(__file__).parent.parent.parent  # Go up to SDK root
            keys_dir = script_dir / 'keys'

        private_key, public_key = load_ed25519_keys(keys_dir)
        will_sign = private_key is not None and public_key is not None

        if not will_sign:
            print("WARNING: Signing requested but keys could not be loaded")
            print("Package will be created without signature")

    # Build TOC entries and payloads
    toc_entries: List[TOCEntry] = []
    payloads: List[bytes] = []

    # Calculate TOC offset and payload start
    toc_offset = HEADER_SIZE
    # config + signed_descriptor + (optional signature) + bitstreams
    toc_count = 1 + 1 + (1 if will_sign else 0) + len(bitstreams)
    toc_bytes = toc_count * TOC_ENTRY_SIZE
    payload_offset = toc_offset + toc_bytes

    current_offset = payload_offset

    # Add program config entry
    config_hash = calculate_sha256(config_data)
    toc_entries.append(TOCEntry(
        entry_type=TOCEntryType.CONFIG,
        flags=0,
        offset=current_offset,
        size=len(config_data),
        sha256=config_hash
    ))
    payloads.append(config_data)
    current_offset += len(config_data)

    print(f"\nTOC Entry 0: CONFIG")
    print(f"  Offset: {toc_entries[0].offset}")
    print(f"  Size: {toc_entries[0].size}")
    print(f"  Hash: {config_hash.hex()[:16]}...")

    # Build signed descriptor
    print(f"\nBuilding signed descriptor...")
    signed_descriptor = bytearray(SIGNED_DESCRIPTOR_SIZE)

    # config_sha256 (32 bytes at offset 0)
    signed_descriptor[0:32] = config_hash

    # artifact_count (1 byte at offset 32)
    artifact_count = min(len(bitstreams), MAX_ARTIFACTS)
    struct.pack_into('<B', signed_descriptor, 32, artifact_count)

    # reserved_pad (3 bytes at offset 33-35) - already zero-filled

    # artifacts (288 bytes = 8 × 36 bytes, at offset 36)
    artifact_offset = 36
    for i, bitstream in enumerate(bitstreams[:MAX_ARTIFACTS]):
        bitstream_hash = calculate_sha256(bitstream.data)
        # artifact type (4 bytes)
        struct.pack_into('<I', signed_descriptor, artifact_offset, bitstream.entry_type)
        # artifact sha256 (32 bytes)
        signed_descriptor[artifact_offset + 4:artifact_offset + 36] = bitstream_hash
        artifact_offset += ARTIFACT_HASH_SIZE

    # flags (4 bytes at offset 324)
    struct.pack_into('<I', signed_descriptor, 324, 0)  # no flags

    # build_id (4 bytes at offset 328)
    import time
    build_id = int(time.time()) & 0xFFFFFFFF  # Use timestamp as build ID
    struct.pack_into('<I', signed_descriptor, 328, build_id)

    # Add signed descriptor entry
    descriptor_hash = calculate_sha256(bytes(signed_descriptor))
    toc_entries.append(TOCEntry(
        entry_type=TOCEntryType.SIGNED_DESCRIPTOR,
        flags=0,
        offset=current_offset,
        size=len(signed_descriptor),
        sha256=descriptor_hash
    ))
    payloads.append(bytes(signed_descriptor))
    current_offset += len(signed_descriptor)

    print(f"\nTOC Entry 1: SIGNED_DESCRIPTOR")
    print(f"  Offset: {toc_entries[1].offset}")
    print(f"  Size: {toc_entries[1].size}")
    print(f"  Artifact count: {artifact_count}")
    print(f"  Build ID: 0x{build_id:08X}")
    print(f"  Hash: {descriptor_hash.hex()[:16]}...")

    # Generate and add signature if keys are available
    if will_sign:
        print(f"\nGenerating Ed25519 signature...")
        try:
            signature = sign_descriptor(bytes(signed_descriptor), private_key)

            # Add signature entry
            signature_hash = calculate_sha256(signature)
            toc_entries.append(TOCEntry(
                entry_type=TOCEntryType.SIGNATURE,
                flags=0,
                offset=current_offset,
                size=len(signature),
                sha256=signature_hash
            ))
            payloads.append(signature)
            current_offset += len(signature)

            print(f"\nTOC Entry 2: SIGNATURE")
            print(f"  Offset: {toc_entries[2].offset}")
            print(f"  Size: {toc_entries[2].size}")
            print(f"  Hash: {signature_hash.hex()[:16]}...")
            print(f"  Signature: {signature.hex()[:32]}...")
        except Exception as e:
            print(f"ERROR: Failed to generate signature: {e}")
            return False

    # Add bitstream entries
    bitstream_start_idx = 2 if will_sign else 1
    for i, bitstream in enumerate(bitstreams):
        bitstream_hash = calculate_sha256(bitstream.data)
        toc_entries.append(TOCEntry(
            entry_type=bitstream.entry_type,
            flags=0,
            offset=current_offset,
            size=len(bitstream.data),
            sha256=bitstream_hash
        ))
        payloads.append(bitstream.data)

        entry_type_name = [k for k, v in vars(TOCEntryType).items()
                          if not k.startswith('_') and v == bitstream.entry_type][0]
        toc_entry_idx = bitstream_start_idx + 1 + i
        print(f"\nTOC Entry {toc_entry_idx}: {entry_type_name}")
        print(f"  File: {bitstream.path.name}")
        print(f"  Offset: {current_offset}")
        print(f"  Size: {len(bitstream.data)}")
        print(f"  Hash: {bitstream_hash.hex()[:16]}...")

        current_offset += len(bitstream.data)

    file_size = current_offset

    # Check file size constraint
    if file_size > MAX_FILE_SIZE:
        print(f"\nERROR: Package size {file_size} exceeds maximum {MAX_FILE_SIZE}")
        return False

    print(f"\nTotal package size: {file_size} bytes ({file_size / 1024:.1f} KB)")

    # Build header
    header = bytearray(HEADER_SIZE)

    # Pack header fields
    struct.pack_into('<I', header, 0, VMPROG_MAGIC)           # magic
    struct.pack_into('<H', header, 4, VERSION_MAJOR)          # version_major
    struct.pack_into('<H', header, 6, VERSION_MINOR)          # version_minor
    struct.pack_into('<H', header, 8, HEADER_SIZE)            # header_size
    struct.pack_into('<H', header, 10, 0)                     # reserved_pad
    struct.pack_into('<I', header, 12, file_size)             # file_size
    # Set signed_pkg flag if package is signed
    flags = HeaderFlags.SIGNED_PKG if will_sign else HeaderFlags.NONE
    struct.pack_into('<I', header, 16, flags)                 # flags
    struct.pack_into('<I', header, 20, toc_offset)            # toc_offset
    struct.pack_into('<I', header, 24, toc_bytes)             # toc_bytes
    struct.pack_into('<I', header, 28, toc_count)             # toc_count
    # sha256_package at offset 32 - will be calculated later

    # Build TOC
    toc = bytearray()
    for entry in toc_entries:
        toc_entry = bytearray(TOC_ENTRY_SIZE)
        struct.pack_into('<I', toc_entry, 0, entry.entry_type)
        struct.pack_into('<I', toc_entry, 4, entry.flags)
        struct.pack_into('<I', toc_entry, 8, entry.offset)
        struct.pack_into('<I', toc_entry, 12, entry.size)
        toc_entry[16:48] = entry.sha256
        # reserved[4] at offset 48-63 already zero-filled
        toc += toc_entry

    # Assemble complete package
    package = bytearray()
    package += header
    package += toc
    for payload in payloads:
        package += payload

    # Calculate package hash over entire file except the hash field itself
    # The hash field (32 bytes at offset 32) should be zero during hash calculation
    package_for_hash = bytearray(package)
    package_for_hash[32:64] = b'\x00' * 32  # Zero out the hash field
    package_hash = calculate_sha256(bytes(package_for_hash))

    # Update package hash in header
    package[32:64] = package_hash

    print(f"\nPackage hash: {package_hash.hex()}")

    # Print signature status
    if will_sign:
        print(f"\n✓ Package is SIGNED with Ed25519")
    else:
        print(f"\n⚠ Package is UNSIGNED")

    # Write to file
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(package)

    print(f"\n{'='*70}")
    print(f"Package created successfully: {output_path}")
    print(f"{'='*70}")

    return True


# =============================================================================
# Package Validation
# =============================================================================

def validate_vmprog_package(filepath: Path, verify_hashes: bool = True) -> bool:
    """
    Validate a .vmprog package against the format specification.

    Args:
        filepath: Path to .vmprog file
        verify_hashes: If True, verify all payload hashes

    Returns:
        True if validation passes, False otherwise
    """
    print(f"\n{'='*70}")
    print(f"Validating vmprog package")
    print(f"{'='*70}")
    print(f"File: {filepath}")
    print(f"Verify hashes: {verify_hashes}")
    print()

    # Read file
    if not filepath.exists():
        print(f"ERROR: File not found: {filepath}")
        return False

    data = filepath.read_bytes()
    file_size = len(data)

    print(f"File size: {file_size} bytes ({file_size / 1024:.1f} KB)")

    # Validate file size
    if file_size < HEADER_SIZE:
        print(f"ERROR: File too small ({file_size} bytes, minimum {HEADER_SIZE})")
        return False

    if file_size > MAX_FILE_SIZE:
        print(f"ERROR: File too large ({file_size} bytes, maximum {MAX_FILE_SIZE})")
        return False

    # Parse and validate header
    print("\n--- Header Validation ---")

    magic = struct.unpack_from('<I', data, 0)[0]
    if magic != VMPROG_MAGIC:
        print(f"ERROR: Invalid magic number: 0x{magic:08X} (expected 0x{VMPROG_MAGIC:08X})")
        return False
    print(f"✓ Magic: 0x{magic:08X} ('VMPG')")

    version_major = struct.unpack_from('<H', data, 4)[0]
    version_minor = struct.unpack_from('<H', data, 6)[0]
    if version_major != VERSION_MAJOR or version_minor != VERSION_MINOR:
        print(f"ERROR: Unsupported version {version_major}.{version_minor} (expected {VERSION_MAJOR}.{VERSION_MINOR})")
        return False
    print(f"✓ Version: {version_major}.{version_minor}")

    header_size = struct.unpack_from('<H', data, 8)[0]
    if header_size != HEADER_SIZE:
        print(f"ERROR: Invalid header size {header_size} (expected {HEADER_SIZE})")
        return False
    print(f"✓ Header size: {header_size}")

    reported_file_size = struct.unpack_from('<I', data, 12)[0]
    if reported_file_size != file_size:
        print(f"ERROR: File size mismatch: header says {reported_file_size}, actual {file_size}")
        return False
    print(f"✓ File size: {reported_file_size}")

    flags = struct.unpack_from('<I', data, 16)[0]
    print(f"✓ Flags: 0x{flags:08X}")

    toc_offset = struct.unpack_from('<I', data, 20)[0]
    toc_bytes = struct.unpack_from('<I', data, 24)[0]
    toc_count = struct.unpack_from('<I', data, 28)[0]

    if toc_offset != HEADER_SIZE:
        print(f"WARNING: TOC offset {toc_offset} is not immediately after header ({HEADER_SIZE})")

    if toc_offset + toc_bytes > file_size:
        print(f"ERROR: TOC extends beyond file (offset {toc_offset} + size {toc_bytes} > {file_size})")
        return False
    print(f"✓ TOC: offset={toc_offset}, bytes={toc_bytes}, count={toc_count}")

    expected_toc_bytes = toc_count * TOC_ENTRY_SIZE
    if toc_bytes != expected_toc_bytes:
        print(f"ERROR: TOC size mismatch: {toc_bytes} bytes for {toc_count} entries (expected {expected_toc_bytes})")
        return False
    print(f"✓ TOC size matches entry count")

    package_hash = data[32:64]
    print(f"✓ Package hash: {package_hash.hex()}")

    # Verify package hash if requested
    if verify_hashes:
        print("\n--- Package Hash Verification ---")
        data_for_hash = bytearray(data)
        data_for_hash[32:64] = b'\x00' * 32
        calculated_hash = calculate_sha256(bytes(data_for_hash))

        if calculated_hash != package_hash:
            print(f"ERROR: Package hash mismatch!")
            print(f"  Stored:     {package_hash.hex()}")
            print(f"  Calculated: {calculated_hash.hex()}")
            return False
        print(f"✓ Package hash verified")

    # Parse and validate TOC entries
    print("\n--- TOC Entries Validation ---")

    for i in range(toc_count):
        entry_offset = toc_offset + (i * TOC_ENTRY_SIZE)
        entry_type = struct.unpack_from('<I', data, entry_offset + 0)[0]
        entry_flags = struct.unpack_from('<I', data, entry_offset + 4)[0]
        payload_offset = struct.unpack_from('<I', data, entry_offset + 8)[0]
        payload_size = struct.unpack_from('<I', data, entry_offset + 12)[0]
        payload_hash = data[entry_offset + 16:entry_offset + 48]

        entry_type_name = "UNKNOWN"
        for name, value in vars(TOCEntryType).items():
            if not name.startswith('_') and value == entry_type:
                entry_type_name = name
                break

        print(f"\nEntry {i}: {entry_type_name}")
        print(f"  Type: {entry_type}")
        print(f"  Flags: 0x{entry_flags:08X}")
        print(f"  Offset: {payload_offset}")
        print(f"  Size: {payload_size}")
        print(f"  Hash: {payload_hash.hex()[:32]}...")

        # Validate payload bounds
        if payload_offset + payload_size > file_size:
            print(f"  ERROR: Payload extends beyond file!")
            return False
        print(f"  ✓ Payload within file bounds")

        # Verify payload hash if requested
        if verify_hashes:
            payload_data = data[payload_offset:payload_offset + payload_size]
            calculated_hash = calculate_sha256(payload_data)

            if calculated_hash != payload_hash:
                print(f"  ERROR: Payload hash mismatch!")
                print(f"    Stored:     {payload_hash.hex()}")
                print(f"    Calculated: {calculated_hash.hex()}")
                return False
            print(f"  ✓ Payload hash verified")

        # Validate specific payload types
        if entry_type == TOCEntryType.CONFIG:
            if payload_size != PROGRAM_CONFIG_SIZE:
                print(f"  ERROR: Config size {payload_size} != expected {PROGRAM_CONFIG_SIZE}")
                return False
            print(f"  ✓ Config size correct")

            # Validate config structure
            result = validate_program_config(data, payload_offset)
            if result != ValidationResult.OK:
                print(f"  ERROR: Config validation failed: {VALIDATION_MESSAGES[result]}")
                return False
            print(f"  ✓ Config structure validated")

        elif entry_type == TOCEntryType.SIGNED_DESCRIPTOR:
            if payload_size != SIGNED_DESCRIPTOR_SIZE:
                print(f"  ERROR: Signed descriptor size {payload_size} != expected {SIGNED_DESCRIPTOR_SIZE}")
                return False
            print(f"  ✓ Signed descriptor size correct")

            # Validate descriptor structure
            result = validate_signed_descriptor(data, payload_offset)
            if result != ValidationResult.OK:
                print(f"  ERROR: Signed descriptor validation failed: {VALIDATION_MESSAGES[result]}")
                return False
            print(f"  ✓ Signed descriptor structure validated")

    print(f"\n{'='*70}")
    print(f"✓ Validation PASSED")
    print(f"{'='*70}")

    return True


def validate_signed_descriptor(data: bytes, offset: int) -> int:
    """Validate signed descriptor structure"""

    # Check artifact count
    artifact_count = struct.unpack_from('<B', data, offset + 32)[0]
    if artifact_count > MAX_ARTIFACTS:
        return ValidationResult.INVALID_ARTIFACT_COUNT

    # Validate reserved padding is zero
    validate_reserved_zero(data, offset + 33, 3, "descriptor.reserved_pad")

    # Validate each artifact hash structure
    for i in range(artifact_count):
        artifact_offset = offset + 36 + (i * ARTIFACT_HASH_SIZE)
        artifact_type = struct.unpack_from('<I', data, artifact_offset)[0]

        # Check artifact type is valid
        if artifact_type < TOCEntryType.FPGA_BITSTREAM or artifact_type > TOCEntryType.BITSTREAM_HD_DUAL:
            return ValidationResult.INVALID_ENUM_VALUE

    return ValidationResult.OK


def validate_program_config(data: bytes, offset: int) -> int:
    """Validate program configuration structure"""

    # Check strings are null-terminated
    result = validate_string_terminated(data, offset + 0, 64, "program_id")
    if result != ValidationResult.OK:
        return result

    result = validate_string_terminated(data, offset + 82, 32, "program_name")
    if result != ValidationResult.OK:
        return result

    result = validate_string_terminated(data, offset + 114, 64, "author")
    if result != ValidationResult.OK:
        return result

    result = validate_string_terminated(data, offset + 178, 32, "license")
    if result != ValidationResult.OK:
        return result

    result = validate_string_terminated(data, offset + 210, 32, "category")
    if result != ValidationResult.OK:
        return result

    result = validate_string_terminated(data, offset + 242, 128, "description")
    if result != ValidationResult.OK:
        return result

    # Validate ABI range
    abi_min_major = struct.unpack_from('<H', data, offset + 70)[0]
    abi_min_minor = struct.unpack_from('<H', data, offset + 72)[0]
    abi_max_major = struct.unpack_from('<H', data, offset + 74)[0]
    abi_max_minor = struct.unpack_from('<H', data, offset + 76)[0]

    # Min must be less than max
    if abi_min_major > abi_max_major:
        return ValidationResult.INVALID_ABI_RANGE
    if abi_min_major == abi_max_major and abi_min_minor >= abi_max_minor:
        return ValidationResult.INVALID_ABI_RANGE

    # Validate parameter count
    parameter_count = struct.unpack_from('<H', data, offset + 498)[0]
    if parameter_count > 12:
        return ValidationResult.INVALID_PARAMETER_COUNT

    # Validate reserved fields are zero
    validate_reserved_zero(data, offset + 500, 2, "config.reserved_pad")
    validate_reserved_zero(data, offset + 7366, 2, "config.reserved")

    return ValidationResult.OK


# =============================================================================
# Main Entry Point
# =============================================================================

def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Videomancer Program Package Creator',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Input directory must contain:
  - program_config.bin (7372 bytes)
  - bitstreams/ directory with *.bin files

Example:
  python vmprog_pack.py ./build/programs/passthru ./output/passthru.vmprog
  python vmprog_pack.py --no-sign ./build/programs/passthru ./output/passthru.vmprog
  python vmprog_pack.py --keys-dir ./my_keys ./build/programs/passthru ./output/passthru.vmprog
        """
    )

    parser.add_argument('input_dir', type=Path,
                       help='Input directory containing program_config.bin and bitstreams/')
    parser.add_argument('output_file', type=Path,
                       help='Output .vmprog file path')
    parser.add_argument('--no-sign', action='store_true',
                       help='Do not sign the package (unsigned package)')
    parser.add_argument('--keys-dir', type=Path, default=None,
                       help='Directory containing Ed25519 keys (default: ./keys)')

    args = parser.parse_args()

    input_dir = args.input_dir
    output_path = args.output_file
    sign = not args.no_sign
    keys_dir = args.keys_dir

    if not input_dir.exists():
        print(f"ERROR: Input directory does not exist: {input_dir}")
        sys.exit(1)

    if not input_dir.is_dir():
        print(f"ERROR: Input path is not a directory: {input_dir}")
        sys.exit(1)

    # Build package
    success = build_vmprog_package(input_dir, output_path, sign=sign, keys_dir=keys_dir)
    if not success:
        print("\nERROR: Package creation failed")
        sys.exit(1)

    # Validate package
    success = validate_vmprog_package(output_path, verify_hashes=True)
    if not success:
        print("\nERROR: Package validation failed")
        sys.exit(1)

    print(f"\n✓ Successfully created and validated: {output_path}")
    sys.exit(0)


if __name__ == '__main__':
    main()
