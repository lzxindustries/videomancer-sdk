#!/usr/bin/env bash
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only
#
# clean_trailing_whitespace.sh
# Removes trailing whitespace from all source files in the repository,
# excluding third-party code and build artifacts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Cleaning trailing whitespace in: ${PROJECT_ROOT}"
echo ""

# Count files processed
FILES_PROCESSED=0
FILES_MODIFIED=0

# Find all files, excluding:
# - third_party directories
# - build directories
# - .git directory
# - binary files (common extensions)
# Process text files including:
# - Source code (.c, .cpp, .h, .hpp, .py, .sh, etc.)
# - Documentation (.md, .txt, .toml, .json, .yaml)
# - Build files (CMakeLists.txt, Makefile, etc.)
find "${PROJECT_ROOT}" -type f \
  -not -path "*/third_party/*" \
  -not -path "*/build/*" \
  -not -path "*/out/*" \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.vscode/*" \
  -not -name "*.bin" \
  -not -name "*.o" \
  -not -name "*.a" \
  -not -name "*.so" \
  -not -name "*.dylib" \
  -not -name "*.dll" \
  -not -name "*.exe" \
  -not -name "*.png" \
  -not -name "*.jpg" \
  -not -name "*.jpeg" \
  -not -name "*.gif" \
  -not -name "*.ico" \
  -not -name "*.pdf" \
  -not -name "*.zip" \
  -not -name "*.tar" \
  -not -name "*.gz" \
  -not -name "*.bz2" \
  -not -name "*.vmprog" | while IFS= read -r file; do

  # Skip binary files (check for null bytes)
  if grep -qI . "$file" 2>/dev/null; then
    FILES_PROCESSED=$((FILES_PROCESSED + 1))

    # Check if file has trailing whitespace
    if grep -q '[[:space:]]$' "$file" 2>/dev/null; then
      # Remove trailing whitespace
      sed -i 's/[[:space:]]*$//' "$file"
      FILES_MODIFIED=$((FILES_MODIFIED + 1))
      echo "✓ Cleaned: ${file#${PROJECT_ROOT}/}"
    fi
  fi
done

echo ""
echo "Summary:"
echo "  Files processed: ${FILES_PROCESSED}"
echo "  Files modified:  ${FILES_MODIFIED}"

if [ "${FILES_MODIFIED}" -gt 0 ]; then
  echo ""
  echo "Trailing whitespace has been removed from ${FILES_MODIFIED} file(s)."
  echo "Review changes with: git diff"
else
  echo ""
  echo "No trailing whitespace found. Repository is clean!"
fi
