#!/bin/bash
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

# Complete workflow example for Ed25519 signing setup and package creation

set -e  # Exit on error

echo "========================================================================"
echo "Videomancer Ed25519 Signing Setup and Package Creation Example"
echo "========================================================================"
echo ""

# Colors for output (if supported)
if command -v tput &> /dev/null && [ -t 1 ]; then
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    RESET=$(tput sgr0)
else
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
fi

# Get script directory (SDK root)
SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "${BLUE}SDK Root: ${SDK_ROOT}${RESET}"
echo ""

# Step 1: Check if cryptography library is installed
echo "${BLUE}Step 1: Checking Python cryptography library...${RESET}"
if python3 -c "import cryptography" 2>/dev/null; then
    echo "${GREEN}✓ cryptography library is installed${RESET}"
else
    echo "${YELLOW}⚠ cryptography library is not installed${RESET}"
    echo "Installing cryptography library..."
    
    # Try system package manager first (for PEP 668 environments)
    if command -v apt-get &> /dev/null; then
        echo "Using system package manager (apt)..."
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y python3-cryptography
    elif command -v yum &> /dev/null; then
        echo "Using system package manager (yum)..."
        sudo yum install -y python3-cryptography
    elif command -v dnf &> /dev/null; then
        echo "Using system package manager (dnf)..."
        sudo dnf install -y python3-cryptography
    else
        # Fall back to pip3
        echo "Attempting pip3 installation..."
        if pip3 install cryptography 2>/dev/null; then
            echo "${GREEN}✓ Installed via pip3${RESET}"
        else
            # Try with --break-system-packages as last resort
            echo "${YELLOW}System pip installation blocked (PEP 668)${RESET}"
            echo "Attempting installation with --break-system-packages..."
            pip3 install --break-system-packages cryptography || {
                echo "${RED}Failed to install cryptography library${RESET}"
                echo ""
                echo "${YELLOW}Please install manually using one of these methods:${RESET}"
                echo "  1. System package: sudo apt install python3-cryptography"
                echo "  2. Virtual environment: python3 -m venv venv && source venv/bin/activate && pip install cryptography"
                echo "  3. User install: pip3 install --user cryptography"
                echo ""
                exit 1
            }
        fi
    fi
    
    # Verify installation
    if python3 -c "import cryptography" 2>/dev/null; then
        echo "${GREEN}✓ cryptography library installed successfully${RESET}"
    else
        echo "${RED}ERROR: cryptography library installation failed${RESET}"
        exit 1
    fi
fi
echo ""

# Step 2: Check for existing keys
echo "${BLUE}Step 2: Checking for Ed25519 keys...${RESET}"
KEYS_DIR="${SDK_ROOT}/keys"
PRIV_KEY="${KEYS_DIR}/lzx_official_signed_descriptor_priv.bin"
PUB_KEY="${KEYS_DIR}/lzx_official_signed_descriptor_pub.bin"

if [ -f "${PRIV_KEY}" ] && [ -f "${PUB_KEY}" ]; then
    echo "${GREEN}✓ Ed25519 keys already exist${RESET}"
    echo "  Private key: ${PRIV_KEY}"
    echo "  Public key: ${PUB_KEY}"
else
    echo "${YELLOW}⚠ Ed25519 keys not found${RESET}"
    echo "Generating new Ed25519 key pair..."
    python3 "${SDK_ROOT}/scripts/vmprog_pack/generate_ed25519_keys.py" --output-dir "${KEYS_DIR}"
    echo "${GREEN}✓ Ed25519 keys generated${RESET}"
fi
echo ""

# Step 3: Test signing functionality
echo "${BLUE}Step 3: Testing Ed25519 signing functionality...${RESET}"
python3 "${SDK_ROOT}/scripts/vmprog_pack/test_ed25519_signing.py"
echo ""

# Step 4: Example package creation
echo "${BLUE}Step 4: Example package creation${RESET}"
echo ""
echo "The vmprog_pack.py script can now create signed packages:"
echo ""
echo "${GREEN}# Create signed package (default):${RESET}"
echo "  python scripts/vmprog_pack/vmprog_pack.py \\"
echo "    ./build/programs/passthru \\"
echo "    ./output/passthru.vmprog"
echo ""
echo "${GREEN}# Create unsigned package:${RESET}"
echo "  python scripts/vmprog_pack/vmprog_pack.py --no-sign \\"
echo "    ./build/programs/passthru \\"
echo "    ./output/passthru.vmprog"
echo ""
echo "${GREEN}# Use custom key directory:${RESET}"
echo "  python scripts/vmprog_pack/vmprog_pack.py --keys-dir ./my_keys \\"
echo "    ./build/programs/passthru \\"
echo "    ./output/passthru.vmprog"
echo ""

# Step 5: Security reminders
echo "${BLUE}========================================================================"
echo "SECURITY REMINDERS"
echo "========================================================================${RESET}"
echo ""
echo "${YELLOW}⚠ Keep your private key secure!${RESET}"
echo "  - Never commit ${PRIV_KEY} to version control"
echo "  - Store it in a secure location (encrypted storage, HSM, etc.)"
echo "  - Limit access to authorized personnel only"
echo ""
echo "${GREEN}✓ Your public key can be freely shared${RESET}"
echo "  - ${PUB_KEY}"
echo "  - Embedded in Videomancer firmware for signature verification"
echo ""

echo "========================================================================"
echo "Setup Complete!"
echo "========================================================================"
echo ""
echo "You can now create cryptographically signed Videomancer packages."
echo ""
